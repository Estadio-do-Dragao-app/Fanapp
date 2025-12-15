import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/services/mqtt_service.dart';
import '../../map/data/models/route_model.dart';
import '../../map/data/models/node_model.dart';
import '../../map/data/models/poi_model.dart';
import '../data/models/navigation_instruction.dart';
import '../data/services/user_position_service.dart';
import 'models/reroute_event.dart';
import 'route_tracker.dart';
import 'dynamic_route_manager.dart';

/// Controlador principal da navegação
/// Gerencia o estado da navegação, tracking de posição e instruções
class NavigationController extends ChangeNotifier {
  final RouteModel initialRoute;
  final POIModel destination;
  final List<NodeModel> allNodes;
  final double? initialX;
  final double? initialY;
  final int? initialLevel;

  late RouteModel route;
  late RouteTracker _tracker;
  late DynamicRouteManager _routeManager;
  Timer? _updateTimer;

  // Stream para monitorizar posição
  final StreamController<({double x, double y})> _positionStream =
      StreamController.broadcast();

  // Stream para eventos de reroute (ex: melhor rota encontrada)
  final StreamController<RerouteEvent> _rerouteStream =
      StreamController.broadcast();
  Stream<RerouteEvent> get rerouteStream => _rerouteStream.stream;
  bool _isDisposed = false;
  
  // Subscription para MQTT routing stream
  StreamSubscription<Map<String, dynamic>>? _mqttSubscription;

  bool _isNavigating = true;
  NavigationInstruction? _currentInstruction;

  // Heading em graus (0 = Este/Direita, 90 = Sul/Baixo)
  double _heading = 0.0;

  // Piso atual (baseado no waypoint atual)
  int _currentLevel = 0;

  NavigationController({
    required RouteModel route,
    required this.destination,
    required this.allNodes,
    this.initialX,
    this.initialY,
    this.initialLevel,
  }) : initialRoute = route,
       _currentLevel = initialLevel ?? 0 {
    this.route = route;
    _tracker = RouteTracker(route: route, allNodes: allNodes);

    // Inicializar gestor de rota dinâmica
    // Usa coordenadas do POI para recalcular rotas quando user se desvia
    _routeManager = DynamicRouteManager(
      destinationX: destination.x,
      destinationY: destination.y,
      destinationLevel: destination.level,
      allNodes: allNodes,
      initialRoute: route,
    );

    // Callback quando rota é recalculada
    _routeManager.onRouteUpdated = (newRoute) {
      print('[NavigationController] 🔄 Rota atualizada!');
      route = newRoute;
      // CRÍTICO: Preservar posição atual antes de recriar tracker
      final currentX = _tracker.currentX;
      final currentY = _tracker.currentY;
      _tracker = RouteTracker(route: newRoute, allNodes: allNodes);
      _tracker.updateUserPosition(currentX, currentY);
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

    if (initialX != null && initialY != null) {
      // Usar posição passada como parâmetro
      startX = initialX!;
      startY = initialY!;
      // Se initialLevel foi fornecido, usá-lo, caso contrário, carregar do serviço
      if (initialLevel != null) {
        startLevel = initialLevel!;
      } else {
        final savedPosition = await UserPositionService.getPosition();
        startLevel = savedPosition.level;
      }
      print(
        '[NavigationController] 📍 Usando posição fornecida: ($startX, $startY, level=$startLevel)',
      );
    } else {
      // Carregar posição do UserPositionService
      final savedPosition = await UserPositionService.getPosition();
      if (savedPosition.x != 0.0 || savedPosition.y != 0.0) {
        startX = savedPosition.x;
        startY = savedPosition.y;
        startLevel = savedPosition.level;
        print(
          '[NavigationController] 📍 Posição carregada do serviço: ($startX, $startY, level=$startLevel)',
        );
      } else {
        // Fallback: usar N1
        final userNode = allNodes.firstWhere(
          (n) => n.id == 'N1',
          orElse: () => allNodes.first,
        );
        startX = userNode.x;
        startY = userNode.y;
        startLevel = userNode.level;
        print(
          '[NavigationController] 📍 Fallback para nó ${userNode.id}: ($startX, $startY, level=$startLevel)',
        );
      }
    }

    // Usar nível do utilizador (não do primeiro waypoint!)
    _currentLevel = startLevel;
    print('[NavigationController] 🏢 Nível inicial: $_currentLevel');

    _tracker.updateUserPosition(startX, startY, level: _currentLevel);
    _updateInstruction();
    notifyListeners();

    // Iniciar navegação automática
    _startAutoNavigation();
    
    // Iniciar timer para guardar posição periodicamente (para emergências)
    _startPositionSaveTimer();
  }

  // Timer para navegação automática
  Timer? _autoNavTimer;
  // Timer para guardar posição periodicamente
  Timer? _positionSaveTimer;
  int _targetWaypointIndex = 0;

  /// Inicia timer para guardar posição periodicamente durante navegação
  void _startPositionSaveTimer() {
    _positionSaveTimer?.cancel();
    _positionSaveTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!_isNavigating) {
        timer.cancel();
        return;
      }
      
      // Guardar posição atual para uso em caso de emergência
      final currentX = _tracker.currentX;
      final currentY = _tracker.currentY;
      final nearestNode = _findNearestNode(currentX, currentY);
      
      await UserPositionService.savePosition(
        x: currentX,
        y: currentY,
        nodeId: nearestNode.id,
        level: _currentLevel,
      );
    });
  }

  /// Inicia navegação automática ao longo da rota
  void _startAutoNavigation() {
    if (route.waypoints.isEmpty) return;

    _targetWaypointIndex = 0;

    // Mover a cada 100ms para movimento suave
    _autoNavTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!_isNavigating || _tracker.hasArrived) {
        timer.cancel();
        return;
      }

      _moveTowardsNextWaypoint();
    });
  }

  /// Pause auto-navigation (called before route recalculation)
  void pauseAutoNavigation() {
    _autoNavTimer?.cancel();
    _autoNavTimer = null;
    print('[NavigationController] ⏸️ Auto-navigation paused');
  }

  /// Move o utilizador gradualmente em direção ao próximo waypoint
  void _moveTowardsNextWaypoint() {
    if (route.waypoints.isEmpty) return;

    // Obter coordenadas corretas do waypoint alvo
    final nodesMap = {for (var n in allNodes) n.id: n};

    // Encontrar o próximo waypoint que ainda não foi atingido
    while (_targetWaypointIndex < route.waypoints.length) {
      final targetWp = route.waypoints[_targetWaypointIndex];
      final node = nodesMap[targetWp.nodeId];
      final targetX = node?.x ?? targetWp.x;
      final targetY = node?.y ?? targetWp.y;
      final targetLevel = node?.level ?? targetWp.level;

      final currentX = _tracker.currentX;
      final currentY = _tracker.currentY;

      final dx = targetX - currentX;
      final dy = targetY - currentY;
      final distance = math.sqrt(dx * dx + dy * dy);

      // Se chegou ao waypoint atual (menos de 1.5 unidades), passar para o próximo
      if (distance < 1.5) {
        // Verificar mudança de piso ao atingir waypoint de escadas/rampa
        if (targetLevel != _currentLevel) {
          print(
            '[NavigationController] 🪜 Mudança de piso: $_currentLevel -> $targetLevel',
          );
          _currentLevel = targetLevel;
          // Atualizar nível no tracker também!
          _tracker.updateUserPosition(
            _tracker.currentX,
            _tracker.currentY,
            level: _currentLevel,
          );
          notifyListeners(); // Notificar UI para mudar o piso do mapa
        }
        _targetWaypointIndex++;
        continue;
      }

      // Velocidade de caminhada: ~2 unidades por tick (mais lento e natural)
      const speed = 2.0;

      // Calcular movimento normalizado
      final moveX = (dx / distance) * math.min(speed, distance);
      final moveY = (dy / distance) * math.min(speed, distance);

      // Calcular heading para a direção do movimento
      // atan2(dy, dx) retorna ângulo em radianos onde 0 = direita
      // Convertemos para sistema onde 0 = cima (norte)
      // O ícone Icons.navigation aponta para CIMA por defeito
      _heading = math.atan2(dx, -dy) * (180.0 / math.pi);
      // Normalizar para 0-360
      if (_heading < 0) _heading += 360;

      // Mover utilizador
      moveUser(moveX, moveY);
      return;
    }

    // Chegou ao destino
    _autoNavTimer?.cancel();
  }

  /// Roda o utilizador em graus (positivo = horário)
  void rotateUser(double degrees) {
    _heading += degrees;
    // Normalizar para 0-360
    _heading = _heading % 360;
    if (_heading < 0) _heading += 360;
    notifyListeners();
  }

  /// Move para a frente na direção do heading atual
  void moveForward(double meters) {
    // Converter heading para radianos
    // Sistema de Navegação (Bearing):
    // 0 graus = Norte/Cima (Eixo Y negativo)
    // 90 graus = Este/Direita (Eixo X positivo)
    // 180 graus = Sul/Baixo (Eixo Y positivo)
    final rad = _heading * (math.pi / 180.0);

    // Bearing formulas for screen coordinates (Y is Down):
    // dX = meters * sin(theta)
    // dY = meters * -cos(theta)

    // Check: 0 deg -> sin(0)=0, -cos(0)=-1 -> (0, -1) -> Up. Correct.
    // Check: 90 deg -> sin(90)=1, -cos(90)=0 -> (1, 0) -> Right. Correct.

    final deltaX = meters * math.sin(rad);
    final deltaY = meters * -math.cos(rad);

    moveUser(deltaX, deltaY);
  }

  /// Atualiza a instrução atual
  void _updateInstruction() {
    _currentInstruction = _tracker.getNextInstruction();
    notifyListeners();
  }

  /// Atualiza posição manualmente (para integração com GPS real)
  void updateUserPosition(double x, double y) {
    _tracker.updateUserPosition(x, y);
    _updateInstruction();

    if (_tracker.hasArrived) {
      _onArrival();
    }
  }

  /// Move utilizador de forma incremental (para controlos manuais)
  void moveUser(double deltaX, double deltaY) {
    final newX = _tracker.currentX + deltaX;
    final newY = _tracker.currentY + deltaY;
    _tracker.updateUserPosition(newX, newY);

    // Só atualizar instrução se ainda não chegou
    if (!_tracker.hasArrived) {
      _updateInstruction();
    }

    // Emitir posição para monitorização de rota
    _positionStream.add((x: newX, y: newY));

    if (_tracker.hasArrived) {
      _onArrival();
    }
  }

  void goToNextWaypoint() {
    final nextIndex = _tracker.currentWaypointIndex + 1;
    if (nextIndex < route.waypoints.length) {
      final waypoint = route.waypoints[nextIndex];
      _tracker.updateUserPosition(waypoint.x, waypoint.y);
      _updateInstruction();

      if (_tracker.hasArrived) {
        _onArrival();
      }
    }
  }

  /// Volta ao waypoint anterior (controlo manual para emulador)
  void goToPreviousWaypoint() {
    final prevIndex = _tracker.currentWaypointIndex - 1;
    if (prevIndex >= 0) {
      final waypoint = route.waypoints[prevIndex];
      _tracker.updateUserPosition(waypoint.x, waypoint.y);
      _updateInstruction();
    }
  }



  /// Chamado quando utilizador chega ao destino
  void _onArrival() async {
    _isNavigating = false;
    _updateTimer?.cancel();

    // Guardar posição final como nova posição do usuário
    final finalX = _tracker.currentX;
    final finalY = _tracker.currentY;
    final finalNode = _findNearestNode(finalX, finalY);

    await UserPositionService.savePosition(
      x: finalX,
      y: finalY,
      nodeId: finalNode.id,
      level: _currentLevel,
    );
    print(
      '[NavigationController] 💾 Posição final guardada: x=$finalX, y=$finalY, node=${finalNode.id}',
    );

    notifyListeners();
  }

  /// Termina a navegação manualmente
  Future<void> endNavigation() async {
    _isNavigating = false;
    _updateTimer?.cancel();

    // Guardar posição atual antes de sair
    final finalX = _tracker.currentX;
    final finalY = _tracker.currentY;
    final finalNode = _findNearestNode(finalX, finalY);

    await UserPositionService.savePosition(
      x: finalX,
      y: finalY,
      nodeId: finalNode.id,
      level: _currentLevel,
    );
    print(
      '[NavigationController] 💾 Posição guardada ao terminar: x=$finalX, y=$finalY, node=${finalNode.id}',
    );

    notifyListeners();
  }

  /// Simula um evento de reroute (para testes e demonstrações)
  void simulateRerouteEvent() {
    if (_isDisposed) return;
    print('[NavigationController] 🚦 Simulating Reroute Event...');
    _rerouteStream.add(
      RerouteEvent(
        arrivalTime: "20:00",
        duration: "0:05",
        distance: 50,
        locationName: "WC 2",
        newDestinationId: "WC_2", // Exemplo
        reason: "Less queue",
      ),
    );
  }

  /// Utiliza IDs de nós para reconstruir rota completa
  void applyNewRoute(List<String> nodeIds) {
    if (nodeIds.isEmpty) return;

    print(
      '[NavigationController] 🛣️ Applying new route with ${nodeIds.length} nodes',
    );

    // Mapear IDs para NodeModels
    final nodesMap = {for (var n in allNodes) n.id: n};
    final newPath = <PathNode>[];
    double cumulativeDist = 0;
    double cumulativeTime = 0;

    for (int i = 0; i < nodeIds.length; i++) {
      final id = nodeIds[i];
      final node = nodesMap[id];
      if (node == null) continue;

      if (i > 0) {
        final prevNode = nodesMap[nodeIds[i - 1]];
        if (prevNode != null) {
          final dist = math.sqrt(
            math.pow(node.x - prevNode.x, 2) + math.pow(node.y - prevNode.y, 2),
          );
          cumulativeDist += dist;
          cumulativeTime += dist / 1.4; // 1.4 m/s walking speed
        }
      }

      newPath.add(
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

    // Criar novo RouteModel
    final newRouteModel = RouteModel(
      path: newPath,
      totalDistance: cumulativeDist,
      estimatedTime: cumulativeTime,
      congestionLevel: 0, // Desconhecido nesta fase
      warnings: [],
    );

    // Atualizar rota no manager e tracker
    route = newRouteModel;
    _routeManager.updateRoute(newRouteModel);

    // Resetar tracker mas manter posição atual logicamente
    final currentX = _tracker.currentX;
    final currentY = _tracker.currentY;
    _tracker = RouteTracker(route: newRouteModel, allNodes: allNodes);
    _tracker.updateUserPosition(currentX, currentY);
    _updateInstruction();

    // Reiniciar navegação automática
    _autoNavTimer?.cancel();
    _isNavigating = true;
    _targetWaypointIndex = 0;
    _startAutoNavigation();
    
    print('[NavigationController] ✅ New route applied, auto-navigation restarted');

    notifyListeners();
  }

  /// Processa eventos recebidos via MQTT
  void _onMqttEvent(Map<String, dynamic> event) {
    if (_isDisposed) {
      // Controller disposed, ignore any incoming MQTT events
      print('[NavigationController] ⚠️ Ignoring MQTT event after dispose');
      return;
    }

    final eventType = event['type'] as String?;

    // Handle evacuation routes (emergency)
    if (eventType == 'evacuation') {
      print('[NavigationController] 🚨 EVACUATION route received!');
      try {
        final routeIds = List<String>.from(event['route'] ?? []);
        if (routeIds.isNotEmpty) {
          print('[NavigationController] 🚨 Applying evacuation route with  24{routeIds.length} nodes');
          print('[NavigationController] 🚨 Keeping user at current position: ( 24{_tracker.currentX},  24{_tracker.currentY})');

          // STOP existing auto-navigation completely
          _autoNavTimer?.cancel();
          _autoNavTimer = null;
          _isNavigating = false;  // This stops the timer callback from moving user

          // applyNewRoute preserves current position (X, Y coordinates)
          applyNewRoute(routeIds);

          // DO NOT restart auto-navigation - user keeps current position
          // The route is now displayed and user can follow it manually
        }
      } catch (e) {
        print('[NavigationController] ❌ Error applying evacuation route: $e');
      }
      return;
    }

    // Handle reroute suggestions
    if (eventType == 'reroute_suggestion') {
      print('[NavigationController] 📩 MQTT Reroute Suggestion received: $event');
      try {
        // Parse payload (flat structure from backend)
        final improvement = event['improvement'] as Map<String, dynamic>?;
        final newRoute = List<String>.from(event['new_route'] ?? []);

        final rerouteEvent = RerouteEvent(
          arrivalTime: improvement?['time_saved_display'] ?? 'Unknown',
          duration: improvement?['time_saved_display'] ?? 'Unknown',
          distance: 0, // Não vem no payload, não critico
          locationName: event['new_destination'] ?? "Better Route Found",
          newDestinationId: event['new_destination'] ?? '', // O novo POI de destino
          category: event['category'] as String?, // POI category for nearest_category lookup
          reason: event['reason'] ?? 'Better route found',
          newRouteIds: newRoute,
        );
        if (!_isDisposed) {
          _rerouteStream.add(rerouteEvent);
        } else {
          print('[NavigationController] ⚠️ Tried to add reroute event after dispose');
        }
      } catch (e) {
        print('[NavigationController] ❌ Error parsing reroute event: $e');
      }
    }
  }

  @override
  void dispose() {
    print('[NavigationController] 🧹 Disposing controller...');
    _isDisposed = true;
    if (_mqttSubscription != null) {
      print('[NavigationController] 🧹 Cancelling MQTT subscription');
      _mqttSubscription?.cancel();
      _mqttSubscription = null;
    }
    _updateTimer?.cancel();
    _autoNavTimer?.cancel();
    _positionSaveTimer?.cancel();
    _positionStream.close();
    _rerouteStream.close();
    _routeManager.dispose();
    print('[NavigationController] 🧹 Dispose complete');
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
      final dx = node.x - x;
      final dy = node.y - y;
      final distance = (dx * dx + dy * dy);

      if (distance < minDistance) {
        minDistance = distance;
        nearest = node;
      }
    }

    return nearest ?? allNodes.first;
  }
}
