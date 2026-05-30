import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/services/mqtt_service.dart';
import '../../map/data/models/route_model.dart';
import '../../map/data/models/node_model.dart';
import '../../map/data/models/poi_model.dart';
import '../data/models/navigation_instruction.dart';
import '../data/services/user_position_service.dart';
import 'models/reroute_event.dart';
import 'route_tracker.dart';
import 'dynamic_route_manager.dart';
import '../../map/data/services/routing_service.dart';
import '../../../core/utils/geographic_utils.dart';

/// Controlador principal da navegação
/// Gerencia o estado da navegação, tracking de posição e instruções
class NavigationController extends ChangeNotifier {
  final RouteModel initialRoute;
  POIModel destination; // mutable: can change on reroute
  final List<NodeModel> allNodes;
  final double? initialX;
  final double? initialY;
  final int? initialLevel;
  final bool avoidStairs;

  late RouteModel route;
  late RouteTracker _tracker;
  late DynamicRouteManager _routeManager;
  final RoutingService _routingService = RoutingService();
  StreamSubscription<Position>? _gpsSubscription;

  // Stream para monitorizar posição
  final StreamController<({double x, double y})> _positionStream =
      StreamController.broadcast();

  // Stream para alimentar o CurrentLocationLayer com a MESMA posição que
  // o tracker conhece. Garante que o dot do plugin e o início da linha
  // de rota (que usa tracker.currentX/Y) estão sempre sincronizados —
  // sem isto o plugin usa o seu GPS interno e desencontra-se do traço.
  final StreamController<LocationMarkerPosition?> _markerPositionStream =
      StreamController<LocationMarkerPosition?>.broadcast();
  Stream<LocationMarkerPosition?> get markerPositionStream =>
      _markerPositionStream.stream;

  // Stream para eventos de reroute (ex: melhor rota encontrada)
  final StreamController<RerouteEvent> _rerouteStream =
      StreamController.broadcast();
  Stream<RerouteEvent> get rerouteStream => _rerouteStream.stream;

  // Stream that emits the new RouteModel directly when a reroute fires.
  // Consumers subscribe to get the exact object without re-reading _controller.route.
  final StreamController<RouteModel> _routeChangeController =
      StreamController.broadcast();
  Stream<RouteModel> get routeChangeStream => _routeChangeController.stream;

  bool _isDisposed = false;

  // Subscription para MQTT routing stream
  StreamSubscription<Map<String, dynamic>>? _mqttSubscription;

  bool _isNavigating = true;
  NavigationInstruction? _currentInstruction;

  // Heading em graus (0 = Este/Direita, 90 = Sul/Baixo)
  double _heading = 0.0;

  // Piso atual (baseado no waypoint atual)
  int _currentLevel = 0;

  // ── Filtro de ruído GPS ──────────────────────────────────────────────────
  // Última posição aceite como válida
  double? _lastFilteredX;
  double? _lastFilteredY;
  DateTime? _lastFilteredTime;

  // Velocidade máxima plausível para um pedrão a correr: 3.5 m/s (~12.6 km/h)
  // Saltos que impliquem >3× esse valor são descartados como ruído de GPS.
  static const double _maxPlausibleSpeed = 3.5; // m/s
  static const double _noiseMultiplier = 3.0;
  // Se o GPS esteve parado > 10 s (ex: récoupération de sinal), aceitar sempre
  static const Duration _signalGap = Duration(seconds: 10);
  // ──────────────────────────────────────────────────────────────────────────

  bool _isInitializing = true;
  bool get isInitializing => _isInitializing;

  // O desenho da rota deve sempre começar no progresso real do tracker.
  int get routeStartWaypointIndex => _tracker.currentWaypointIndex;

  NavigationController({
    required RouteModel route,
    required this.destination,
    required this.allNodes,
    this.initialX,
    this.initialY,
    this.initialLevel,
    this.avoidStairs = false,
  }) : initialRoute = route,
       _currentLevel = initialLevel ?? 0 {
    this.route = route;
    _tracker = RouteTracker(route: route, allNodes: allNodes);

    // Inicializar gestor de rota dinâmica
    // Usa coordenadas do POI para recalcular rotas quando user se desvia
    _routeManager = DynamicRouteManager(
      destinationId: destination.id,
      destinationType: destination.category == 'seat' ? 'seat' : 'poi',
      destinationX: destination.x,
      destinationY: destination.y,
      destinationLevel: destination.level,
      allNodes: allNodes,
      initialRoute: route,
      avoidStairs: avoidStairs,
      recentlyCrossedTransitionProvider: () {
        final at = _tracker.zGuard.lastVisitedTransitionAt;
        if (at == null) return false;
        return DateTime.now().difference(at) < const Duration(seconds: 60);
      },
    );

    // Callback quando rota é recalculada
    _routeManager.onRouteUpdated = (newRoute) {
      print('[NavigationController]  Rota atualizada! ControllerHash: $hashCode');
      print('[NavigationController]  Old RouteObjHash: ${route.hashCode} Length: ${route.waypoints.length}');
      // CRÍTICO: Preservar posição RAW (GPS cru) antes de recriar tracker
      // Snapped seria a projeção visual; reroute precisa do ponto físico.
      final currentX = _tracker.rawX;
      final currentY = _tracker.rawY;

      final rawNodeIds = newRoute.path.map((p) => p.nodeId).toList();
      print('[NavigationController] Rota recebida (raw): $rawNodeIds');

      final normalizedRoute = _normalizeRouteFromCurrentPosition(
        newRoute,
        currentX,
        currentY,
      );

      final normalizedNodeIds = normalizedRoute.path.map((p) => p.nodeId).toList();
      print('[NavigationController] Rota aplicada (normalized): $normalizedNodeIds');
      // Always create a new RouteModel copy so that Flutter's widget comparison
      // (didUpdateWidget) detects the change even if normalization returned the same object.
      final freshRoute = normalizedRoute.copy();
      print('[NavigationController]  New RouteObjHash: ${freshRoute.hashCode} Length: ${freshRoute.waypoints.length}');

      route = freshRoute;

      _tracker = RouteTracker(route: freshRoute, allNodes: allNodes);
      final seededIndex = _computeSeededWaypointIndex(
        freshRoute,
        currentX,
        currentY,
      );
      _tracker.seedUserPositionForNewRoute(
        currentX,
        currentY,
        level: _currentLevel,
        waypointIndex: seededIndex,
      );
      _routeManager.updateRoute(freshRoute);
      _routeManager.currentWaypointIndex = seededIndex;

      print(
        '[NavigationController] Reroute seeded at WP$seededIndex/${route.waypoints.length} '
        '(user=[$currentX,$currentY], level=$_currentLevel)',
      );
      // Emit the new route directly so listeners get the exact object
      _routeChangeController.add(freshRoute);
      _updateInstruction();
      notifyListeners();
    };

    // Iniciar monitorização
    _routeManager.startMonitoring(_positionStream.stream);

    // Escutar eventos MQTT (Reroute) e guardar subscription
    _mqttSubscription = MqttService().routingStream.listen(_onMqttEvent);

    _initialize();
  }

  // Getters
  bool get isNavigating => _isNavigating;
  NavigationInstruction? get currentInstruction => _currentInstruction;
  double get remainingDistance => _tracker.remainingDistance;
  int get remainingTimeSeconds => _tracker.remainingTimeSeconds;
  double get progress => _tracker.progress;
  bool get hasArrived => _tracker.hasArrived;
  RouteTracker get tracker => _tracker;
  double get heading => _heading;
  int get currentLevel => _currentLevel;

  /// Inicializa o tracking e instruções
  /// Usa posição fornecida, ou carrega do UserPositionService, ou fallback para N1
  void _initialize() async {
    double startX;
    double startY;
    int startLevel =
        _currentLevel; // Inicializar com o nível passado no construtor

    // Sempre tentar obter a posição GPS real - ignora initialX/Y (que podem estar velhos)
    final freshGps = await GeographicUtils.getCurrentUserPosition();
    if (freshGps != null) {
      startX = freshGps.x;
      startY = freshGps.y;
      startLevel = freshGps.level;
      print(
        '[NavigationController]  GPS fresco obtido: ($startX, $startY, level=$startLevel)',
      );
    } else if (initialX != null && initialY != null) {
      // Fallback: usar posição passada como parâmetro
      startX = initialX!;
      startY = initialY!;
      if (initialLevel != null) startLevel = initialLevel!;
      print(
        '[NavigationController]  Usando posição fornecida (sem GPS): ($startX, $startY, level=$startLevel)',
      );
    } else {
      // Último recurso: UserPositionService
      final savedPosition = await UserPositionService.getPosition();
      if (savedPosition != null) {
        startX = savedPosition.x;
        startY = savedPosition.y;
        startLevel = savedPosition.level;
        print(
          '[NavigationController]  Posição carregada do serviço: ($startX, $startY, level=$startLevel)',
        );
      } else {
        // Fallback: This should never be reached if UI checks work.
        // If we reach here without GPS, throw an exception.
        throw Exception(
          "Cannot calculate route without GPS location. Ensure position is obtained before navigating.",
        );
      }
    }

    // Usar nível do utilizador (não do primeiro waypoint!)
    _currentLevel = startLevel;
    print('[NavigationController]  Nível inicial: $_currentLevel');

    _tracker.updateUserPosition(startX, startY, level: _currentLevel);

    // VERIFICAÇÃO CRÍTICA: Se a posição real estiver muito longe do início da rota (> 50m)
    // recalcular imediatamente ANTES de terminar a inicialização para evitar mostrar 10km+ ao user.
    final firstWp = route.waypoints.first;
    final firstWpCoords = GeographicUtils.calculateDistance(
      startX,
      startY,
      firstWp.x,
      firstWp.y,
    );

    if (firstWpCoords > 50.0) {
      print(
        '[NavigationController] Posição inicial está longe da rota ($firstWpCoords m). Forçando recálculo...',
      );
      try {
        final newRoute = await _routingService.getRoute(
          startX: startX,
          startY: startY,
          startLevel: _currentLevel,
          destinationType: destination.category == 'seat' ? 'seat' : 'poi',
          destinationId: destination.id,
          avoidStairs: avoidStairs,
        );
        final normalizedRoute = _normalizeRouteFromCurrentPosition(
          newRoute,
          startX,
          startY,
        );
        route = normalizedRoute.copy();
        _tracker = RouteTracker(route: route, allNodes: allNodes);
        final seededIndex = _computeSeededWaypointIndex(
          normalizedRoute,
          startX,
          startY,
        );
        _tracker.seedUserPositionForNewRoute(
          startX,
          startY,
          level: _currentLevel,
          waypointIndex: seededIndex,
        );
        _routeManager.updateRoute(normalizedRoute);
        _routeManager.currentWaypointIndex = seededIndex;
      } catch (e) {
        print('[NavigationController] Erro no recálculo inicial: $e');
      }
    }

    _isInitializing = false;
    _updateInstruction();
    notifyListeners();

    print(
      '[NavigationController]  Start check: RouteLen=${route.waypoints.length}, HasArrived=${_tracker.hasArrived}',
    );

    // Check for immediate arrival (e.g. route to current location)
    if (_tracker.hasArrived) {
      print('[NavigationController]  Immediate arrival detected at start.');
      _onArrival();
      return;
    }

    // Iniciar navegação real baseada em GPS
    _startGpsTracking();
  }

  Future<void> _startGpsTracking() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    final locationSettings = const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 2, // Update events when user moves 2 meters
    );

    _gpsSubscription =
        Geolocator.getPositionStream(
          locationSettings: locationSettings,
        ).listen((Position position) {
          if (!_isNavigating || _isDisposed) return;

          // Update heading based on device movement
          if (position.heading > 0) {
            _heading = position.heading;
          }

          final newX = position.longitude;
          final newY = position.latitude;

          // ── Filtro de ruído GPS ──────────────────────────────────────
          if (_lastFilteredX != null && _lastFilteredTime != null) {
            final timeDelta =
                DateTime.now().difference(_lastFilteredTime!).inMilliseconds /
                1000.0;

            // Se há menos de 10 s desde a última posição válida,
            // verificar se a velocidade implicada é plausível.
            if (timeDelta < _signalGap.inSeconds.toDouble() && timeDelta > 0) {
              final dist = GeographicUtils.calculateDistance(
                _lastFilteredX!,
                _lastFilteredY!,
                newX,
                newY,
              );
              final impliedSpeed = dist / timeDelta; // m/s

              if (impliedSpeed > _maxPlausibleSpeed * _noiseMultiplier) {
                print(
                  '[NavigationController] GPS NOISE ignored: '
                  'impliedSpeed=${impliedSpeed.toStringAsFixed(1)} m/s '
                  '(limit=${(_maxPlausibleSpeed * _noiseMultiplier).toStringAsFixed(1)} m/s), '
                  'jump=${dist.toStringAsFixed(1)}m in ${timeDelta.toStringAsFixed(1)}s',
                );
                return; // descartar esta posição
              }
            }
          }

          // Posição aceite — actualizar filtro
          _lastFilteredX = newX;
          _lastFilteredY = newY;
          _lastFilteredTime = DateTime.now();
          // ─────────────────────────────────────────────────────────────

          // Update position on map/tracker
          updateUserPosition(newX, newY);

          // Emit to trigger dynamic route manager updates
          _positionStream.add((x: newX, y: newY));

          // Emit to plugin so the dot moves at the same time the trace moves.
          if (!_markerPositionStream.isClosed) {
            _markerPositionStream.add(
              LocationMarkerPosition(
                latitude: newY,
                longitude: newX,
                accuracy: position.accuracy,
              ),
            );
          }
        });
  }

  /// Pausar GPS tracking (ex: antes de recalcular rota)
  void pauseGpsTracking() {
    _gpsSubscription?.pause();
    print('[NavigationController] GPS tracking paused');
  }

  /// Retomar GPS tracking após pausa
  void resumeGpsTracking() {
    if (_isNavigating &&
        _gpsSubscription != null &&
        _gpsSubscription!.isPaused) {
      print('[NavigationController] GPS tracking resumed');
      _gpsSubscription?.resume();
    }
  }

  /// Atualiza a instrução atual
  void _updateInstruction() {
    _currentInstruction = _tracker.getNextInstruction();
    notifyListeners();
  }

  /// Atualiza posição (para integração com GPS real)
  void updateUserPosition(double x, double y) {
    // Atualizar piso candidato via nó mais próximo. O ZAxisGuard interno
    // do tracker decide se aceita a transição (precisa de stairs/ramp na rota).
    final candidateLevel = _findNearestNode(x, y).level;
    _tracker.updateUserPosition(x, y, level: candidateLevel);
    _currentLevel = _tracker.currentLevel; // pode ter sido rejeitado pelo z-guard

    // Sincronizar o índice de progresso com o gestor de rota dinâmica
    // para que a verificação off-route ignore segmentos já ultrapassados
    _routeManager.currentWaypointIndex = _tracker.currentWaypointIndex;

    // Sinalizar atalho válido (heading alinhado + a mover-se) ao gestor
    // de rota dinâmica para suprimir trigger de hysteresis prematuro.
    final hv = _tracker.lastHeadingValidation;
    _routeManager.shortcutValid =
        hv != null && hv.isMovingForward && hv.isAlignedWithReference;

    _updateInstruction();

    if (_tracker.hasArrived) {
      _onArrival();
    }
  }

  /// Chamado quando utilizador chega ao destino
  void _onArrival() async {
    _isNavigating = false;
    _gpsSubscription?.cancel();

    // Guardar posição final como nova posição do usuário (GPS cru)
    final finalX = _tracker.rawX;
    final finalY = _tracker.rawY;
    final finalNode = _findNearestNode(finalX, finalY);

    await UserPositionService.savePosition(
      x: finalX,
      y: finalY,
      nodeId: finalNode.id,
      level: _currentLevel,
    );
    print(
      '[NavigationController] Posição final guardada: x=$finalX, y=$finalY, node=${finalNode.id}',
    );

    notifyListeners();
  }

  /// Termina a navegação manualmente
  Future<void> endNavigation() async {
    _isNavigating = false;
    _gpsSubscription?.cancel();

    // Guardar posição atual antes de sair (GPS cru)
    final finalX = _tracker.rawX;
    final finalY = _tracker.rawY;
    final finalNode = _findNearestNode(finalX, finalY);

    await UserPositionService.savePosition(
      x: finalX,
      y: finalY,
      nodeId: finalNode.id,
      level: _currentLevel,
    );
    print(
      '[NavigationController] Posição guardada ao terminar: x=$finalX, y=$finalY, node=${finalNode.id}',
    );

    notifyListeners();
  }

  /// Utiliza IDs de nós para reconstruir rota completa
  void applyNewRoute(List<String> nodeIds) {
    if (nodeIds.isEmpty) return;

    print(
      '[NavigationController]  Applying new route with ${nodeIds.length} nodes',
    );

    final currentX = _tracker.rawX;
    final currentY = _tracker.rawY;

    // Mapear IDs para NodeModels
    final nodesMap = {for (var n in allNodes) n.id: n};
    final rawPath = <PathNode>[];
    double cumulativeDist = 0;
    double cumulativeTime = 0;

    for (int i = 0; i < nodeIds.length; i++) {
      final id = nodeIds[i];
      final node = nodesMap[id];
      if (node == null) continue;

      if (i > 0) {
        final prevId = nodeIds[i - 1];
        final prevNode = nodesMap[prevId];
        if (prevNode != null) {
          final dist = GeographicUtils.calculateDistance(
            prevNode.x,
            prevNode.y,
            node.x,
            node.y,
          );
          cumulativeDist += dist;
          cumulativeTime += dist / 1.4; // 1.4 m/s walking speed
        }
      }

      rawPath.add(
        PathNode(
          nodeId: id,
          x: node.x,
          y: node.y,
          level: node.level,
          distanceFromStart: cumulativeDist,
          estimatedTime: cumulativeTime,
        ),
      );
    }

    // Criar RouteModel bruto
    final rawRouteModel = RouteModel(
      path: rawPath,
      totalDistance: cumulativeDist,
      estimatedTime: cumulativeTime,
      congestionLevel: 0,
      warnings: [],
    );

    // Normalizar: remover nós que ficaram atrás do utilizador
    final newRouteModel = _normalizeRouteFromCurrentPosition(
      rawRouteModel,
      currentX,
      currentY,
    );

    // Always create a new RouteModel copy so that Flutter's widget comparison
    // (didUpdateWidget) detects the change even if normalization returned the same object.
    final freshRouteModel = newRouteModel.copy();
    route = freshRouteModel;
    _routeManager.updateRoute(freshRouteModel);

    // Recriar tracker e semear na posição correta
    _tracker = RouteTracker(route: freshRouteModel, allNodes: allNodes);
    final seededIndex = _computeSeededWaypointIndex(
      freshRouteModel,
      currentX,
      currentY,
    );
    _tracker.seedUserPositionForNewRoute(
      currentX,
      currentY,
      level: _currentLevel,
      waypointIndex: seededIndex,
    );
    _routeManager.currentWaypointIndex = seededIndex;

    _updateInstruction();

    // Reiniciar navegação baseada no GPS
    _isNavigating = true;
    resumeGpsTracking();

    print(
      '[NavigationController]  New route applied: '
      '${newRouteModel.waypoints.length} waypoints, seeded at WP$seededIndex',
    );

    // Emit the new route directly so listeners get the exact object
    _routeChangeController.add(freshRouteModel);
    notifyListeners();
  }

  /// Updates the active destination POI (e.g. after a reroute to a different place)
  void updateDestination(POIModel newDestination) {
    destination = newDestination;
    // Sync the dynamic route manager with the new target
    _routeManager.updateDestination(
      destinationId: newDestination.id,
      destinationType: newDestination.category == 'seat' ? 'seat' : 'poi',
      destinationX: newDestination.x,
      destinationY: newDestination.y,
      destinationLevel: newDestination.level,
    );
    print('[NavigationController] Destination updated to: ${newDestination.id} (${newDestination.name})');
    notifyListeners();
  }

  /// Processa eventos recebidos via MQTT
  void _onMqttEvent(Map<String, dynamic> event) {
    if (_isDisposed) {
      // Controller disposed, ignore any incoming MQTT events
      print('[NavigationController]  Ignoring MQTT event after dispose');
      return;
    }

    final eventType = event['type'] as String?;

    // Handle evacuation routes (emergency)
    if (eventType == 'evacuation') {
      print('[NavigationController]  EVACUATION route received!');
      try {
        final routeIds = List<String>.from(event['route'] ?? []);
        if (routeIds.isNotEmpty) {
          print(
            '[NavigationController]  Applying evacuation route with ${routeIds.length} nodes',
          );
          print(
            '[NavigationController]  Keeping user at current position: (${_tracker.currentX}, ${_tracker.currentY})',
          );

          // STOP GPS tracking temporarily
          pauseGpsTracking();
          _isNavigating = false;

          // applyNewRoute preserves current position (X, Y coordinates)
          applyNewRoute(routeIds);

          // DO NOT restart auto-navigation - user keeps current position
          // The route is now displayed and user can follow it manually
        }
      } catch (e) {
        print('[NavigationController]  Error applying evacuation route: $e');
      }
      return;
    }

    // Handle reroute suggestions
    if (eventType == 'reroute_suggestion') {
      print('[NavigationController]  MQTT Reroute Suggestion received: $event');
      try {
        // Parse payload (flat structure from backend)
        final improvement = event['improvement'] as Map<String, dynamic>?;
        final newRoute = List<String>.from(event['new_route'] ?? []);

        // Calcular novos valores baseados na melhoria
        final timeSavedSeconds =
            (improvement?['time_saved_seconds'] as num?)?.toInt() ?? 0;
        // Nova duração = Duração atual - Tempo poupado
        final currentRemainingSeconds = remainingTimeSeconds;
        final newDurationSeconds = (currentRemainingSeconds - timeSavedSeconds)
            .clamp(60, 86400); // Mínimo 1 min

        // Formatar nova duração
        final newDurationMinutes = (newDurationSeconds / 60).ceil();
        final newDurationDisplay = newDurationMinutes < 60
            ? '$newDurationMinutes min'
            : '${newDurationMinutes ~/ 60}h ${newDurationMinutes % 60}m';

        // Calcular nova hora de chegada
        final now = DateTime.now();
        final newArrival = now.add(Duration(seconds: newDurationSeconds));
        final newArrivalDisplay =
            '${newArrival.hour}:${newArrival.minute.toString().padLeft(2, '0')}';

        // Calcular distância da nova rota
        double newRouteDistance = 0;
        if (newRoute.isNotEmpty) {
          final nodesMap = {for (var n in allNodes) n.id: n};
          for (int i = 0; i < newRoute.length - 1; i++) {
            final nodeA = nodesMap[newRoute[i]];
            final nodeB = nodesMap[newRoute[i + 1]];
            if (nodeA != null && nodeB != null) {
              final dx = nodeA.x - nodeB.x;
              final dy = nodeA.y - nodeB.y;
              newRouteDistance += math.sqrt(dx * dx + dy * dy);
            }
          }
        }

        final rerouteEvent = RerouteEvent(
          arrivalTime: newArrivalDisplay, // "14:30"
          duration: newDurationDisplay, // "15 min"
          distance: newRouteDistance.round(), // Distância real calculada
          locationName: event['new_destination'] ?? "Better Route Found",
          newDestinationId:
              event['new_destination'] ?? '', // O novo POI de destino
          category:
              event['category']
                  as String?, // POI category for nearest_category lookup
          reason: event['reason'] ?? 'Better route found',
          newRouteIds: newRoute,
        );
        if (!_isDisposed) {
          _rerouteStream.add(rerouteEvent);
        } else {
          print(
            '[NavigationController]  Tried to add reroute event after dispose',
          );
        }
      } catch (e) {
        print('[NavigationController]  Error parsing reroute event: $e');
      }
    }
  }

  @override
  void dispose() {
    print('[NavigationController]  Disposing controller...');
    _isDisposed = true;
    if (_mqttSubscription != null) {
      print('[NavigationController]  Cancelling MQTT subscription');
      _mqttSubscription?.cancel();
      _mqttSubscription = null;
    }
    _gpsSubscription?.cancel();
    _positionStream.close();
    _markerPositionStream.close();
    _rerouteStream.close();
    _routeChangeController.close();
    _routeManager.dispose();
    print('[NavigationController]  Dispose complete');
    super.dispose();
  }

  /// Formata tempo restante para exibição (ex: "5 min", "1h 20m")
  String get formattedRemainingTime {
    final minutes = (remainingTimeSeconds / 60).ceil();

    if (minutes < 1) {
      return '<1 min';
    } else if (minutes < 60) {
      return '$minutes min';
    } else {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      return '${hours}h ${mins}m';
    }
  }

  /// Formata distância restante (ex: "40 m", "1.2 km")
  String get formattedRemainingDistance {
    if (remainingDistance < 1000) {
      return '${remainingDistance.round()} m';
    } else {
      return '${(remainingDistance / 1000).toStringAsFixed(1)} km';
    }
  }

  /// Encontra nó mais próximo de uma posição
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

  /// Remove prefixo de waypoints atrás do utilizador após reroute.
  ///
  /// O backend pode incluir 1-2 nós iniciais de "snap" que ficam para trás,
  /// o que faz o mapa/instrução parecer voltar ao ponto antigo.
  RouteModel _normalizeRouteFromCurrentPosition(
    RouteModel rawRoute,
    double userX,
    double userY,
  ) {
    if (rawRoute.path.length < 3) return rawRoute;

    final nodesMap = {for (var n in allNodes) n.id: n};

    int nearestIndex = 0;
    double nearestDistance = double.infinity;

    for (int i = 0; i < rawRoute.path.length; i++) {
      final wp = rawRoute.path[i];
      final node = nodesMap[wp.nodeId];
      final wpX = node?.x ?? wp.x;
      final wpY = node?.y ?? wp.y;

      final dist = GeographicUtils.calculateDistance(userX, userY, wpX, wpY);
      if (dist < nearestDistance) {
        nearestDistance = dist;
        nearestIndex = i;
      }
    }

    // Só corta o prefixo quando a diferença é clara e segura.
    if (nearestIndex <= 0 || nearestDistance > 35.0) {
      return rawRoute;
    }

    final first = rawRoute.path.first;
    final firstNode = nodesMap[first.nodeId];
    final firstX = firstNode?.x ?? first.x;
    final firstY = firstNode?.y ?? first.y;
    final distanceToFirst = GeographicUtils.calculateDistance(
      userX,
      userY,
      firstX,
      firstY,
    );

    if (distanceToFirst - nearestDistance < 8.0) {
      print(
        '[NavigationController] Reroute kept raw prefix: nearestIdx=$nearestIndex '
        'nearest=${nearestDistance.toStringAsFixed(1)}m first=${distanceToFirst.toStringAsFixed(1)}m',
      );
      return rawRoute;
    }

    final trimmed = rawRoute.path.skip(nearestIndex).toList();
    if (trimmed.length < 2) {
      return rawRoute;
    }

    // Recalcular métricas para manter consistência com o path aparado.
    final removedDistance = trimmed.first.distanceFromStart;
    final removedTime = trimmed.first.estimatedTime;
    final adjustedDistance = (rawRoute.totalDistance - removedDistance).clamp(
      0.0,
      double.infinity,
    );
    final adjustedTime = (rawRoute.estimatedTime - removedTime).clamp(
      0.0,
      double.infinity,
    );

    print(
      '[NavigationController] Reroute trimmed prefix: drop=$nearestIndex '
      'nearest=${nearestDistance.toStringAsFixed(1)}m first=${distanceToFirst.toStringAsFixed(1)}m '
      'len=${rawRoute.path.length}->${trimmed.length}',
    );

    return RouteModel(
      path: trimmed,
      totalDistance: adjustedDistance,
      estimatedTime: adjustedTime,
      congestionLevel: rawRoute.congestionLevel,
      waitTime: rawRoute.waitTime,
      warnings: rawRoute.warnings,
    );
  }

  int _computeSeededWaypointIndex(
    RouteModel route,
    double userX,
    double userY,
  ) {
    if (route.waypoints.length <= 1) return 0;

    final nodesMap = {for (var n in allNodes) n.id: n};
    final lookAhead = route.waypoints.length < 4 ? route.waypoints.length : 4;

    int nearestIdx = 0;
    double nearestDist = double.infinity;

    for (int i = 0; i < lookAhead; i++) {
      final wp = route.waypoints[i];
      final node = nodesMap[wp.nodeId];
      final wpX = node?.x ?? wp.x;
      final wpY = node?.y ?? wp.y;
      final dist = GeographicUtils.calculateDistance(userX, userY, wpX, wpY);

      if (dist < nearestDist) {
        nearestDist = dist;
        nearestIdx = i;
      }
    }

    // Só arrancar à frente quando há evidência clara e próxima.
    if (nearestIdx > 0 && nearestDist < 10.0) {
      return nearestIdx;
    }
    return 0;
  }
}
