  import 'dart:async';
import '../../map/data/models/route_model.dart';
import '../../map/data/models/node_model.dart';
import '../../map/data/services/routing_service.dart';
import '../../../core/utils/geographic_utils.dart';
import 'tracking/reroute_hysteresis.dart';
import 'tracking/z_axis_guard.dart';

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

  /// Histerese temporal: só dispara reroute se off-route por >= 3s.
  final RerouteHysteresis _hysteresis = RerouteHysteresis(
    offRouteMeters: 20.0,
    sustainedDuration: const Duration(seconds: 3),
    extremeOffRouteMeters: 50.0,
    cooldown: const Duration(seconds: 10),
  );

  /// Indicador externo (opcional) — atalho validado pelo controller
  /// (heading alinhado + velocidade ok). Quando true, hysteresis ignora.
  bool shortcutValid = false;

  /// Devolve true se o utilizador atravessou uma escada/rampa/elevador
  /// recentemente (janela definida pelo controller, ex: 60s). Usado para
  /// validar reroutes que aumentam o número de transições verticais.
  final bool Function()? recentlyCrossedTransitionProvider;

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
    this.recentlyCrossedTransitionProvider,
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
    _hysteresis.reset();
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

    // Histerese temporal: só dispara se off-route sustentado por 3s+
    // (ou desvio extremo > 50m). Atalho validado pelo controller faz override.
    final shouldFire = _hysteresis.shouldTrigger(
      perpDistMeters: minDistanceToRoute,
      now: DateTime.now(),
      atShortcutValid: shortcutValid,
    );

    if (shouldFire) {
      print(
        '[DynamicRouteManager] Hysteresis fired: perp=${minDistanceToRoute.toStringAsFixed(1)}m. Recalculating.',
      );
      await _recalculateRoute(userX, userY);
    } else if (movingAwayFromTarget || movingAwayFromDestination) {
      print(
        '[DynamicRouteManager] Moving-away streak detected (target=$movingAwayFromTarget, dest=$movingAwayFromDestination). Recalculating.',
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

      // Veto da heurística de transições: se a nova rota tem mais
      // stairs/ramp/elevator que a actual (a partir do índice corrente) e
      // o ZAxisGuard não registou transição recente, é quase certo que o
      // backend está a propor uma travessia de piso indevida — descartar.
      final oldTransitions = _countTransitions(
        _currentRoute?.path ?? const [],
        from: currentWaypointIndex,
      );
      final newTransitions = _countTransitions(newRoute.path, from: 0);
      final crossedRecently = recentlyCrossedTransitionProvider?.call() ?? false;
      if (newTransitions > oldTransitions && !crossedRecently) {
        print(
          '[DynamicRouteManager] Reroute rejeitado: nova rota teria '
          '$newTransitions transições vs $oldTransitions actuais '
          '(user não atravessou escadas/rampa recentemente).',
        );
        return;
      }

      _currentRoute = newRoute;
      currentWaypointIndex = 0;
      _lastRouteUpdateTime = DateTime.now();
      _lastDistanceToTarget = null;
      _movingAwayStreak = 0;
      _lastDistanceToDestination = null;
      _movingAwayDestinationStreak = 0;
      _hysteresis.reset();

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

  /// Conta nós de transição (escadas/rampa/elevador) num path a partir do
  /// índice `from`. Usado para detectar reroutes que adicionam travessias
  /// de piso indevidas.
  int _countTransitions(List<PathNode> path, {required int from}) {
    if (path.isEmpty) return 0;
    final nodesMap = {for (var n in allNodes) n.id: n};
    final start = from.clamp(0, path.length);
    int count = 0;
    for (int i = start; i < path.length; i++) {
      final node = nodesMap[path[i].nodeId];
      if (node != null && ZAxisGuard.transitionTypes.contains(node.type)) {
        count++;
      }
    }
    return count;
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
