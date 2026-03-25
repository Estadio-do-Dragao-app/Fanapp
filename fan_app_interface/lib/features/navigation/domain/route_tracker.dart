import 'dart:math';
import '../../map/data/models/route_model.dart';
import '../../map/data/models/node_model.dart';
import '../../../core/utils/geographic_utils.dart';
import '../data/models/navigation_instruction.dart';

/// Responsável por rastrear a posição do utilizador na rota
/// e gerar instruções de navegação
class RouteTracker {
  final RouteModel route;
  final List<NodeModel> allNodes;

  // Mapa para lookup rápido de coordenadas corretas (do Map Service)
  late final Map<String, NodeModel> _nodesMap;

  int _currentWaypointIndex = 0;
  double _userX = 0;
  double _userY = 0;
  int _userLevel = 0;

  RouteTracker({required this.route, required this.allNodes}) {
    // Criar mapa de nós para lookup O(1)
    _nodesMap = {for (var n in allNodes) n.id: n};
  }

  /// Obtém coordenadas corretas de um waypoint usando o Map Service
  /// O Routing Service retorna coordenadas incorretas, mas os node_ids são válidos
  ({double x, double y}) getCorrectWaypointCoords(PathNode wp) {
    final node = _nodesMap[wp.nodeId];
    if (node != null) {
      return (x: node.x, y: node.y);
    }

    // Se o nó é (0,0) vindo do backend, é quase certamente um erro de snapping/virtual node.
    // Usar as coordenadas do waypoint apenas se não forem (0,0).
    if (wp.x.abs() < 0.0001 && wp.y.abs() < 0.0001) {
      print(
        '[RouteTracker] AVISO: Nó ${wp.nodeId} ignorado por ter coordenadas (0,0)',
      );
      // Em vez de retornar 0,0 (que dá erro de 4500km), retornamos a posição do user
      // para que a distância ao primeiro nó seja pequena.
      return (x: _userX, y: _userY);
    }

    return (x: wp.x, y: wp.y);
  }

  // Getters para posição atual (para camera follow)
  double get currentX => _userX;
  double get currentY => _userY;
  int get currentLevel => _userLevel;
  int get currentWaypointIndex => _currentWaypointIndex;

  /// Atualiza a posição atual do utilizador
  void updateUserPosition(double x, double y, {int? level}) {
    _userX = x;
    _userY = y;
    if (level != null) {
      _userLevel = level;
    }
    print('[RouteTracker] Posição atualizada: x=$x, y=$y, level=$_userLevel');
    _updateCurrentWaypoint();
  }

  /// Define posição/índice base após um recálculo de rota sem executar
  /// auto-progressão imediata para evitar saltos logo no primeiro frame.
  void seedUserPositionForNewRoute(
    double x,
    double y, {
    int? level,
    int waypointIndex = 0,
  }) {
    _userX = x;
    _userY = y;
    if (level != null) {
      _userLevel = level;
    }

    final maxIndex = route.waypoints.isEmpty ? 0 : route.waypoints.length - 1;
    _currentWaypointIndex = waypointIndex.clamp(0, maxIndex);

    print(
      '[RouteTracker] Rota nova semeada: x=$x, y=$y, level=$_userLevel, '
      'waypoint=$_currentWaypointIndex/${route.waypoints.length}',
    );
  }

  /// Verifica se utilizador chegou ao destino
  /// Considera X, Y E nível - só chegou se estiver no piso certo!
  /// Requer que o user tenha progredido na rota (evita arrival prematuro em rotas curtas)
  bool get hasArrived {
    // Se a rota está vazia, já chegamos (ou não há para onde ir)
    if (route.waypoints.isEmpty) return true;
    final lastWaypoint = route.waypoints.last;
    final lastCoords = getCorrectWaypointCoords(lastWaypoint);
    final destinationLevel = _getWaypointLevel(lastWaypoint);

    final distToLast = GeographicUtils.calculateDistance(
      _userX,
      _userY,
      lastCoords.x,
      lastCoords.y,
    );

    // Raio de chegada: 5 metros
    if (distToLast < 5.0 && _userLevel == destinationLevel) {
      // Para rotas curtas: só considerar "arrived" se o user já progrediu
      // na rota (pelo menos 60% dos waypoints ultrapassados)
      // Isto evita que a navegação termine antes de começar
      final minProgress = route.waypoints.length <= 3
          ? 0.5 // Rotas muito curtas: pelo menos metade
          : 0.3; // Rotas normais: 30%
      if (progress < minProgress) {
        return false;
      }
      return true;
    }

    return false;
  }

  /// Obtém o nível de um waypoint (do Map Service ou do próprio waypoint)
  int _getWaypointLevel(PathNode wp) {
    final node = _nodesMap[wp.nodeId];
    return node?.level ?? wp.level;
  }

  /// Retorna a distância restante total
  double get remainingDistance {
    if (_currentWaypointIndex >= route.waypoints.length) {
      return 0;
    }

    // Distância do utilizador até o próximo waypoint
    final nextWaypoint = route.waypoints[_currentWaypointIndex];
    final nextCoords = getCorrectWaypointCoords(nextWaypoint);
    double total = GeographicUtils.calculateDistance(
      _userX,
      _userY,
      nextCoords.x,
      nextCoords.y,
    );

    // Somar distâncias dos waypoints seguintes
    for (int i = _currentWaypointIndex; i < route.waypoints.length - 1; i++) {
      final current = route.waypoints[i];
      final next = route.waypoints[i + 1];
      final currentCoords = getCorrectWaypointCoords(current);
      final nextCoordsLoop = getCorrectWaypointCoords(next);
      total += GeographicUtils.calculateDistance(
        currentCoords.x,
        currentCoords.y,
        nextCoordsLoop.x,
        nextCoordsLoop.y,
      );
    }

    print(
      '[RouteTracker] Distância restante: ${total.toStringAsFixed(1)}m (waypoint $_currentWaypointIndex/${route.waypoints.length})',
    );
    return total;
  }

  /// Retorna o tempo estimado restante (baseado na distância)
  int get remainingTimeSeconds {
    // Assumir velocidade de caminhada: 1.4 m/s (~5 km/h)
    const walkingSpeed = 1.4;
    return (remainingDistance / walkingSpeed).round();
  }

  /// Gera a próxima instrução de navegação
  /// Procura a PRÓXIMA CURVA REAL e soma as distâncias dos straights até lá
  NavigationInstruction? getNextInstruction() {
    if (route.waypoints.isEmpty) return null;

    // Verificar se chegou ao destino
    final lastWaypoint = route.waypoints.last;
    final lastCoords = getCorrectWaypointCoords(lastWaypoint);
    final distToLast = GeographicUtils.calculateDistance(
      _userX,
      _userY,
      lastCoords.x,
      lastCoords.y,
    );

    // Verificar se chegou ao destino (considerando nível!)
    final destinationLevel = _getWaypointLevel(lastWaypoint);
    final sameLevel = _userLevel == destinationLevel;

    if (distToLast < 5.0 && sameLevel && progress >= 0.3) {
      print(
        '[RouteTracker]  Chegando ao destino! Distância: ${distToLast.toStringAsFixed(1)}m, nível: $_userLevel',
      );
      return NavigationInstruction(
        type: 'arrive',
        distanceToNextTurn: distToLast,
        nodeId: lastWaypoint.nodeId,
      );
    }

    // Se está perto em X,Y mas no nível errado, mostrar instrução para escadas/rampa
    if (distToLast < 10.0 && !sameLevel) {
      print(
        '[RouteTracker] Perto do destino mas nível errado: user=$_userLevel, dest=$destinationLevel',
      );
      // Continuar navegação normal para encontrar escadas
    }

    // Encontrar a próxima curva real (não straight)
    int nextTurnIndex = _findNextRealTurn(_currentWaypointIndex);

    // Calcular distância TOTAL até essa curva
    // Inclui: posição atual → waypoint atual → ... → waypoint da curva
    double totalDistance = 0.0;

    // Distância da posição atual até o waypoint atual
    final currentWp = route.waypoints[_currentWaypointIndex];
    final currentCoords = getCorrectWaypointCoords(currentWp);
    totalDistance += GeographicUtils.calculateDistance(
      _userX,
      _userY,
      currentCoords.x,
      currentCoords.y,
    );

    // Somar distâncias entre waypoints intermédios
    for (int i = _currentWaypointIndex; i < nextTurnIndex; i++) {
      final wp1 = route.waypoints[i];
      final wp2 = route.waypoints[i + 1];
      final coords1 = getCorrectWaypointCoords(wp1);
      final coords2 = getCorrectWaypointCoords(wp2);
      totalDistance += GeographicUtils.calculateDistance(
        coords1.x,
        coords1.y,
        coords2.x,
        coords2.y,
      );
    }

    // Determinar o tipo de curva no waypoint alvo
    String turnType;
    if (nextTurnIndex >= route.waypoints.length - 1) {
      turnType = 'arrive';
    } else {
      turnType = _determineTurnAtWaypoint(nextTurnIndex);
      // Se ainda deu straight, usar straight mesmo
      if (turnType == 'straight') {
        turnType = 'straight';
      }
    }

    print(
      '[RouteTracker] Instrução: "$turnType" em ${totalDistance.toStringAsFixed(1)}m '
      '(waypoints $_currentWaypointIndex→$nextTurnIndex de ${route.waypoints.length})',
    );

    return NavigationInstruction(
      type: turnType,
      distanceToNextTurn: totalDistance,
      nodeId: route.waypoints[nextTurnIndex].nodeId,
    );
  }

  /// Encontra o índice do próximo waypoint com curva real (não straight)
  int _findNextRealTurn(int startIndex) {
    // Procurar waypoint com curva a partir do índice atual
    for (int i = startIndex; i < route.waypoints.length - 1; i++) {
      final turnType = _determineTurnAtWaypoint(i);
      if (turnType != 'straight') {
        return i;
      }
    }
    // Se não há mais curvas, retornar o último waypoint
    return route.waypoints.length - 1;
  }

  /// Determina o tipo de curva que acontece NUM waypoint específico
  /// Analisa a mudança de direção: (anterior→waypoint) vs (waypoint→seguinte)
  String _determineTurnAtWaypoint(int waypointIndex) {
    // Precisamos de pelo menos 3 pontos: anterior, atual, seguinte
    if (waypointIndex < 1 || waypointIndex >= route.waypoints.length - 1) {
      return 'straight';
    }

    final prev = route.waypoints[waypointIndex - 1];
    final current = route.waypoints[waypointIndex];
    final next = route.waypoints[waypointIndex + 1];

    // Verificar se o waypoint atual e o seguinte são a mesma estrutura de transição
    final currentNode = _nodesMap[current.nodeId];
    final nextNode = _nodesMap[next.nodeId];

    if (currentNode != null && nextNode != null) {
      if (currentNode.type == 'stairs' && nextNode.type == 'stairs') {
        return 'stairs';
      }
      if (currentNode.type == 'ramp' && nextNode.type == 'ramp') {
        return 'ramp';
      }
    }

    // Obter coordenadas corretas do Map Service
    final prevCoords = getCorrectWaypointCoords(prev);
    final currentCoords = getCorrectWaypointCoords(current);
    final nextCoords = getCorrectWaypointCoords(next);

    // Calcular vetores de direção
    final dx1 = currentCoords.x - prevCoords.x;
    final dy1 = currentCoords.y - prevCoords.y;
    final dx2 = nextCoords.x - currentCoords.x;
    final dy2 = nextCoords.y - currentCoords.y;

    // Verificar se os vetores são válidos (não-zero)
    final len1 = sqrt(dx1 * dx1 + dy1 * dy1);
    final len2 = sqrt(dx2 * dx2 + dy2 * dy2);
    if (len1 < 1e-12 || len2 < 1e-12) {
      return 'straight';
    }

    // Cross product: determina o sentido da curva
    final crossProduct = dx1 * dy2 - dy1 * dx2;

    // Dot product normalizado para calcular o ângulo absoluto
    final dotProduct = (dx1 * dx2 + dy1 * dy2) / (len1 * len2);
    final angleDegrees = acos(dotProduct.clamp(-1.0, 1.0)) * 180 / pi;

    print(
      '[RouteTracker] Curva em WP$waypointIndex: ângulo=${angleDegrees.toStringAsFixed(1)}° cross=${crossProduct.toStringAsFixed(0)}',
    );

    // Se o ângulo é pequeno, é praticamente reto
    if (angleDegrees < 25) {
      return 'straight';
    }

    // Invertido: testando a outra combinação
    // Cross product positivo = curva à ESQUERDA
    // Cross product negativo = curva à DIREITA
    if (crossProduct > 0) {
      return 'left';
    } else {
      return 'right';
    }
  }

  /// Versão do progressAlongSegment sem clamp — permite detectar t > 1
  /// (user passou além do nó destino do segmento)
  double _rawProgressAlongSegment(
    double px,
    double py,
    double x1,
    double y1,
    double x2,
    double y2,
  ) {
    final segLenSq = (x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1);
    if (segLenSq < 1e-12) return 1.0;
    return ((px - x1) * (x2 - x1) + (py - y1) * (y2 - y1)) / segLenSq;
  }

  void _updateCurrentWaypoint() {
    if (_currentWaypointIndex >= route.waypoints.length) return;

    // Skip conservador para evitar saltos errados entre ramos da rota.
    const int MAX_SKIP_AHEAD = 8;
    const double PROXIMITY_DIST = 7.0; // meters – chegou ao nó
    const double MAX_LATERAL_DIST = 14.0; // meters – tolerância lateral

    int bestNextWaypoint = _currentWaypointIndex;

    final maxLook = (_currentWaypointIndex + MAX_SKIP_AHEAD).clamp(
      0,
      route.waypoints.length,
    );

    for (int i = _currentWaypointIndex; i < maxLook; i++) {
      final wp = route.waypoints[i];
      final coords = getCorrectWaypointCoords(wp);

      final pointDist = GeographicUtils.calculateDistance(
        _userX,
        _userY,
        coords.x,
        coords.y,
      );

      // CHEGADA AO NÓ: está dentro do raio de chegada
      if (pointDist < PROXIMITY_DIST) {
        if (i + 1 > bestNextWaypoint) {
          bestNextWaypoint = i + 1;
        }
        continue; // continue scanning ahead
      }

      // PROJEÇÃO NO SEGMENTO: só considerar se existe um segmento anterior
      if (i > 0) {
        final prevWp = route.waypoints[i - 1];
        final prevCoords = getCorrectWaypointCoords(prevWp);

        final segLen = GeographicUtils.calculateDistance(
          prevCoords.x,
          prevCoords.y,
          coords.x,
          coords.y,
        );
        if (segLen < 0.5) continue; // segmento degenerado

        final rawT = _rawProgressAlongSegment(
          _userX,
          _userY,
          prevCoords.x,
          prevCoords.y,
          coords.x,
          coords.y,
        );
        final segDist = GeographicUtils.pointToSegmentDistance(
          _userX,
          _userY,
          prevCoords.x,
          prevCoords.y,
          coords.x,
          coords.y,
        );

        // Só considerar se estamos lateralmente perto do segmento
        // E se estamos a progredir no sentido do nó (t >= 0) — não atrás
        if (segDist < MAX_LATERAL_DIST && rawT >= 0.0 && rawT <= 1.1) {
          if (i > bestNextWaypoint) {
            bestNextWaypoint = i;
          }
        }
        // Se já passámos o nó (t > 0.85), o próximo alvo é o seguinte
        if (segDist < MAX_LATERAL_DIST && rawT > 0.85) {
          if (i + 1 > bestNextWaypoint) {
            bestNextWaypoint = i + 1;
          }
        }
      }
    }

    if (bestNextWaypoint <= _currentWaypointIndex) {
      // Fallback: se a heurística acima não avançou, escolhemos o waypoint
      // mais próximo à frente do índice atual para evitar ficar preso atrás.
      int nearestAhead = _currentWaypointIndex;
      double nearestDist = double.infinity;

      for (int i = _currentWaypointIndex; i < route.waypoints.length; i++) {
        final wp = route.waypoints[i];
        final coords = getCorrectWaypointCoords(wp);
        final dist = GeographicUtils.calculateDistance(
          _userX,
          _userY,
          coords.x,
          coords.y,
        );
        if (dist < nearestDist) {
          nearestDist = dist;
          nearestAhead = i;
        }
      }

      // Só saltar automaticamente quando há alta confiança espacial e
      // apenas para 1 waypoint à frente (evita pular grandes blocos).
      final jump = nearestAhead - _currentWaypointIndex;
      if (nearestAhead > _currentWaypointIndex && nearestDist < 12.0 && jump <= 1) {
        bestNextWaypoint = nearestAhead;
      }
    }

    if (bestNextWaypoint > _currentWaypointIndex) {
      // Guard-rail: limitar avanço por update para evitar saltos abruptos.
      final maxForwardAdvancePerUpdate = _currentWaypointIndex + 1;
      if (bestNextWaypoint > maxForwardAdvancePerUpdate) {
        bestNextWaypoint = maxForwardAdvancePerUpdate;
      }

      if (bestNextWaypoint >= route.waypoints.length) {
        bestNextWaypoint = route.waypoints.length - 1;
      }
      print(
        '[RouteTracker] Progresso: WP$_currentWaypointIndex → WP$bestNextWaypoint',
      );
      _currentWaypointIndex = bestNextWaypoint;
    }
  }

  /// Retorna o progresso da rota (0.0 a 1.0)
  double get progress {
    if (route.waypoints.isEmpty) return 0.0;
    return _currentWaypointIndex / route.waypoints.length;
  }
}
