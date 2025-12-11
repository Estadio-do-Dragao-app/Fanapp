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

/// Página de navegação em modo emergência (vermelho com borda piscante)
class EmergencyNavigationPage extends StatefulWidget {
  final RouteModel route;
  final POIModel destination;
  final List<NodeModel> nodes;

  const EmergencyNavigationPage({
    Key? key,
    required this.route,
    required this.destination,
    required this.nodes,
  }) : super(key: key);

  @override
  State<EmergencyNavigationPage> createState() =>
      _EmergencyNavigationPageState();
}

class _EmergencyNavigationPageState extends State<EmergencyNavigationPage>
    with SingleTickerProviderStateMixin {
  late NavigationController _controller;
  late AnimationController _blinkController;
  final MapController _mapController = MapController();

  // Conversão de unidades do backend para LatLng (MESMA lógica do StadiumMapPage!)
  static const double _backendCenterX = 499.0;
  static const double _backendCenterY = 400.0;
  static const double _unitsToLatDegrees = 0.000004;
  static const double _unitsToLngDegrees = 0.000005;
  static const LatLng _mapOrigin = LatLng(
    41.161758,
    -8.583933,
  ); // Centro do estádio

  @override
  void initState() {
    super.initState();

    _controller = NavigationController(
      route: widget.route,
      destination: widget.destination,
      allNodes: widget.nodes,
    );
    _controller.addListener(_onNavigationUpdate);

    // Animação de piscar para a borda vermelha
    _blinkController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.removeListener(_onNavigationUpdate);
    _controller.dispose();
    _blinkController.dispose();
    super.dispose();
  }

  void _onNavigationUpdate() {
    if (!mounted) return;
    setState(() {});

    // Câmara segue o utilizador (tipo Google Maps)
    _followUserPosition();

    // Chegada: voltar ao mapa automaticamente (com delay para evitar crash)
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
    // Centrar as coordenadas antes de converter
    final centeredX = tracker.currentX - _backendCenterX;
    final centeredY = tracker.currentY - _backendCenterY;

    final userLat = _mapOrigin.latitude + (centeredY * _unitsToLatDegrees);
    final userLng = _mapOrigin.longitude + (centeredX * _unitsToLngDegrees);

    // Move câmara suavemente para a posição do utilizador
    _mapController.move(LatLng(userLat, userLng), 19.0);
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
    final radius = MediaQuery.of(context).viewPadding.top > 0 ? 70.0 : 0.0;
    final tracker = _controller.tracker;
    // Centrar as coordenadas antes de converter
    final centeredX = tracker.currentX - _backendCenterX;
    final centeredY = tracker.currentY - _backendCenterY;
    final userLat = _mapOrigin.latitude + (centeredY * _unitsToLatDegrees);
    final userLng = _mapOrigin.longitude + (centeredX * _unitsToLngDegrees);
    final userPosition = LatLng(userLat, userLng);

    return Scaffold(
      body: Stack(
        children: [
          // Mapa de fundo com rota destacada (vermelha)
          Positioned.fill(
            child: StadiumMapPage(
              highlightedRoute: _controller.route, // Usar rota atual
              highlightedPOI: widget.destination,
              mapController: _mapController,
              isNavigating: true,
              userPosition: userPosition,
            ),
          ),

          // Borda vermelha ANIMADA (pisca)
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
                    borderRadius: BorderRadius.circular(radius),
                    border: Border.all(
                      color: const Color(
                        0xFFBD453D,
                      ).withOpacity(_blinkController.value),
                      width: 35,
                    ),
                  ),
                );
              },
            ),
          ),

          // Conteúdo respeitando SafeArea
          SafeArea(
            child: Stack(
              children: [
                // Header com instrução de navegação
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: NavigationHeader(
                    instruction: _controller.currentInstruction,
                    isEmergency: true,
                  ),
                ),

                // Bottom sheet com informações
                NavigationBottomSheet(
                  arrivalTime: _getArrivalTime(),
                  remainingTime: _controller.formattedRemainingTime,
                  remainingDistance: _controller.formattedRemainingDistance,
                  destination: widget.destination,
                  onEndRoute: _endNavigation,
                  isEmergency: true,
                ),

                // Controlos manuais para emulador (DEBUG) - 4 direções
                Positioned(
                  right: 16,
                  bottom: 350,
                  child: Column(
                    children: [
                      // Cima
                      FloatingActionButton(
                        heroTag: 'up_emergency',
                        mini: true,
                        backgroundColor: const Color(0xFFBD453D),
                        onPressed: () => _controller.moveUser(0, 5),
                        child: const Icon(
                          Icons.arrow_upward,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          // Esquerda
                          FloatingActionButton(
                            heroTag: 'left_emergency',
                            mini: true,
                            backgroundColor: const Color(0xFFBD453D),
                            onPressed: () => _controller.moveUser(-5, 0),
                            child: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Direita
                          FloatingActionButton(
                            heroTag: 'right_emergency',
                            mini: true,
                            backgroundColor: const Color(0xFFBD453D),
                            onPressed: () => _controller.moveUser(5, 0),
                            child: const Icon(
                              Icons.arrow_forward,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Baixo
                      FloatingActionButton(
                        heroTag: 'down_emergency',
                        mini: true,
                        backgroundColor: const Color(0xFFBD453D),
                        onPressed: () => _controller.moveUser(0, -5),
                        child: const Icon(
                          Icons.arrow_downward,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
