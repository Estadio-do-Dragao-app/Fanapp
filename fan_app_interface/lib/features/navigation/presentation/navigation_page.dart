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

  const NavigationPage({
    Key? key,
    required this.route,
    required this.destination,
    required this.nodes,
  }) : super(key: key);

  @override
  State<NavigationPage> createState() => _NavigationPageState();
}

class _NavigationPageState extends State<NavigationPage> {
  late NavigationController _controller;
  final MapController _mapController = MapController();

  // Escala para corresponder ao StadiumMapPage
  static const double _coordScale = 0.001;

  @override
  void initState() {
    super.initState();
    _controller = NavigationController(
      route: widget.route,
      destination: widget.destination,
      allNodes: widget.nodes,
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
    // Conversão direta Cartesian -> Visual LatLng
    final userLat = tracker.currentY * _coordScale;
    final userLng = tracker.currentX * _coordScale;
    
    // Move câmara suavemente para a posição do utilizador
    _mapController.move(LatLng(userLat, userLng), 19.0);
  }

  void _endNavigation() {
    _controller.endNavigation();
    Navigator.of(context).pop();
  }

  String _getArrivalTime() {
    final now = DateTime.now();
    final arrivalTime = now.add(Duration(seconds: _controller.remainingTimeSeconds));
    return '${arrivalTime.hour}:${arrivalTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final tracker = _controller.tracker;
    // Wrapper "Legacy" para passar X,Y brutos para o StadiumMapPage
    // StadiumMapPage espera (Latitude=Y, Longitude=X)
    final userPosition = LatLng(tracker.currentY, tracker.currentX);
    
    return Scaffold(
      body: Stack(
        children: [
          // Mapa de fundo com rota destacada
          StadiumMapPage(
            highlightedRoute: widget.route,
            highlightedPOI: widget.destination,
            mapController: _mapController,
            isNavigating: true,
            userPosition: userPosition,
            userHeading: _controller.heading,
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

          // Controlos manuais (Tank Controls)
          Positioned(
            right: 16,
            bottom: 350,
            child: Column(
              children: [
                // Frente
                FloatingActionButton(
                  heroTag: 'forward',
                  mini: false, // Maior destaque
                  backgroundColor: const Color(0xFF5B6FE8),
                  onPressed: () => _controller.moveForward(5), // +5m na direção atual
                  child: const Icon(Icons.arrow_upward, color: Colors.white),
                ),
                const SizedBox(height: 16),
                // Rodar
                FloatingActionButton(
                  heroTag: 'rotate',
                  mini: false,
                  backgroundColor: Colors.white,
                  onPressed: () => _controller.rotateUser(45), // +45 graus
                  child: const Icon(Icons.rotate_right, color: Color(0xFF5B6FE8)),
                ),
              ],
            ),
          ),
          
        ],
      ),
    );
  }
}
