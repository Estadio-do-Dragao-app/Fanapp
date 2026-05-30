import 'dart:math';
import '../../map/data/models/route_model.dart';
import '../../map/data/models/node_model.dart';
import '../../../core/utils/geographic_utils.dart';
import '../data/models/navigation_instruction.dart';
import 'geometry/segment_projector.dart';
import 'tracking/snap_engine.dart';
import 'tracking/heading_validator.dart';
import 'tracking/z_axis_guard.dart';

/// Tracker da posição do utilizador na rota.
///
/// Modelo: **GPS cru direto na UI**. Nada de simulação on-edge.
/// - `currentX/Y` = posição GPS real (após filtros).
/// - As lógicas auxiliares (heading validator, z-axis guard, projeção para
///   off-route, deteção de atalho que avança índice de waypoint, hysteresis
///   de reroute) continuam ativas — apenas não interferem nas coordenadas
///   apresentadas ao utilizador.
class RouteTracker {
  final RouteModel route;
  final List<NodeModel> allNodes;

  late final Map<String, NodeModel> _nodesMap;
  late final List<({double x, double y})> _vertices;
  late final List<double> _cumLen;
  late final double _totalLength;

  // Engines auxiliares (não geram posição visível)
  final SnapEngine _snapEngine;
  final HeadingValidator _headingValidator = HeadingValidator();
  final ZAxisGuard _zGuard;

  // GPS cru — é o que a UI mostra.
  double _rawX = 0;
  double _rawY = 0;

  int _currentWaypointIndex = 0;
  int _userLevel = 0;
  double _lastPerpDistMeters = double.infinity;
  // Comprimento da rota já percorrido (m). Usado só para progress/remaining.
  double _accumulatedDistanceMeters = 0;

  RouteTracker({
    required this.route,
    required this.allNodes,
    SnapEngine? snapEngine,
    int initialLevel = 0,
  })  : _snapEngine = snapEngine ?? const SnapEngine(),
        _zGuard = ZAxisGuard(initialLevel: initialLevel) {
    _nodesMap = {for (var n in allNodes) n.id: n};
    _userLevel = initialLevel;
    _vertices = _extractVertices();
    _cumLen = _buildCumLen(_vertices);
    _totalLength = _cumLen.isEmpty ? 0.0 : _cumLen.last;
  }

  List<({double x, double y})> _extractVertices() {
    final v = <({double x, double y})>[];
    for (final wp in route.waypoints) {
      final n = _nodesMap[wp.nodeId];
      v.add((x: n?.x ?? wp.x, y: n?.y ?? wp.y));
    }
    return v;
  }

  List<double> _buildCumLen(List<({double x, double y})> v) {
    if (v.length < 2) return [0.0];
    final cum = List<double>.filled(v.length, 0.0);
    for (int i = 1; i < v.length; i++) {
      cum[i] = cum[i - 1] +
          GeographicUtils.calculateDistance(
              v[i - 1].x, v[i - 1].y, v[i].x, v[i].y);
    }
    return cum;
  }

  ({double x, double y}) getCorrectWaypointCoords(PathNode wp) {
    final n = _nodesMap[wp.nodeId];
    if (n != null) return (x: n.x, y: n.y);
    if (wp.x.abs() < 0.0001 && wp.y.abs() < 0.0001) {
      return (x: _rawX, y: _rawY);
    }
    return (x: wp.x, y: wp.y);
  }

  // ── Getters expostos ─────────────────────────────────────────────────────
  /// Posição para a UI = GPS cru.
  double get currentX => _rawX;
  double get currentY => _rawY;

  /// GPS cru (reroute, save, lookup de nó) — igual a currentX/Y.
  double get rawX => _rawX;
  double get rawY => _rawY;

  int get currentLevel => _userLevel;
  int get currentWaypointIndex => _currentWaypointIndex;
  double get perpDistMeters => _lastPerpDistMeters;
  HeadingValidator get headingValidator => _headingValidator;
  ZAxisGuard get zGuard => _zGuard;
  HeadingValidation? lastHeadingValidation;

  // ── Atualização de posição ───────────────────────────────────────────────
  /// Recebe GPS cru `(x,y)`. Valida heading, mede perp dist, avança índice
  /// de waypoint quando há projeção válida à frente.
  void updateUserPosition(double x, double y, {int? level, DateTime? now}) {
    final ts = now ?? DateTime.now();

    // 1. Heading validation
    double? refX;
    double? refY;
    if (_currentWaypointIndex < route.waypoints.length) {
      final tgt = getCorrectWaypointCoords(
        route.waypoints[_currentWaypointIndex],
      );
      refX = tgt.x;
      refY = tgt.y;
    }
    lastHeadingValidation = _headingValidator.evaluate(
      curX: x, curY: y, now: ts, refX: refX, refY: refY,
    );
    final hv = lastHeadingValidation!;

    // 2. Filtro teleport: ignora amostra absurda.
    if (hv.isImplausibleJump) {
      print('[RouteTracker] Teleport ignorado: speed=${hv.speedMps.toStringAsFixed(1)} m/s');
      return;
    }

    // 3. Aceita GPS cru.
    _rawX = x;
    _rawY = y;

    // 4. Z-axis guard.
    if (level != null && level != _userLevel) {
      final d = _zGuard.evaluateLevelChange(
        candidateLevel: level,
        route: route,
        currentSegmentIndex: _currentWaypointIndex,
        nodesMap: _nodesMap,
      );
      _userLevel = d.acceptedLevel;
    } else if (level != null) {
      _userLevel = level;
    }

    // 5. Projeção: encontra segmento ativo + perp dist, e tenta avançar
    //    o índice de waypoint quando o user já passou nós atrás.
    _projectAndAdvanceWaypoint(x, y);

    // 6. Aceita amostra no histórico (post-update).
    _headingValidator.accept(x, y, ts);

    // 7. Notifica Z-guard se passou por nó transitório.
    if (_currentWaypointIndex < route.waypoints.length) {
      final wp = route.waypoints[_currentWaypointIndex];
      final n = _nodesMap[wp.nodeId];
      if (n != null) {
        final d = GeographicUtils.calculateDistance(x, y, n.x, n.y);
        if (d < 3.0) _zGuard.notifyVisited(n);
      }
    }
  }

  /// Procura, na janela à frente, o segmento com menor perp dist cuja
  /// projeção caia DENTRO do segmento (rawT ∈ [0,1]). Se encontrar à
  /// frente do índice atual, avança o waypoint. Atualiza `_lastPerpDistMeters`
  /// e `_accumulatedDistanceMeters` para progresso.
  ///
  /// **Barreira de nós transitórios:** a procura nunca atravessa um nó
  /// `stairs/ramp/elevator` cujo piso de destino ainda não foi confirmado
  /// pelo `ZAxisGuard`. Caminhar em paralelo (perp pequena) à projeção 2D
  /// de umas escadas NÃO conta como tê-las usado.
  void _projectAndAdvanceWaypoint(double x, double y) {
    if (_vertices.length < 2) {
      _lastPerpDistMeters = double.infinity;
      return;
    }

    final curSeg = _currentWaypointIndex.clamp(0, _vertices.length - 2);
    final maxLook = (curSeg + _snapEngine.maxLookAhead)
        .clamp(curSeg + 1, _vertices.length - 1);

    int bestIdx = curSeg;
    double bestPerp = double.infinity;
    double bestT = 0.0;
    bool bestInside = false;

    for (int i = curSeg; i < maxLook; i++) {
      // Antes de considerar o segmento `i`, verifica se o vértice de
      // ENTRADA (waypoint i) é um nó transitório que ainda não foi visitado
      // no terreno. Se for, não avançamos para lá nem nada à frente.
      if (i > curSeg && _isUntraversedTransitionBoundary(i)) {
        break;
      }

      final a = _vertices[i];
      final b = _vertices[i + 1];
      if (a == b) continue;
      final proj = SegmentProjector.projectOntoSegment(
          x, y, a.x, a.y, b.x, b.y);
      final inside = !proj.isClamped;
      if (inside && !bestInside) {
        bestInside = true;
        bestIdx = i;
        bestPerp = proj.perpDistMeters;
        bestT = proj.clampedT;
        continue;
      }
      if (inside == bestInside && proj.perpDistMeters < bestPerp) {
        bestIdx = i;
        bestPerp = proj.perpDistMeters;
        bestT = proj.clampedT;
      }
    }

    _lastPerpDistMeters = bestPerp;

    // Avança o índice de waypoint sempre que houver projeção válida à frente,
    // mesmo sem heading alinhado. Critério único: cortar segmentos físicamente
    // ultrapassados pelo utilizador para que o traço nunca apareça "atrás" do dot.
    if (bestInside && bestIdx > _currentWaypointIndex) {
      print('[RouteTracker] WP$_currentWaypointIndex → WP$bestIdx (perp=${bestPerp.toStringAsFixed(1)}m)');
      _currentWaypointIndex = bestIdx;
    }

    if (bestIdx < _cumLen.length - 1) {
      final segLen = _cumLen[bestIdx + 1] - _cumLen[bestIdx];
      _accumulatedDistanceMeters =
          (_cumLen[bestIdx] + bestT * segLen).clamp(0.0, _totalLength);
    }
  }

  /// `true` se o waypoint `idx` é um nó stairs/ramp/elevator ainda não
  /// confirmado como atravessado (ZAxisGuard não tem este id como última
  /// transição **e** o piso do utilizador difere do piso do nó de chegada
  /// do outro lado da transição).
  ///
  /// Conservador: na dúvida bloqueia o avanço.
  bool _isUntraversedTransitionBoundary(int idx) {
    if (idx <= 0 || idx >= route.waypoints.length) return false;
    final wp = route.waypoints[idx];
    final node = _nodesMap[wp.nodeId];
    if (node == null) return false;
    if (!ZAxisGuard.transitionTypes.contains(node.type)) return false;

    // Já marcámos como visitado → liberta o avanço para depois deste nó.
    if (_zGuard.lastVisitedTransitionId == node.id) return false;

    // Piso de destino: o piso do próximo waypoint do outro lado, ou o do
    // próprio nó se este tiver `level` diferente do user.
    int destLevel = node.level;
    if (idx + 1 < route.waypoints.length) {
      final nextNode = _nodesMap[route.waypoints[idx + 1].nodeId];
      if (nextNode != null) destLevel = nextNode.level;
    }

    // Se o user ainda não está no piso de destino, NÃO podemos considerar
    // o nó como passado por mera projeção 2D.
    return _userLevel != destLevel;
  }

  // ── Reset/seed ────────────────────────────────────────────────────────────
  /// Semeia posição/índice após recálculo. O dot fica no GPS cru fornecido.
  void seedUserPositionForNewRoute(
    double x,
    double y, {
    int? level,
    int waypointIndex = 0,
  }) {
    _rawX = x;
    _rawY = y;

    final maxIndex = route.waypoints.isEmpty ? 0 : route.waypoints.length - 1;
    _currentWaypointIndex = waypointIndex.clamp(0, maxIndex);

    if (level != null) {
      _userLevel = level;
      _zGuard.reset(level: level);
    }
    _headingValidator.reset();
    lastHeadingValidation = null;
    _lastPerpDistMeters = double.infinity;
    _accumulatedDistanceMeters = _currentWaypointIndex < _cumLen.length
        ? _cumLen[_currentWaypointIndex]
        : 0.0;

    print(
      '[RouteTracker] Rota nova semeada: x=$x, y=$y, level=$_userLevel, '
      'waypoint=$_currentWaypointIndex/${route.waypoints.length}',
    );
  }

  // ── Chegada ──────────────────────────────────────────────────────────────
  bool get hasArrived {
    if (route.waypoints.isEmpty) return true;
    final last = route.waypoints.last;
    final lc = getCorrectWaypointCoords(last);
    final destLevel = _getWaypointLevel(last);
    final d = GeographicUtils.calculateDistance(_rawX, _rawY, lc.x, lc.y);
    if (d < 5.0 && _userLevel == destLevel) {
      final minProgress = route.waypoints.length <= 3 ? 0.5 : 0.3;
      if (progress < minProgress) return false;
      return true;
    }
    return false;
  }

  int _getWaypointLevel(PathNode wp) {
    final n = _nodesMap[wp.nodeId];
    return n?.level ?? wp.level;
  }

  // ── Distância e tempo ────────────────────────────────────────────────────
  double get remainingDistance {
    return (_totalLength - _accumulatedDistanceMeters).clamp(0.0, _totalLength);
  }

  int get remainingTimeSeconds => (remainingDistance / 1.4).round();

  double get progress {
    if (_totalLength < 1e-6) return 0.0;
    return (_accumulatedDistanceMeters / _totalLength).clamp(0.0, 1.0);
  }

  // ── Instruções ───────────────────────────────────────────────────────────
  NavigationInstruction? getNextInstruction() {
    if (route.waypoints.isEmpty) return null;

    final last = route.waypoints.last;
    final lc = getCorrectWaypointCoords(last);
    final distToLast =
        GeographicUtils.calculateDistance(_rawX, _rawY, lc.x, lc.y);
    final destLevel = _getWaypointLevel(last);
    final sameLevel = _userLevel == destLevel;

    if (distToLast < 5.0 && sameLevel && progress >= 0.3) {
      return NavigationInstruction(
        type: 'arrive',
        distanceToNextTurn: distToLast,
        nodeId: last.nodeId,
      );
    }

    final nextTurnIndex = _findNextRealTurn(_currentWaypointIndex);

    double totalDist = remainingDistance;
    if (nextTurnIndex < route.waypoints.length &&
        nextTurnIndex < _cumLen.length) {
      final lenToTurn = (_cumLen[nextTurnIndex] - _accumulatedDistanceMeters)
          .clamp(0.0, double.infinity);
      totalDist = lenToTurn;
    }

    String turnType;
    if (nextTurnIndex >= route.waypoints.length - 1) {
      turnType = 'arrive';
    } else {
      turnType = _determineTurnAtWaypoint(nextTurnIndex);
    }

    return NavigationInstruction(
      type: turnType,
      distanceToNextTurn: totalDist,
      nodeId: route.waypoints[nextTurnIndex].nodeId,
    );
  }

  int _findNextRealTurn(int startIndex) {
    for (int i = startIndex; i < route.waypoints.length - 1; i++) {
      final t = _determineTurnAtWaypoint(i);
      if (t != 'straight') return i;
    }
    return route.waypoints.length - 1;
  }

  String _determineTurnAtWaypoint(int idx) {
    if (idx < 1 || idx >= route.waypoints.length - 1) return 'straight';
    final prev = route.waypoints[idx - 1];
    final cur = route.waypoints[idx];
    final next = route.waypoints[idx + 1];

    final curNode = _nodesMap[cur.nodeId];
    final nextNode = _nodesMap[next.nodeId];
    if (curNode != null && nextNode != null) {
      if (curNode.type == 'stairs' && nextNode.type == 'stairs') return 'stairs';
      if (curNode.type == 'ramp' && nextNode.type == 'ramp') return 'ramp';
    }

    final pc = getCorrectWaypointCoords(prev);
    final cc = getCorrectWaypointCoords(cur);
    final nc = getCorrectWaypointCoords(next);

    final dx1 = cc.x - pc.x;
    final dy1 = cc.y - pc.y;
    final dx2 = nc.x - cc.x;
    final dy2 = nc.y - cc.y;
    final len1 = sqrt(dx1 * dx1 + dy1 * dy1);
    final len2 = sqrt(dx2 * dx2 + dy2 * dy2);
    if (len1 < 1e-12 || len2 < 1e-12) return 'straight';

    final cross = dx1 * dy2 - dy1 * dx2;
    final dot = (dx1 * dx2 + dy1 * dy2) / (len1 * len2);
    final angDeg = acos(dot.clamp(-1.0, 1.0)) * 180 / pi;
    if (angDeg < 25) return 'straight';
    return cross > 0 ? 'left' : 'right';
  }
}
