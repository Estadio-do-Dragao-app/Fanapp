import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../map/data/models/route_model.dart';
import '../../map/data/models/node_model.dart';
import '../../map/data/models/poi_model.dart';
import '../data/models/navigation_instruction.dart';
import '../data/services/user_position_service.dart';
import 'route_tracker.dart';
import 'dynamic_route_manager.dart';

/// Controlador principal da navegação
/// Gerencia o estado da navegação, tracking de posição e instruções
class NavigationController extends ChangeNotifier {
  final RouteModel initialRoute;
  final POIModel destination;
  final List<NodeModel> allNodes;
  
  late RouteModel route;
  late RouteTracker _tracker;
  late DynamicRouteManager _routeManager;
  Timer? _updateTimer;
  
  // Stream para monitorizar posição
  final StreamController<({double x, double y})> _positionStream = StreamController.broadcast();
  
  bool _isNavigating = true;
  NavigationInstruction? _currentInstruction;

  // Heading em graus (0 = Este/Direita, 90 = Sul/Baixo)
  double _heading = 0.0;

  NavigationController({
    required RouteModel route,
    required this.destination,
    required this.allNodes,
  }) : initialRoute = route {
    this.route = route;
    _tracker = RouteTracker(route: route, allNodes: allNodes);
    
    // Encontrar nó de destino mais próximo do POI
    final destNode = _findNearestNode(destination.x, destination.y);
    
    // Inicializar gestor de rota dinâmica
    _routeManager = DynamicRouteManager(
      destinationNodeId: destNode.id,
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

  /// Inicializa o tracking e instruções
  void _initialize() {
    // Posição inicial do utilizador (primeiro waypoint)
    if (route.waypoints.isNotEmpty) {
      final firstWaypoint = route.waypoints.first;
      _tracker.updateUserPosition(firstWaypoint.x, firstWaypoint.y);
      _updateInstruction();
    }
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
    );
    print('[NavigationController] 💾 Posição final guardada: x=$finalX, y=$finalY, node=${finalNode.id}');
    
    notifyListeners();
  }

  /// Termina a navegação manualmente
  void endNavigation() {
    _isNavigating = false;
    _updateTimer?.cancel();
    notifyListeners();
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _positionStream.close();
    _routeManager.dispose();
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
