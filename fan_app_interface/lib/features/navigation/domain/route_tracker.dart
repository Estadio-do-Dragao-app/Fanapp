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
    // Fallback: usar coordenadas do routing (podem estar erradas)
    print(
      '[RouteTracker] AVISO: Nó ${wp.nodeId} não encontrado no Map Service',
    );
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
          ? 0.5  // Rotas muito curtas: pelo menos metade
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

  /// Atualiza o waypoint atual baseado na posição do utilizador.
  ///
  /// Lógica estilo Google Maps:
  /// 1. Se o user está perto de um waypoint (< 4m), avança
  /// 2. Se o user progrediu > 90% no segmento atual, avança
  /// 3. FORWARD-PROJECTION: Se o user está mais perto do PRÓXIMO waypoint
  ///    do que do ATUAL, avança (skips waypoints ultrapassados)
  void _updateCurrentWaypoint() {
    if (_currentWaypointIndex >= route.waypoints.length) return;

    bool advanced = true;

    // Continuar a avançar enquanto houver waypoints para saltar
    while (advanced && _currentWaypointIndex < route.waypoints.length) {
      advanced = false;

      final currentIdx = _currentWaypointIndex;
      final waypoint = route.waypoints[currentIdx];
      final coords = getCorrectWaypointCoords(waypoint);
      final pointDist = GeographicUtils.calculateDistance(
        _userX, _userY, coords.x, coords.y,
      );

      // Debug log
      print(
        '[RouteTracker] WP$currentIdx (${waypoint.nodeId}): '
        'dist=${pointDist.toStringAsFixed(1)}m',
      );

      // === CHECK 1: Proximidade direta ao nó (< 4m) ===
      if (pointDist < 4.0) {
        _currentWaypointIndex = currentIdx + 1;
        print(
          '[RouteTracker] WP$currentIdx atingido por proximidade '
          '(${pointDist.toStringAsFixed(1)}m)',
        );
        advanced = true;
        continue;
      }

      // === CHECK 2: Snap-to-edge — progresso no segmento ===
      if (currentIdx > 0) {
        final prevWp = route.waypoints[currentIdx - 1];
        final prevCoords = getCorrectWaypointCoords(prevWp);

        final segDist = GeographicUtils.pointToSegmentDistance(
          _userX, _userY,
          prevCoords.x, prevCoords.y,
          coords.x, coords.y,
        );
        final progress = GeographicUtils.progressAlongSegment(
          _userX, _userY,
          prevCoords.x, prevCoords.y,
          coords.x, coords.y,
        );

        print(
          '[RouteTracker] Seg WP${currentIdx - 1}→WP$currentIdx: '
          'segDist=${segDist.toStringAsFixed(1)}m, '
          'progress=${(progress * 100).toStringAsFixed(0)}%',
        );

        // Se está perto do segmento E progrediu > 90%, avança
        if (segDist < 8.0 && progress > 0.90) {
          _currentWaypointIndex = currentIdx + 1;
          print(
            '[RouteTracker] WP$currentIdx atingido por snap-to-edge '
            '(progress=${(progress * 100).toStringAsFixed(0)}%)',
          );
          advanced = true;
          continue;
        }
      }

      // === CHECK 3: FORWARD-PROJECTION (estilo Google Maps) ===
      // Se o user está mais perto do PRÓXIMO waypoint do que do ATUAL,
      // significa que já ultrapassou o atual sem passar perto.
      // Isto resolve o caso de cortar uma curva ou caminhar paralelo.
      if (currentIdx + 1 < route.waypoints.length) {
        final nextWp = route.waypoints[currentIdx + 1];
        final nextCoords = getCorrectWaypointCoords(nextWp);
        final distToNext = GeographicUtils.calculateDistance(
          _userX, _userY, nextCoords.x, nextCoords.y,
        );

        // Distância entre o waypoint atual e o próximo
        final segmentLen = GeographicUtils.calculateDistance(
          coords.x, coords.y, nextCoords.x, nextCoords.y,
        );

        // Se o user está mais perto do próximo E a distância ao atual
        // é maior que metade do segmento → claramente ultrapassou
        if (distToNext < pointDist && pointDist > segmentLen * 0.4) {
          _currentWaypointIndex = currentIdx + 1;
          print(
            '[RouteTracker] WP$currentIdx skipped (forward-projection): '
            'distCurrent=${pointDist.toStringAsFixed(1)}m > '
            'distNext=${distToNext.toStringAsFixed(1)}m',
          );
          advanced = true;
          continue;
        }
      }
    }
  }

  /// Retorna o progresso da rota (0.0 a 1.0)
  double get progress {
    if (route.waypoints.isEmpty) return 0.0;
    return _currentWaypointIndex / route.waypoints.length;
  }
}

