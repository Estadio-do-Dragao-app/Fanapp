import 'dart:async';
import '../../map/data/models/route_model.dart';
import '../../map/data/models/node_model.dart';
import '../../map/data/services/routing_service.dart';
import 'dart:math';

/// Gestor de rota dinâmica - recalcula automaticamente quando user se desvia
///
/// Atualizado para nova API que usa coordenadas do utilizador
class DynamicRouteManager {
  final RoutingService _routingService = RoutingService();

  // Destination info for recalculation (usando coordenadas para evitar 404)
  final double destinationX;
  final double destinationY;
  final int destinationLevel;
  final List<NodeModel> allNodes;

  RouteModel? _currentRoute;
  Timer? _recalculationTimer;

  // Callbacks
  Function(RouteModel)? onRouteUpdated;

  DynamicRouteManager({
    required this.destinationX,
    required this.destinationY,
    required this.destinationLevel,
    required this.allNodes,
    required RouteModel initialRoute,
  }) {
    _currentRoute = initialRoute;
  }

  RouteModel? get currentRoute => _currentRoute;

  /// Inicia monitorização automática da posição
  void startMonitoring(Stream<({double x, double y})> positionStream) {
    positionStream.listen((position) {
      _checkAndRecalculateIfNeeded(position.x, position.y);
    });
  }

  /// Verifica se user está fora da rota e recalcula
  Future<void> _checkAndRecalculateIfNeeded(double userX, double userY) async {
    if (_currentRoute == null || _currentRoute!.path.isEmpty) return;

    // Criar mapa de nós para lookup O(1)
    final nodesMap = {for (var n in allNodes) n.id: n};

    // Calcular distância mínima à rota atual
    double minDistanceToRoute = double.infinity;

    for (int i = 0; i < _currentRoute!.path.length - 1; i++) {
      final wp1 = _currentRoute!.path[i];
      final wp2 = _currentRoute!.path[i + 1];

      // Obter coordenadas corretas do Map Service
      final node1 = nodesMap[wp1.nodeId];
      final node2 = nodesMap[wp2.nodeId];

      // Usar coordenadas do Map Service se disponíveis
      final x1 = node1?.x ?? wp1.x;
      final y1 = node1?.y ?? wp1.y;
      final x2 = node2?.x ?? wp2.x;
      final y2 = node2?.y ?? wp2.y;

      final dist = _pointToLineDistance(userX, userY, x1, y1, x2, y2);

      if (dist < minDistanceToRoute) {
        minDistanceToRoute = dist;
      }
    }

    print(
      '[DynamicRouteManager] Distância à rota: ${minDistanceToRoute.toStringAsFixed(1)}m',
    );

    // Se está a mais de 8 metros da rota, recalcular
    if (minDistanceToRoute > 8.0) {
      await _recalculateRoute(userX, userY);
    }
  }

  /// Recalcula rota da posição atual até ao destino
  /// ATUALIZADO: Agora usa coordenadas diretamente para evitar 404 do servidor
  Future<void> _recalculateRoute(double userX, double userY) async {
    // Evitar recálculos múltiplos simultâneos
    if (_recalculationTimer != null && _recalculationTimer!.isActive) return;

    _recalculationTimer = Timer(const Duration(seconds: 3), () {});

    print('[DynamicRouteManager] 🔄 RECALCULANDO ROTA - User desviou-se!');
    print('[DynamicRouteManager] 📍 Posição atual: x=$userX, y=$userY');
    print('[DynamicRouteManager] 🎯 Destino: x=$destinationX, y=$destinationY');

    try {
      // Determinar o nível atual do utilizador
      final nearestNode = _findNearestNode(userX, userY);
      final currentLevel = nearestNode.level;

      // Calcular nova rota usando coordenadas (evita 404 do lookup de POI)
      final newRoute = await _routingService.getRouteToCoordinates(
        startX: userX,
        startY: userY,
        startLevel: currentLevel,
        endX: destinationX,
        endY: destinationY,
        endLevel: destinationLevel,
        allNodes: allNodes,
      );

      _currentRoute = newRoute;

      print(
        '[DynamicRouteManager] ✅ Nova rota calculada: ${newRoute.path.length} waypoints',
      );

      // Notificar listeners
      onRouteUpdated?.call(newRoute);
    } catch (e) {
      print('[DynamicRouteManager] ❌ Erro ao recalcular rota: $e');
    }
  }

  /// Encontra o nó mais próximo da posição atual (para determinar o nível)
  NodeModel _findNearestNode(double x, double y) {
    NodeModel? nearest;
    double minDistance = double.infinity;

    for (final node in allNodes) {
      final distance = sqrt(pow(node.x - x, 2) + pow(node.y - y, 2));

      if (distance < minDistance) {
        minDistance = distance;
        nearest = node;
      }
    }

    return nearest ?? allNodes.first;
  }

  /// Calcula distância de um ponto a uma linha
  double _pointToLineDistance(
    double px,
    double py,
    double x1,
    double y1,
    double x2,
    double y2,
  ) {
    final lineLength = sqrt(pow(x2 - x1, 2) + pow(y2 - y1, 2));

    if (lineLength == 0) {
      return sqrt(pow(px - x1, 2) + pow(py - y1, 2));
    }

    final t = max(
      0.0,
      min(
        1.0,
        ((px - x1) * (x2 - x1) + (py - y1) * (y2 - y1)) / pow(lineLength, 2),
      ),
    );

    final projX = x1 + t * (x2 - x1);
    final projY = y1 + t * (y2 - y1);

    return sqrt(pow(px - projX, 2) + pow(py - projY, 2));
  }

  void dispose() {
    _recalculationTimer?.cancel();
  }
}
