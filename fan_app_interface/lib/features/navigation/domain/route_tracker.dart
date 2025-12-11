import 'dart:math';
import '../../map/data/models/route_model.dart';
import '../../map/data/models/node_model.dart';
import '../data/models/navigation_instruction.dart';

/// Responsável por rastrear a posição do utilizador na rota
/// e gerar instruções de navegação
class RouteTracker {
  final RouteModel route;
  final List<NodeModel> allNodes;
  
  int _currentWaypointIndex = 0;
  double _userX = 0;
  double _userY = 0;

  RouteTracker({
    required this.route,
    required this.allNodes,
  });

  // Getters para posição atual (para camera follow)
  double get currentX => _userX;
  double get currentY => _userY;
  int get currentWaypointIndex => _currentWaypointIndex;

  /// Atualiza a posição atual do utilizador
  void updateUserPosition(double x, double y) {
    _userX = x;
    _userY = y;
    print('[RouteTracker] Posição atualizada: x=$x, y=$y');
    _updateCurrentWaypoint();
  }

  /// Verifica se utilizador chegou ao destino
  bool get hasArrived {
    if (route.waypoints.isEmpty) return false;
    final lastWaypoint = route.waypoints.last;
    final distToLast = _calculateDistance(_userX, _userY, lastWaypoint.x, lastWaypoint.y);
    // Chegou se está a menos de 3 metros do último waypoint
    return distToLast < 3.0;
  }

  /// Retorna a distância restante total
  double get remainingDistance {
    if (_currentWaypointIndex >= route.waypoints.length) {
      return 0;
    }
    
    // Distância do utilizador até o próximo waypoint
    final nextWaypoint = route.waypoints[_currentWaypointIndex];
    double total = _calculateDistance(_userX, _userY, nextWaypoint.x, nextWaypoint.y);
    
    // Somar distâncias dos waypoints seguintes
    for (int i = _currentWaypointIndex; i < route.waypoints.length - 1; i++) {
      final current = route.waypoints[i];
      final next = route.waypoints[i + 1];
      total += _calculateDistance(current.x, current.y, next.x, next.y);
    }
    
    print('[RouteTracker] Distância restante: ${total.toStringAsFixed(1)}m (waypoint $_currentWaypointIndex/${route.waypoints.length})');
    return total;
  }

  /// Retorna o tempo estimado restante (baseado na distância)
  int get remainingTimeSeconds {
    // Assumir velocidade de caminhada: 1.4 m/s (~5 km/h)
    const walkingSpeed = 1.4;
    return (remainingDistance / walkingSpeed).round();
  }

  /// Gera a próxima instrução de navegação
  NavigationInstruction? getNextInstruction() {
    if (route.waypoints.isEmpty) return null;
    
    // Verificar se chegou ao destino
    final lastWaypoint = route.waypoints.last;
    final distToLast = _calculateDistance(_userX, _userY, lastWaypoint.x, lastWaypoint.y);
    
    if (distToLast < 3.0 || _currentWaypointIndex >= route.waypoints.length - 1) {
      print('[RouteTracker] Chegando ao destino! Distância: ${distToLast.toStringAsFixed(1)}m');
      return NavigationInstruction(
        type: 'arrive',
        distanceToNextTurn: distToLast,
        nodeId: lastWaypoint.nodeId,
      );
    }

    // NOVO: Agrupar waypoints "straight" consecutivos
    int nextTurnIndex = _findNextTurn(_currentWaypointIndex);
    
    // Calcular distância total até a próxima curva (ou destino)
    double totalDistance = 0.0;
    
    // Distância da posição atual até o próximo waypoint
    final nextWaypoint = route.waypoints[(_currentWaypointIndex + 1).clamp(0, route.waypoints.length - 1)];
    totalDistance += _calculateDistance(_userX, _userY, nextWaypoint.x, nextWaypoint.y);
    
    // Somar distâncias dos waypoints intermediários straight
    for (int i = _currentWaypointIndex + 1; i < nextTurnIndex; i++) {
      final wp1 = route.waypoints[i];
      final wp2 = route.waypoints[i + 1];
      totalDistance += _calculateDistance(wp1.x, wp1.y, wp2.x, wp2.y);
    }
    
    // Determinar tipo de instrução (straight ou tipo da próxima curva)
    final turnType = _determineTurnType(nextTurnIndex);
    
    print('[RouteTracker] Próxima instrução: $turnType em ${totalDistance.toStringAsFixed(1)}m (waypoints $_currentWaypointIndex → $nextTurnIndex)');

    return NavigationInstruction(
      type: turnType,
      distanceToNextTurn: totalDistance,
      nodeId: route.waypoints[nextTurnIndex].nodeId,
    );
  }
  
  /// Encontra o índice do próximo waypoint com curva (não-straight)
  int _findNextTurn(int startIndex) {
    // Se já estamos no último ou penúltimo, retornar próximo
    if (startIndex >= route.waypoints.length - 2) {
      return (startIndex + 1).clamp(0, route.waypoints.length - 1);
    }
    
    // Procurar o próximo waypoint que NÃO seja straight
    for (int i = startIndex + 1; i < route.waypoints.length - 1; i++) {
      final turnType = _determineTurnType(i);
      if (turnType != 'straight') {
        return i;
      }
    }
    
    // Se todos são straight até o final, retornar último
    return route.waypoints.length - 1;
  }

  /// Determina o tipo de curva com base no ângulo entre segmentos
  String _determineTurnType(int waypointIndex) {
    if (waypointIndex == 0 || waypointIndex >= route.waypoints.length - 2) {
      return 'straight';
    }

    final prev = route.waypoints[waypointIndex - 1];
    final current = route.waypoints[waypointIndex];
    final next = route.waypoints[waypointIndex + 1];

    // Calcular vetores
    final dx1 = current.x - prev.x;
    final dy1 = current.y - prev.y;
    final dx2 = next.x - current.x;
    final dy2 = next.y - current.y;

    // Calcular ângulo entre vetores
    final angle1 = atan2(dy1, dx1);
    final angle2 = atan2(dy2, dx2);
    var angleDiff = angle2 - angle1;

    // Normalizar para [-π, π]
    while (angleDiff > pi) angleDiff -= 2 * pi;
    while (angleDiff < -pi) angleDiff += 2 * pi;

    final angleDegrees = angleDiff * 180 / pi;

    // Classificar curva
    if (angleDegrees.abs() < 30) {
      return 'straight';
    } else if (angleDegrees > 0) {
      return 'left';
    } else {
      return 'right';
    }
  }

  /// Atualiza o waypoint atual baseado na posição do utilizador
  void _updateCurrentWaypoint() {
    for (int i = _currentWaypointIndex; i < route.waypoints.length; i++) {
      final waypoint = route.waypoints[i];
      final distance = _calculateDistance(_userX, _userY, waypoint.x, waypoint.y);
      
      // Se está a menos de 2 metros do waypoint, avançar para o próximo
      if (distance < 2.0 && i < route.waypoints.length - 1) {
        _currentWaypointIndex = i + 1;
      } else {
        break;
      }
    }
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
