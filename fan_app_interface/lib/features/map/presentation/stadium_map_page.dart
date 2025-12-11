import 'package:fan_app_interface/features/map/presentation/controllers/map_logic_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math';

import '../data/models/poi_model.dart';
import '../data/models/node_model.dart';
import '../data/models/route_model.dart';
import '../data/services/map_service.dart';
import '../data/services/routing_service.dart';
import '../../navigation/data/services/user_position_service.dart';
import '../../poi/presentation/poi_details_sheet.dart';

/// Página principal do mapa interativo do estádio
class StadiumMapPage extends StatefulWidget {
  final RouteModel? highlightedRoute;
  final POIModel? highlightedPOI;
  final bool showAllPOIs;
  final MapController? mapController;
  final bool isNavigating;
  final LatLng? userPosition; // Posição externa opcional (para navigation page)
  final double? userHeading; // Heading externo opcional

  const StadiumMapPage({
    Key? key,
    this.highlightedRoute,
    this.highlightedPOI,
    this.showAllPOIs = true,
    this.mapController,
    this.isNavigating = false,
    this.userPosition,
    this.userHeading,
  }) : super(key: key);

  @override
  State<StadiumMapPage> createState() => StadiumMapPageState();
}

class StadiumMapPageState extends State<StadiumMapPage> {
  late final MapLogicController _logicController;
  // Fallback controller se não for fornecido
  late final MapController _internalMapController;
  
  final MapService _mapService = MapService();
  final RoutingService _routingService = RoutingService();
  
  // Estado
  int _currentFloor = 0;
  List<POIModel> _pois = [];
  List<NodeModel> _nodes = [];
  RouteModel? _currentRoute;
  bool _isLoading = true;
  String? _errorMessage;
  
  // Scale factor removed: Using directly 1:1 mapping for CrsSimple
  static const double coordScale = 1.0;

  // Limites do mapa baseados nos dados reais (coordenadas 0-100)
  // Usando 0-200 para dar margem
  static final LatLngBounds mapBounds = LatLngBounds(
    const LatLng(0, 0), // Min: y=0, x=0
    const LatLng(200, 200), // Max: y=200, x=200
  );

  @override
  void initState() {
    super.initState();
    // Usa controller fornecido ou cria um interno
    _internalMapController = widget.mapController ?? MapController();
    _logicController = MapLogicController(mapController: _internalMapController);

    // Inicializar rota
    _currentRoute = widget.highlightedRoute;
    
    _loadUserPosition();
    _loadMapData();
  }

  // Novo método chamado quando o mapa está pronto
  void _onMapReady() {
    if (widget.isNavigating) {
      _logicController.startNavigation();
    }
    
    // Se tivermos posição inicial (diferente de default), centramos nela
    if (_logicController.userX != 0 || _logicController.userY != 0) {
      _logicController.centerOnUser();
    }
  }

  @override
  void didUpdateWidget(StadiumMapPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.highlightedRoute != oldWidget.highlightedRoute) {
      setState(() {
        _currentRoute = widget.highlightedRoute;
      });
    }
    
    if (widget.isNavigating != oldWidget.isNavigating) {
      if (widget.isNavigating) {
        _logicController.startNavigation();
      } else {
        _logicController.stopNavigation();
      }
    }
    
    // Atualização de posição externa
    if (widget.userPosition != null && widget.userPosition != oldWidget.userPosition) {
       _logicController.setUserPosition(
        widget.userPosition!.longitude, // X
        widget.userPosition!.latitude,  // Y
      );
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
  
  /// Carrega posição salva do utilizador
  Future<void> _loadUserPosition() async {
    final position = await UserPositionService.getPosition();
    if (mounted) {
      // Usar a posição guardada diretamente (assumindo que já está no sistema correto ou será 0,0)
      _logicController.setUserPosition(
        position.x,
        position.y,
        nodeId: position.nodeId,
      );
    }
  }
  
  Future<void> _loadMapData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final pois = await _mapService.getPOIsByFloor(_currentFloor);
      final nodes = await _mapService.getAllNodes();
      
      if (mounted) {
        setState(() {
          _pois = pois;
          _nodes = nodes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  // Helper para converter x,y cartesianos para LatLng (Direct Mapping)
  LatLng _toLatLng(double x, double y) {
    // Y maps to Latitude, X maps to Longitude (1:1 for CrsSimple)
    return LatLng(y, x);
  }

  /// Encontra o nó mais próximo de um POI
  String _findNearestNode(POIModel poi) {
    if (_nodes.isEmpty) return _logicController.userNodeId;
    
    NodeModel? nearest;
    double minDistance = double.infinity;
    
    for (var node in _nodes) {
      if (node.level != poi.level) continue;
      
      final dx = node.x - poi.x;
      final dy = node.y - poi.y;
      final distance = sqrt(dx * dx + dy * dy);
      
      if (distance < minDistance) {
        minDistance = distance;
        nearest = node;
      }
    }
    
    return nearest?.id ?? _logicController.userNodeId;
  }
  
  void zoomToPOI(POIModel poi) {
    _logicController.mapController.move(_toLatLng(poi.x, poi.y), 19.5);
  }
  
  void _showPOIDetails(POIModel poi) async {
    final previousZoom = _logicController.mapController.camera.zoom;
    
    // Move camera safely
    _logicController.mapController.move(_toLatLng(poi.x, poi.y), 19.5);
    
    RouteModel? route;
    try {
      final nearestNode = _findNearestNode(poi);
      route = await _routingService.getRoute(
        fromNode: _logicController.userNodeId,
        toNode: nearestNode,
      );
      
      setState(() {
        _currentRoute = route;
      });
    } catch (e) {
      print('[StadiumMapPage] Erro ao calcular rota: $e');
    }
    
    if (!mounted) return;
    
    POIDetailsSheet.show(
      context,
      poi: poi,
      route: route,
      allNodes: _nodes,
    ).whenComplete(() {
      if (!widget.isNavigating) {
        setState(() {
          _currentRoute = null;
        });
      }
      
      if (mounted) {
        final currentCenter = _logicController.mapController.camera.center;
        _logicController.mapController.move(currentCenter, previousZoom);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _logicController,
      builder: (context, _) {
        return Stack(
          children: [
            if (_errorMessage != null)
              _buildErrorState()
            else if (_isLoading)
              _buildLoadingState()
            else
              _buildMap(),
            
            // Botão de foco no utilizador (apenas durante navegação)
            if (widget.isNavigating)
              Positioned(
                left: 16,
                bottom: 350,
                child: FloatingActionButton(
                  mini: true,
                  backgroundColor: _logicController.isFollowingUser ? Colors.blue : Colors.white,
                  onPressed: _logicController.toggleFollowUser,
                  child: Icon(
                    Icons.my_location,
                    color: _logicController.isFollowingUser ? Colors.white : const Color(0xFF5B6FE8),
                  ),
                ),
              ),
          ],
        );
      }
    );
  }
  
  Widget _buildMap() {
    return FlutterMap(
      mapController: _logicController.mapController,
      options: MapOptions(
        crs: const CrsSimple(), // CRS Cartesiano Simples
        initialCenter: _toLatLng(50, 20), // Centro aproximado dos dados
        // Zoom levels for 200-unit map (0-200):
        // At zoom 1, scale = 2, so 200 units = 400 pixels (fits on screen)
        // At zoom 2, scale = 4, so 200 units = 800 pixels (zoomed in)
        initialZoom: 1.0, // Shows a good portion of the map
        minZoom: -1.0, // Can zoom out a bit
        maxZoom: 4.0, // Can zoom in for detail
        onMapReady: _onMapReady,
        onTap: (_, pos) {
             print("Map Tapped at: x=${pos.longitude}, y=${pos.latitude}");
        },
      ),
      children: [
        // Camada de fundo (Imagem / Gráfico) - ONDEM Z=0
        OverlayImageLayer(
          overlayImages: [
            OverlayImage(
              bounds: mapBounds, 
              opacity: 1.0,
              imageProvider: const AssetImage('assets/images/map_placeholder.png'),
            ),
          ],
        ),
        
        // Polylines (Rotas) - ORDEM Z=1
        if (_currentRoute != null) _buildRouteLayer(),
        
        // Markers (POIs + User) - ORDEM Z=2 (Topo)
        _buildPOILayer(),
      ],
    );
  }

  Widget _buildRouteLayer() {
    final route = _currentRoute!;
    final points = route.waypoints
        .where((wp) => wp.level == _currentFloor)
        .map((wp) => _toLatLng(wp.x, wp.y))
        .toList();
    
    return PolylineLayer(
      polylines: [
        Polyline(
          points: points,
          color: const Color(0xFF5B6FE8),
          strokeWidth: 5.0,
          borderColor: Colors.white,
          borderStrokeWidth: 2.5,
        ),
      ],
    );
  }
  
  Widget _buildPOILayer() {
    List<POIModel> poisToShow;
    
    // Lógica de filtragem de POIs
    if (widget.isNavigating) {
      poisToShow = widget.highlightedPOI != null ? [widget.highlightedPOI!] : [];
    } else if (widget.showAllPOIs) {
      poisToShow = _pois;
    } else if (widget.highlightedPOI != null) {
      poisToShow = [widget.highlightedPOI!];
    } else {
      poisToShow = [];
    }
    
    final markers = <Marker>[];
    
    // 1. Marcadores de POIs (Desenhados primeiro)
    for (var poi in poisToShow) {
      final isHighlighted = widget.highlightedPOI?.id == poi.id;
      markers.add(
        Marker(
          point: _toLatLng(poi.x, poi.y),
          width: isHighlighted ? 60 : 50,
          height: isHighlighted ? 60 : 50,
          child: GestureDetector(
            onTap: () => _showPOIDetails(poi),
            child: Container(
              padding: EdgeInsets.all(isHighlighted ? 10 : 8),
              decoration: BoxDecoration(
                color: _getPOIColor(poi.category),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isHighlighted ? Colors.yellow : Colors.white,
                  width: isHighlighted ? 3 : 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: isHighlighted ? 8 : 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                _getPOIIcon(poi.category),
                color: Colors.white,
                size: isHighlighted ? 24 : 20,
              ),
            ),
          ),
        ),
      );
    }
    
    // 2. Marcador do Utilizador (Desenhado por último para ficar em Z mais alto)
    // Se tivermos um heading externo (NavigationPage), usamos para rodar o ícone
    // Se não tiver heading, usa 0
    // O sistema de heading usa 0=Norte/Cima. O ícone arrow_upward aponta para cima.
    // Logo, a rotação é direta.
    final rotationRad = (widget.userHeading ?? 0) * (3.14159 / 180);
    
    // Só desenha se a posição não for nula/zero ou se estivermos explicitamente com tracking
    double userX = _logicController.userX;
    double userY = _logicController.userY;
    
    if (userX != 0 || userY != 0) {
      markers.add(
        Marker(
          point: _toLatLng(userX, userY),
          width: 60,
          height: 60,
          child: Transform.rotate(
            angle: rotationRad,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.black26, blurRadius: 4),
                ],
                border: Border.all(color: Colors.blue, width: 2),
              ),
              child: const Icon(
                Icons.arrow_upward, // Seta que aponta para CIMA (Norte) por defeito
                color: Colors.blue,
                size: 35,
              ),
            ),
          ),
        ),
      );
    }

    return MarkerLayer(markers: markers);
  }

  Widget _buildLoadingState() {
    return const Center(child: CircularProgressIndicator());
  }
  
  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Error',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadMapData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
  
  Color _getPOIColor(String category) {
    switch (category.toLowerCase()) {
      case 'restroom': return Colors.blue.shade700;
      case 'food':
      case 'bar': return Colors.orange.shade700;
      case 'emergency_exit': return Colors.red.shade700;
      case 'first_aid': return Colors.green.shade700;
      case 'information': return Colors.purple.shade700;
      default: return Colors.grey.shade700;
    }
  }
  
  IconData _getPOIIcon(String category) {
    switch (category.toLowerCase()) {
      case 'restroom': return Icons.wc;
      case 'food': return Icons.restaurant;
      case 'bar': return Icons.local_bar;
      case 'emergency_exit': return Icons.exit_to_app;
      case 'first_aid': return Icons.local_hospital;
      case 'information': return Icons.info;
      default: return Icons.place;
    }
  }
}
