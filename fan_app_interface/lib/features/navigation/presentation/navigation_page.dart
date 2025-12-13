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

  const NavigationPage({
    Key? key,
    required this.route,
    required this.destination,
    required this.nodes,
    this.initialX,
    this.initialY,
  }) : super(key: key);

  @override
  State<NavigationPage> createState() => _NavigationPageState();
}

class _NavigationPageState extends State<NavigationPage> {
  late NavigationController _controller;
  final MapController _mapController = MapController();

  // Escala para corresponder ao StadiumMapPage

  @override
  void initState() {
    super.initState();
    _controller = NavigationController(
      route: widget.route,
      destination: widget.destination,
      allNodes: widget.nodes,
      initialX: widget.initialX,
      initialY: widget.initialY,
    );
    _controller.addListener(_onNavigationUpdate);
  }

  @override
  void dispose() {
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
          Navigator.of(context).pop();
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

    // Move e roda câmara como no Google Maps
    // O mapa roda para que a direção de viagem esteja sempre para CIMA
    try {
      _mapController.moveAndRotate(
        LatLng(userLat, userLng),
        20.0, // Zoom
        -_controller
            .heading, // Rotação negativa para que o heading fique para cima
      );
    } catch (e) {
      // Mapa ainda não renderizado, ignorar
    }
  }

  void _endNavigation() {
    _controller.endNavigation();
    Navigator.of(context).pop();
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
            highlightedRoute: _controller
                .route, // Usar rota atual (pode ter sido recalculada)
            highlightedPOI: widget.destination,
            mapController: _mapController,
            isNavigating: true,
            userPosition: userPosition,
            userHeading: _controller.heading,
            routeStartWaypointIndex: _controller.tracker.currentWaypointIndex,
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

          // Botão de centrar (apenas na NavigationPage)
          Positioned(
            left: 16,
            bottom: 200,
            child: FloatingActionButton(
              heroTag: 'center',
              backgroundColor: Colors.white,
              onPressed: _followUserPosition,
              child: const Icon(Icons.my_location, color: Colors.blue),
            ),
          ),
        ],
      ),
    );
  }
}
