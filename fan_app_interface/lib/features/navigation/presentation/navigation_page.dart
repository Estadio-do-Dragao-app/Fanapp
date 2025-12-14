import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../map/data/models/route_model.dart';
import '../../map/data/models/node_model.dart';
import '../../map/data/models/poi_model.dart';
import '../../map/presentation/stadium_map_page.dart';
import '../domain/navigation_controller.dart';
import 'widgets/navigation_header.dart';
import 'widgets/navigation_bottom_sheet.dart';

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
  });

  @override
  State<NavigationPage> createState() => _NavigationPageState();
}

class _NavigationPageState extends State<NavigationPage>
    with TickerProviderStateMixin {
  late NavigationController _controller;
  final MapController _mapController = MapController();

  // Controlador de animação para movimento suave do mapa
  late AnimationController _animationController;
  Animation<double>? _latAnimation;
  Animation<double>? _lngAnimation;
  Animation<double>? _rotAnimation;

  // Escala para corresponder ao StadiumMapPage
  bool _showHeatmap = false; // Estado local para toggle do heatmap

  @override
  void initState() {
    super.initState();
    // Duração curta para corresponder à frequência de updates (100ms) mas suavizar snaps
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

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
  }

  @override
  void dispose() {
    _animationController.dispose();
    _controller.removeListener(_onNavigationUpdate);
    _controller.dispose();
    super.dispose();
  }

  void _onNavigationUpdate() {
    if (!mounted) return;
    setState(() {});

    // Câmara segue o utilizador (tipo Google Maps)
    _followUserPosition();

    // Chegada ao destino: voltar ao mapa automaticamente (com delay para evitar crash)
    if (_controller.hasArrived) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          // Voltar à Home (root) independentemente de onde veio
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      });
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
      Navigator.of(context).popUntil((route) => route.isFirst);
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
          ),

          // Header com instrução de navegação (topo)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: NavigationHeader(
              instruction: _controller.currentInstruction,
              isEmergency: false,
            ),
          ),

          // Bottom sheet com informações
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
              isEmergency: false,
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
