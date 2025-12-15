import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../map/data/models/route_model.dart';
import '../../map/data/models/node_model.dart';
import '../../map/data/models/poi_model.dart';
import '../../map/data/services/routing_service.dart';
import '../../map/presentation/stadium_map_page.dart';
import '../domain/navigation_controller.dart';
import '../domain/models/reroute_event.dart';
import 'widgets/navigation_header.dart';
import 'widgets/navigation_bottom_sheet.dart';
import 'widgets/reroute_popup.dart';
import '../../../Home.dart';

/// Página principal de navegação (modo normal - azul)
class NavigationPage extends StatefulWidget {
  final RouteModel route;
  final POIModel destination;
  final List<NodeModel> nodes;
  final double? initialX;
  final double? initialY;
  final int? initialLevel;

  const NavigationPage({
    super.key,
    required this.route,
    required this.destination,
    required this.nodes,
    this.initialX,
    this.initialY,
    this.initialLevel,
    this.isEmergency = false,
  });

  final bool isEmergency;

  @override
  State<NavigationPage> createState() => _NavigationPageState();
}

class _NavigationPageState extends State<NavigationPage>
    with TickerProviderStateMixin {
  late NavigationController _controller;
  final MapController _mapController = MapController();
  final RoutingService _routingService = RoutingService();

  // Controlador de animação para movimento suave do mapa
  late AnimationController _animationController;
  Animation<double>? _latAnimation;
  Animation<double>? _lngAnimation;
  Animation<double>? _rotAnimation;

  // Animation controller for blinking border (emergency mode)
  late AnimationController _blinkController;

  // Escala para corresponder ao StadiumMapPage
  bool _showHeatmap = false; // Estado local para toggle do heatmap

  // State for reroute popup
  bool _showReroutePopup = false;
  RerouteEvent? _rerouteEvent;

  @override
  void initState() {
    super.initState();
    // ... rest of initState

    // Duração curta para corresponder à frequência de updates (100ms) mas suavizar snaps
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // Initialize blinking controller
    _blinkController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    if (widget.isEmergency) {
      _blinkController.repeat(reverse: true);
    }

    _controller = NavigationController(
      route: widget.route,
      destination: widget.destination,
      allNodes: widget.nodes,
      initialX: widget.initialX,
      initialY: widget.initialY,
      initialLevel: widget.initialLevel,
    );
    _controller.addListener(_onNavigationUpdate);

    // Configurar listener da animação
    _animationController.addListener(() {
      if (_latAnimation != null &&
          _lngAnimation != null &&
          _rotAnimation != null) {
        _mapController.moveAndRotate(
          LatLng(_latAnimation!.value, _lngAnimation!.value),
          20.0, // Zoom constante ou animado se necessário
          _rotAnimation!.value,
        );
      }
    });

    // Escutar eventos de reroute
    _controller.rerouteStream.listen((event) {
      if (!mounted) return;
      print("[NavigationPage] 🔔 Reroute event received!");
      setState(() {
        _rerouteEvent = event;
        _showReroutePopup = true;
      });
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _blinkController.dispose();
    _controller.removeListener(_onNavigationUpdate);
    _controller.dispose();
    super.dispose();
  }

  void _onNavigationUpdate() {
    if (!mounted) return;
    print('[NavigationPage] 🔄 Update: index=${_controller.tracker.currentWaypointIndex}');
    setState(() {});

    // Câmara segue o utilizador (tipo Google Maps)
    _followUserPosition();

    // Chegada ao destino: voltar ao mapa automaticamente (com delay para evitar crash)
    if (_controller.hasArrived) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _exitNavigation();
        }
      });
    }
  }

  void _exitNavigation() {
    if (widget.isEmergency) {
      // Modo de emergência: Home foi removida da stack, temos de navegar para lá explicitamente
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const Home()),
        (route) => false,
      );
    } else {
      // Modo normal: Voltar à Home (root) independentemente de onde veio
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  void _followUserPosition() {
    final tracker = _controller.tracker;
    // Usar mesma lógica de projeção corrigida do StadiumMapPage
    // Centro das coordenadas do backend
    const backendCenterX = 499.0;
    const backendCenterY = 400.0;
    const unitsToLatDegrees = 0.000004;
    const unitsToLngDegrees = 0.000005;

    final center = StadiumMapPageState.stadiumCenter;

    // Centrar as coordenadas antes de converter
    final centeredX = tracker.currentX - backendCenterX;
    final centeredY = tracker.currentY - backendCenterY;

    final userLat = center.latitude + (centeredY * unitsToLatDegrees);
    final userLng = center.longitude + (centeredX * unitsToLngDegrees);

    // Mover e rodar câmara com animação
    try {
      final targetRot = _controller.heading - 180.0;
      _animateMapTo(LatLng(userLat, userLng), targetRot);
    } catch (e) {
      // Mapa ainda não renderizado, ignorar
    }
  }

  void _animateMapTo(LatLng destLocation, double destRotation) {
    if (!mounted) return;

    // Obter valores atuais
    final startLat = _mapController.camera.center.latitude;
    final startLng = _mapController.camera.center.longitude;
    final startRot = _mapController.camera.rotation;

    // Calcular rotação mais curta (evitar girar 360 graus desnecessariamente)
    double diff = (destRotation - startRot + 180) % 360 - 180;
    // Ajustar destRotation para ser vizinha de startRot
    final adjustedDestRot = startRot + diff;

    // Se a mudança for muito pequena, movemos instantaneamente (optimização)
    // Mas para suavidade total, animamos tudo.
    _latAnimation = Tween<double>(begin: startLat, end: destLocation.latitude)
        .animate(
          CurvedAnimation(parent: _animationController, curve: Curves.linear),
        );
    _lngAnimation = Tween<double>(begin: startLng, end: destLocation.longitude)
        .animate(
          CurvedAnimation(parent: _animationController, curve: Curves.linear),
        );
    _rotAnimation = Tween<double>(begin: startRot, end: adjustedDestRot)
        .animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );

    _animationController.reset();
    _animationController.forward();
  }

  Future<void> _endNavigation() async {
    await _controller.endNavigation();
    if (mounted) {
      _exitNavigation();
    }
  }

  String _getArrivalTime() {
    final now = DateTime.now();
    final arrivalTime = now.add(
      Duration(seconds: _controller.remainingTimeSeconds),
    );
    return '${arrivalTime.hour}:${arrivalTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final tracker = _controller.tracker;

    // Calcular posição para o mapa (usando mesma projeção corrigida)
    const backendCenterX = 499.0;
    const backendCenterY = 400.0;
    const unitsToLatDegrees = 0.000004;
    const unitsToLngDegrees = 0.000005;
    final center = StadiumMapPageState.stadiumCenter;

    // Centrar as coordenadas antes de converter
    final centeredX = tracker.currentX - backendCenterX;
    final centeredY = tracker.currentY - backendCenterY;

    final userPosition = LatLng(
      center.latitude + (centeredY * unitsToLatDegrees),
      center.longitude + (centeredX * unitsToLngDegrees),
    );

    return Scaffold(
      body: Stack(
        children: [
          // Mapa de fundo com rota destacada
          StadiumMapPage(
            highlightedRoute: _controller.route,
            highlightedPOI: widget.destination,
            mapController: _mapController,
            isNavigating: true,
            userPosition: userPosition,
            userHeading: _controller.heading,
            routeStartWaypointIndex: _controller.tracker.currentWaypointIndex,
            initialFloor: _controller.currentLevel,
            showHeatmap: _showHeatmap, // Passar estado do toggle
            isEmergency: widget.isEmergency,
          ),

          // Emergency Blinking Border
          if (widget.isEmergency)
            Positioned(
              top: -20,
              bottom: -20,
              left: -20,
              right: -20,
              child: AnimatedBuilder(
                animation: _blinkController,
                builder: (context, child) {
                  return Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        MediaQuery.of(context).viewPadding.top > 0 ? 70.0 : 0.0,
                      ),
                      border: Border.all(
                        color: const Color(
                          0xFFBD453D,
                        ).withValues(alpha: _blinkController.value),
                        width: 35,
                      ),
                    ),
                  );
                },
              ),
            ),

          // Header com instrução de navegação (topo)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: NavigationHeader(
              instruction: _controller.currentInstruction,
              isEmergency: widget.isEmergency,
            ),
          ),

          // Bottom sheet com informações (Hide when popup is visible)
          if (!_showReroutePopup)
            Positioned(
              left: 24,
              right: 24,
              bottom: 24,
              child: NavigationBottomSheet(
                arrivalTime: _getArrivalTime(),
                remainingTime: _controller.formattedRemainingTime,
                remainingDistance: _controller.formattedRemainingDistance,
                destination: widget.destination,
                onEndRoute: _endNavigation,
                isEmergency: widget.isEmergency,
              ),
            ),

          // Reroute Popup
          if (_showReroutePopup && _rerouteEvent != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ReroutePopup(
                arrivalTime: _rerouteEvent!.arrivalTime,
                duration: _rerouteEvent!.duration,
                distance: _rerouteEvent!.distance,
                locationName: _rerouteEvent!.locationName,
                onAccept: () async {
                  // Capture reroute event values BEFORE setState (which may trigger rebuild)
                  final capturedNewDestinationId = _rerouteEvent?.newDestinationId ?? widget.destination.id;
                  final capturedNewRouteIds = _rerouteEvent?.newRouteIds;
                  final capturedCategory = _rerouteEvent?.category; // POI category for nearest_category lookup
                  
                  setState(() {
                    _showReroutePopup = false;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Recalculating route from current position..."),
                    ),
                  );

                  // Request new route from current position to NEW destination
                  try {
                    // Pause auto-navigation to freeze user position while calculating
                    _controller.pauseAutoNavigation();
                    
                    final currentX = _controller.tracker.currentX;
                    final currentY = _controller.tracker.currentY;
                    final currentLevel = _controller.currentLevel;
                    
                    RouteModel newRoute;
                    
                    // If category is available, use nearest_category to find FASTEST POI
                    // (uses full pathfinding with congestion + wait + travel)
                    if (capturedCategory != null && capturedCategory.isNotEmpty) {
                      print('[NavigationPage] 🔄 Requesting nearest $capturedCategory from ($currentX, $currentY) level=$currentLevel');
                      newRoute = await _routingService.getRouteToNearestCategory(
                        startX: currentX,
                        startY: currentY,
                        startLevel: currentLevel,
                        category: capturedCategory,
                        avoidStairs: false,
                      );
                    } else {
                      // Fallback to specific POI if no category
                      print('[NavigationPage] 🔄 Requesting route to specific POI $capturedNewDestinationId');
                      newRoute = await _routingService.getRouteToPOI(
                        startX: currentX,
                        startY: currentY,
                        startLevel: currentLevel,
                        poiId: capturedNewDestinationId,
                        avoidStairs: false,
                      );
                    }
                    
                    if (newRoute.path.isNotEmpty) {
                      final nodeIds = newRoute.path.map((p) => p.nodeId).toList();
                      print('[NavigationPage] ✅ New route received with ${nodeIds.length} nodes');
                      _controller.applyNewRoute(nodeIds);
                      
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Route updated successfully!"),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    }
                  } catch (e) {
                    print('[NavigationPage] ❌ Failed to get new route: $e');
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Failed to recalculate route: $e"),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                onDecline: () {
                  setState(() {
                    _showReroutePopup = false;
                  });
                },
              ),
            ),

          // Botão de centrar e Toggle Heatmap
          Positioned(
            left: 16,
            bottom: 200,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  heroTag: 'heatmap_toggle',
                  backgroundColor: _showHeatmap ? Colors.orange : Colors.white,
                  onPressed: () {
                    setState(() {
                      _showHeatmap = !_showHeatmap;
                    });
                  },
                  child: Icon(
                    _showHeatmap ? Icons.layers_clear : Icons.layers,
                    color: _showHeatmap ? Colors.white : Colors.blue,
                  ),
                ),
                const SizedBox(height: 16),
                FloatingActionButton(
                  heroTag: 'center',
                  backgroundColor: Colors.white,
                  onPressed: _followUserPosition,
                  child: const Icon(Icons.my_location, color: Colors.blue),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
