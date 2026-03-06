import 'dart:math';
import '../../map/data/models/route_model.dart';
import '../../map/data/models/node_model.dart';
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
  /// Para rotas de evacuação ou rotas simples, o nível é verificado com tolerância
  bool get hasArrived {
    // Se a rota está vazia, já chegamos (ou não há para onde ir)
    if (route.waypoints.isEmpty) return true;
    final lastWaypoint = route.waypoints.last;
    final lastCoords = getCorrectWaypointCoords(lastWaypoint);
    final destinationLevel = _getWaypointLevel(lastWaypoint);

    final distToLast = _calculateDistance(
      _userX,
      _userY,
      lastCoords.x,
      lastCoords.y,
    );

    // Se muito perto (< 8m), verificamos se estamos no mesmo piso
    if (distToLast < 8.0) {
      if (_userLevel == destinationLevel) {
        return true;
      }

      // Se estamos perto mas no piso errado, NÃO chegamos ainda
      // (a menos que seja um caso especial de saída de emergência que atravessa pisos,
      // mas para navegação normal isso causa erros graves)
      return false;
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
    double total = _calculateDistance(
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
      total += _calculateDistance(
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
    final distToLast = _calculateDistance(
      _userX,
      _userY,
      lastCoords.x,
      lastCoords.y,
    );

    // Verificar se chegou ao destino (considerando nível!)
    final destinationLevel = _getWaypointLevel(lastWaypoint);
    final sameLevel = _userLevel == destinationLevel;

    if (distToLast < 5.0 && sameLevel) {
      print(
        '[RouteTracker] 🎯 Chegando ao destino! Distância: ${distToLast.toStringAsFixed(1)}m, nível: $_userLevel',
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
        '[RouteTracker] 🪜 Perto do destino mas nível errado: user=$_userLevel, dest=$destinationLevel',
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
    totalDistance += _calculateDistance(
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
      totalDistance += _calculateDistance(
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
      '[RouteTracker] 📍 Instrução: "$turnType" em ${totalDistance.toStringAsFixed(1)}m '
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
    if (len1 < 0.001 || len2 < 0.001) {
      return 'straight';
    }

    // Cross product: determina o sentido da curva
    final crossProduct = dx1 * dy2 - dy1 * dx2;

    // Dot product normalizado para calcular o ângulo absoluto
    final dotProduct = (dx1 * dx2 + dy1 * dy2) / (len1 * len2);
    final angleDegrees = acos(dotProduct.clamp(-1.0, 1.0)) * 180 / pi;

    print(
      '[RouteTracker] 🧭 Curva em WP$waypointIndex: ângulo=${angleDegrees.toStringAsFixed(1)}° cross=${crossProduct.toStringAsFixed(0)}',
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
  /// VERSÃO V2 — Snap-to-Edge:
  /// Em vez de apenas verificar distância ponto-a-nó, projeta a posição
  /// do utilizador no segmento de rota mais próximo. Avança o waypoint quando:
  /// 1. O utilizador está a <10 unidades do nó do waypoint, OU
  /// 2. O progresso ao longo do segmento atual é >85% E a distância
  ///    perpendicular ao segmento é <15 unidades (user está "ao lado" da rota)
  void _updateCurrentWaypoint() {
    final searchEnd = min(_currentWaypointIndex + 3, route.waypoints.length);

    for (int i = _currentWaypointIndex; i < searchEnd; i++) {
      final waypoint = route.waypoints[i];
      final coords = getCorrectWaypointCoords(waypoint);
      final pointDist = _calculateDistance(_userX, _userY, coords.x, coords.y);

      // Debug log for current target waypoint
      if (i == _currentWaypointIndex) {
        final node = _nodesMap[waypoint.nodeId];
        print(
          '[RouteTracker] WP$i (${waypoint.nodeId}): PointDist=${pointDist.toStringAsFixed(1)}m, NodeFound=${node != null}',
        );
      }

      // === CHECK 1: Proximidade direta ao nó (threshold aumentado de 8→10) ===
      if (pointDist < 10.0) {
        _currentWaypointIndex = i + 1;
        print('[RouteTracker] ✅ WP$i atingido por proximidade (${pointDist.toStringAsFixed(1)}m)');
        continue; // Verificar o próximo também
      }

      // === CHECK 2: Snap-to-Edge — projeção no segmento ===
      // Verificar se o user "passou" o waypoint ao caminhar ao lado da rota
      if (i == _currentWaypointIndex && i > 0 && i < route.waypoints.length) {
        final prevWp = route.waypoints[i - 1];
        final prevCoords = getCorrectWaypointCoords(prevWp);
        
        // Segmento: prevWaypoint → currentWaypoint
        final segDist = _distanceToSegment(
          _userX, _userY,
          prevCoords.x, prevCoords.y,
          coords.x, coords.y,
        );
        final progress = _progressAlongSegment(
          _userX, _userY,
          prevCoords.x, prevCoords.y,
          coords.x, coords.y,
        );

        print(
          '[RouteTracker] 📐 Segment check WP${i-1}→WP$i: segDist=${segDist.toStringAsFixed(1)}, progress=${(progress * 100).toStringAsFixed(0)}%',
        );

        // Se está perto do segmento E progrediu >85% ao longo dele
        if (segDist < 15.0 && progress > 0.85) {
          _currentWaypointIndex = i + 1;
          print('[RouteTracker] ✅ WP$i atingido por snap-to-edge (progress=${(progress * 100).toStringAsFixed(0)}%, dist=${segDist.toStringAsFixed(1)}m)');
          continue;
        }

        // Se está perto do segmento mas não progrediu muito, está OK — está na rota
        if (segDist < 15.0) {
          break; // Não avançar, user está no caminho certo mas ainda não chegou
        }
      }

      // Se não passou pelo check 1 nem 2 no waypoint atual, parar de verificar
      if (i == _currentWaypointIndex) {
        break;
      }
    }
  }

  /// Calcula a distância perpendicular de um ponto a um segmento de linha.
  /// Retorna a distância mínima entre o ponto (px, py) e o segmento (x1,y1)→(x2,y2).
  double _distanceToSegment(
    double px, double py,
    double x1, double y1,
    double x2, double y2,
  ) {
    final segLenSq = (x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1);
    
    if (segLenSq < 0.001) {
      // Segment é um ponto
      return _calculateDistance(px, py, x1, y1);
    }

    // Projeção paramétrica: t = dot(P-A, B-A) / |B-A|²
    double t = ((px - x1) * (x2 - x1) + (py - y1) * (y2 - y1)) / segLenSq;
    t = t.clamp(0.0, 1.0);

    // Ponto projetado no segmento
    final projX = x1 + t * (x2 - x1);
    final projY = y1 + t * (y2 - y1);

    return _calculateDistance(px, py, projX, projY);
  }

  /// Calcula o progresso (0.0 a 1.0) de um ponto ao longo de um segmento.
  /// 0.0 = no início (x1,y1), 1.0 = no final (x2,y2), >1.0 = passou o final.
  double _progressAlongSegment(
    double px, double py,
    double x1, double y1,
    double x2, double y2,
  ) {
    final segLenSq = (x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1);
    
    if (segLenSq < 0.001) return 1.0; // Segment é um ponto, já "chegou"

    // Projeção (não clampada para mostrar se ultrapassou)
    final t = ((px - x1) * (x2 - x1) + (py - y1) * (y2 - y1)) / segLenSq;
    return t;
  }

  /// Calcula distância euclidiana entre dois pontos
  double _calculateDistance(double x1, double y1, double x2, double y2) {
    final dx = x2 - x1;
    final dy = y2 - y1;
    return sqrt(dx * dx + dy * dy);
  }

  /// Retorna o progresso da rota (0.0 a 1.0)
  double get progress {
    if (route.waypoints.isEmpty) return 0.0;
    return _currentWaypointIndex / route.waypoints.length;
  }
}
