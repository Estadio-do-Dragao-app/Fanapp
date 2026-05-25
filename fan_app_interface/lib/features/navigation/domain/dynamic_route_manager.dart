  import 'dart:async';
import '../../map/data/models/route_model.dart';
import '../../map/data/models/node_model.dart';
import '../../map/data/services/routing_service.dart';
import '../../../core/utils/geographic_utils.dart';

typedef CurrentUserPositionProvider =
  Future<({double x, double y, int level})?> Function();

/// Gestor de rota dinâmica - recalcula automaticamente quando user se desvia
///
/// Atualizado para nova API que usa coordenadas do utilizador
class DynamicRouteManager {
  final RoutingService _routingService;
  final CurrentUserPositionProvider _currentUserPositionProvider;

  // Destination info for recalculation (mutable to support rerouting to a different POI)
  String destinationId;
  String destinationType;
  double destinationX;
  double destinationY;
  int destinationLevel;
  final List<NodeModel> allNodes;
  final bool avoidStairs;

  RouteModel? _currentRoute;
  Timer? _recalculationTimer;
  DateTime? _lastRouteUpdateTime;
  double? _lastDistanceToTarget;
  int _movingAwayStreak = 0;
  double? _lastDistanceToDestination;
  int _movingAwayDestinationStreak = 0;

  // Callbacks
  Function(RouteModel)? onRouteUpdated;

  DynamicRouteManager({
    required this.destinationId,
    required this.destinationType,
    required this.destinationX,
    required this.destinationY,
    required this.destinationLevel,
    required this.allNodes,
    required RouteModel initialRoute,
    this.avoidStairs = false,
    RoutingService? routingService,
    CurrentUserPositionProvider? currentUserPositionProvider,
  }) : _routingService = routingService ?? RoutingService(),
       _currentUserPositionProvider =
           currentUserPositionProvider ?? GeographicUtils.getCurrentUserPosition {
    _currentRoute = initialRoute;
  }

  /// Índice do próximo waypoint na rota atual (segmentos passados são ignorados)
  int currentWaypointIndex = 0;

  RouteModel? get currentRoute => _currentRoute;

  /// Atualiza manualmente a rota atual (ex: por rerouting MQTT)
  void updateRoute(RouteModel newRoute) {
    _currentRoute = newRoute;
    currentWaypointIndex = 0; // reset para nova rota
    _recalculationTimer?.cancel();
    _lastRouteUpdateTime = DateTime.now();
    _lastDistanceToTarget = null;
    _movingAwayStreak = 0;
    _lastDistanceToDestination = null;
    _movingAwayDestinationStreak = 0;
  }

  /// Updates the target destination (e.g. when a reroute goes to a different POI)
  void updateDestination({
    required String destinationId,
    required String destinationType,
    required double destinationX,
    required double destinationY,
    required int destinationLevel,
  }) {
    this.destinationId = destinationId;
    this.destinationType = destinationType;
    this.destinationX = destinationX;
    this.destinationY = destinationY;
    this.destinationLevel = destinationLevel;
    // Reset distance tracking so the new destination is evaluated fresh
    _lastDistanceToDestination = null;
    _movingAwayDestinationStreak = 0;
    print('[DynamicRouteManager] Destination updated to: $destinationId');
  }

  /// Inicia monitorização automática da posição
  void startMonitoring(Stream<({double x, double y})> positionStream) {
    positionStream.listen((position) {
      _checkAndRecalculateIfNeeded(position.x, position.y);
    });
  }

  /// Verifica se user está fora da rota e recalcula
  Future<void> _checkAndRecalculateIfNeeded(double userX, double userY) async {
    if (_currentRoute == null || _currentRoute!.path.isEmpty) return;

    // Não recalcular se já há um recálculo em curso
    if (_recalculationTimer != null && _recalculationTimer!.isActive) return;

    // Criar mapa de nós para lookup O(1)
    final nodesMap = {for (var n in allNodes) n.id: n};
    final movingAwayFromTarget = _isMovingAwayFromNextWaypoint(
      userX,
      userY,
      nodesMap,
    );
    final movingAwayFromDestination = _isMovingAwayFromDestination(userX, userY);

    // Cooldown de 10 seg após receber nova rota (evita loop de rerouting imediato)
    if (_lastRouteUpdateTime != null) {
      if (DateTime.now().difference(_lastRouteUpdateTime!).inSeconds < 10 &&
          !movingAwayFromTarget &&
          !movingAwayFromDestination) {
        return;
      }
    }

    final distanceInfo = _calculateMinDistanceToRoute(userX, userY, nodesMap);
    double minDistanceToRoute = distanceInfo.minDistance;
    int validSegments = distanceInfo.validSegments;

    // Se todos os segmentos têm nós desconhecidos, só recalcular se houver
    // forte evidência de afastamento do próximo objetivo.
    if (validSegments == 0) {
      if (movingAwayFromTarget) {
        print(
          '[DynamicRouteManager] Sem segmentos válidos, mas afastando-se do alvo. Recalculating.',
        );
        await _recalculateRoute(userX, userY);
      } else if (movingAwayFromDestination) {
        print(
          '[DynamicRouteManager] Sem segmentos válidos, mas afastando-se do destino. Recalculating.',
        );
        await _recalculateRoute(userX, userY);
      }
      print('[DynamicRouteManager] Sem segmentos válidos — skip reroute');
      return;
    }

    print(
      '[DynamicRouteManager] Distância à rota: ${minDistanceToRoute.toStringAsFixed(1)}m ($validSegments segmentos válidos)',
    );

    // Threshold mais permissivo: 20m (o backend snapa o início da rota ao nó mais próximo,
    // que pode estar a ~15-20m do GPS do utilizador)
    const double rerouteThreshold = 12.0;
    // Só fazer bypass do cooldown em desvios verdadeiramente extremos (>50m)
    const double extremeDeviation = 35.0;

    if (minDistanceToRoute > extremeDeviation) {
      print(
        '[DynamicRouteManager] EXTREME off-route (${minDistanceToRoute.toStringAsFixed(1)}m). Recalculating.',
      );
      _lastRouteUpdateTime = null; // reset cooldown
      await _recalculateRoute(userX, userY);
    } else if (minDistanceToRoute > rerouteThreshold) {
      print(
        '[DynamicRouteManager] Off-route (${minDistanceToRoute.toStringAsFixed(1)}m > ${rerouteThreshold}m). Recalculating.',
      );
      await _recalculateRoute(userX, userY);
    } else if (movingAwayFromTarget) {
      print(
        '[DynamicRouteManager] Moving away from next waypoint. Recalculating.',
      );
      await _recalculateRoute(userX, userY);
    } else if (movingAwayFromDestination) {
      print(
        '[DynamicRouteManager] Moving away from destination. Recalculating.',
      );
      await _recalculateRoute(userX, userY);
    }
  }

  ({double minDistance, int validSegments}) _calculateMinDistanceToRoute(
    double userX,
    double userY,
    Map<String, NodeModel> nodesMap,
  ) {
    double minDistanceToRoute = double.infinity;
    final startIdx = currentWaypointIndex.clamp(0, _currentRoute!.path.length - 1);
    int validSegments = 0;

    for (int i = startIdx; i < _currentRoute!.path.length - 1; i++) {
      final wp1 = _currentRoute!.path[i];
      final wp2 = _currentRoute!.path[i + 1];

      final node1 = nodesMap[wp1.nodeId];
      final node2 = nodesMap[wp2.nodeId];
      if (node1 == null || node2 == null) continue;

      validSegments++;
      final dist = GeographicUtils.pointToSegmentDistance(
        userX, userY, node1.x, node1.y, node2.x, node2.y,
      );
      if (dist < minDistanceToRoute) minDistanceToRoute = dist;
    }
    return (minDistance: minDistanceToRoute, validSegments: validSegments);
  }

  bool _isMovingAwayFromNextWaypoint(
    double userX,
    double userY,
    Map<String, NodeModel> nodesMap,
  ) {
    if (_currentRoute == null || _currentRoute!.path.isEmpty) return false;

    final targetIdx = currentWaypointIndex.clamp(
      0,
      _currentRoute!.path.length - 1,
    );
    final targetWp = _currentRoute!.path[targetIdx];
    final targetNode = nodesMap[targetWp.nodeId];
    final targetX = targetNode?.x ?? targetWp.x;
    final targetY = targetNode?.y ?? targetWp.y;

    final distToTarget = GeographicUtils.calculateDistance(
      userX,
      userY,
      targetX,
      targetY,
    );

    if (_lastDistanceToTarget != null) {
      final delta = distToTarget - _lastDistanceToTarget!;

      // Afastamento consistente com margem para ruído de GPS
      if (delta > 2.5) {
        _movingAwayStreak++;
      } else if (delta < -1.5) {
        _movingAwayStreak = 0;
      }
    }

    _lastDistanceToTarget = distToTarget;

    // Trigger se já se afastou em 2+ updates e está significativamente longe.
    return _movingAwayStreak >= 2 && distToTarget > 18.0;
  }

  bool _isMovingAwayFromDestination(double userX, double userY) {
    final distToDestination = GeographicUtils.calculateDistance(
      userX,
      userY,
      destinationX,
      destinationY,
    );

    if (_lastDistanceToDestination != null) {
      final delta = distToDestination - _lastDistanceToDestination!;

      // Só contar afastamento relevante para evitar jitter.
      if (delta > 3.0) {
        _movingAwayDestinationStreak++;
      } else if (delta < -2.0) {
        _movingAwayDestinationStreak = 0;
      }
    }

    _lastDistanceToDestination = distToDestination;

    // Trigger se o utilizador se afasta do destino em sequência.
    return _movingAwayDestinationStreak >= 3 && distToDestination > 30.0;
  }

  /// Recalcula rota da posição atual até ao destino
  /// ATUALIZADO: Agora usa coordenadas diretamente para evitar 404 do servidor
  Future<void> _recalculateRoute(double userX, double userY) async {
    // Evitar recálculos múltiplos simultâneos
    if (_recalculationTimer != null && _recalculationTimer!.isActive) return;

    _recalculationTimer = Timer(const Duration(seconds: 3), () {});

    // Usar a posição mais fresca possível antes de pedir nova rota.
    // Evita recalcular com uma amostra antiga e puxar o utilizador para trás.
    final freshPosition = await _currentUserPositionProvider();
    if (freshPosition != null) {
      userX = freshPosition.x;
      userY = freshPosition.y;
    }

    print('[DynamicRouteManager] RECALCULANDO ROTA - User desviou-se!');
    print('[DynamicRouteManager] Posição atual: x=$userX, y=$userY');
    print('[DynamicRouteManager] Destino: x=$destinationX, y=$destinationY');

    try {
      // Determinar o nível atual do utilizador
      final nearestNode = _findNearestNode(userX, userY);
      final currentLevel = nearestNode.level;

      // Tentar a rota pelo ID/Type original primeiro (melhor precisão)
      RouteModel newRoute;
      try {
        newRoute = await _routingService.getRoute(
          startX: userX,
          startY: userY,
          startLevel: currentLevel,
          destinationType: destinationType,
          destinationId: destinationId,
          avoidStairs: avoidStairs,
        );
      } catch (e) {
        print('[DynamicRouteManager] getRoute fallback due to: $e');
        // Calcular nova rota usando coordenadas (evita 404 do lookup de POI fakes)
        newRoute = await _routingService.getRouteToCoordinates(
          start: Coordinates(x: userX, y: userY, level: currentLevel),
          end: Coordinates(x: destinationX, y: destinationY, level: destinationLevel),
          allNodes: allNodes,
          avoidStairs: avoidStairs,
        );
      }

      _currentRoute = newRoute;
      currentWaypointIndex = 0;
      _lastRouteUpdateTime = DateTime.now();
      _lastDistanceToTarget = null;
      _movingAwayStreak = 0;
      _lastDistanceToDestination = null;
      _movingAwayDestinationStreak = 0;

      final nodeIds = newRoute.path.map((p) => p.nodeId).toList();

      print(
        '[DynamicRouteManager] Nova rota calculada: ${newRoute.path.length} waypoints',
      );
      print('[DynamicRouteManager] Nós da nova rota: $nodeIds');

      // Notificar listeners
      onRouteUpdated?.call(newRoute);
    } catch (e) {
      print('[DynamicRouteManager] Erro ao recalcular rota: $e');
    }
  }

  /// Encontra o nó mais próximo da posição atual (para determinar o nível)
  NodeModel _findNearestNode(double x, double y) {
    NodeModel? nearest;
    double minDistance = double.infinity;

    for (final node in allNodes) {
      final distance = GeographicUtils.calculateDistance(x, y, node.x, node.y);

      if (distance < minDistance) {
        minDistance = distance;
        nearest = node;
      }
    }

    return nearest ?? allNodes.first;
  }

  void dispose() {
    _recalculationTimer?.cancel();
  }
}
