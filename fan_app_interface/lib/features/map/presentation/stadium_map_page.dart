import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../data/models/poi_model.dart';
import '../data/models/node_model.dart';
import '../data/models/route_model.dart';
import '../data/services/map_service.dart';
import '../data/services/routing_service.dart';
import '../data/services/congestion_service.dart';
import '../../poi/presentation/poi_details_sheet.dart';
import 'dart:math';

/// Página principal do mapa interativo do estádio
class StadiumMapPage extends StatefulWidget {
  final RouteModel? highlightedRoute;
  final POIModel? highlightedPOI;
  final bool showAllPOIs;
  final bool showHeatmap;

  const StadiumMapPage({
    Key? key,
    this.highlightedRoute,
    this.highlightedPOI,
    this.showAllPOIs = true,
    this.showHeatmap = false,
  }) : super(key: key);

  @override
  State<StadiumMapPage> createState() => StadiumMapPageState();
}

class StadiumMapPageState extends State<StadiumMapPage> {
  final MapController _mapController = MapController();
  final MapService _mapService = MapService();
  final RoutingService _routingService = RoutingService();
  final CongestionService _congestionService = CongestionService();

  // Posição fixa do utilizador para testes (entrada principal)
  static const String userNodeId = 'N1';

  // Estado
  int _currentFloor = 0;
  List<POIModel> _pois = [];
  List<NodeModel> _nodes = [];
  RouteModel? _currentRoute;
  bool _isLoading = true;
  String? _errorMessage;

  // Heatmap data
  StadiumHeatmapData? _heatmapData;

  @override
  void didUpdateWidget(StadiumMapPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Atualizar rota quando parâmetros mudarem
    if (widget.highlightedRoute != oldWidget.highlightedRoute) {
      setState(() {
        _currentRoute = widget.highlightedRoute;
      });
    }
    // Carregar heatmap quando ativado
    if (widget.showHeatmap && !oldWidget.showHeatmap) {
      _loadHeatmapData();
    }
  }

  /// Carrega dados de congestão para o heatmap
  Future<void> _loadHeatmapData() async {
    try {
      final data = await _congestionService.getStadiumHeatmap();
      if (mounted) {
        setState(() {
          _heatmapData = data;
        });
      }
    } catch (e) {
      print('[StadiumMapPage] Erro ao carregar heatmap: $e');
      // Usar dados de demo para visualização
      if (mounted) {
        setState(() {
          _heatmapData = StadiumHeatmapData(
            sections: {
              'section_A': 0.85, // Alta congestão
              'section_B': 0.45, // Média
              'section_C': 0.15, // Baixa
              'section_D': 0.70, // Alta
            },
            totalSections: 4,
            averageCongestion: 0.54,
          );
        });
      }
    }
  }

  // Coordenadas do Estádio do Dragão (Porto, Portugal)
  static const LatLng stadiumCenter = LatLng(41.161758, -8.583933);

  // Bounding box do estádio (aproximado - ajustar com dados reais do backend)
  static final LatLngBounds stadiumBounds = LatLngBounds(
    const LatLng(41.1600, -8.5850), // Southwest
    const LatLng(41.1635, -8.5820), // Northeast
  );

  @override
  void initState() {
    super.initState();
    // Inicializar com a rota passada como parâmetro
    _currentRoute = widget.highlightedRoute;
    _loadMapData();
  }

  Future<void> _loadMapData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      print('[StadiumMapPage] Carregando POIs do piso $_currentFloor...');

      // Carregar POIs e nós
      final pois = await _mapService.getPOIsByFloor(_currentFloor);
      final nodes = await _mapService.getAllNodes();

      print('[StadiumMapPage] ${pois.length} POIs carregados');
      print('[StadiumMapPage] ${nodes.length} nós carregados');

      setState(() {
        _pois = pois;
        _nodes = nodes;
        _isLoading = false;
      });
    } catch (e) {
      print('[StadiumMapPage] Erro ao carregar POIs: $e');
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  /// Converte coordenadas do backend (x, y) para LatLng do mapa
  /// Assumindo que x,y do backend estão em metros relativos ao centro
  LatLng _convertToLatLng(double x, double y) {
    // Aproximação: 1 metro ≈ 0.00001 graus de latitude
    // Ajustar conforme necessário com dados reais do estádio
    const metersToLatDegrees = 0.000009;
    const metersToLngDegrees = 0.000012; // Longitude varia com latitude

    return LatLng(
      stadiumCenter.latitude + (y * metersToLatDegrees),
      stadiumCenter.longitude + (x * metersToLngDegrees),
    );
  }

  /// Encontra o nó mais próximo de um POI baseado em coordenadas (x, y)
  String _findNearestNode(POIModel poi) {
    if (_nodes.isEmpty) return userNodeId;

    NodeModel? nearest;
    double minDistance = double.infinity;

    for (var node in _nodes) {
      // Só considerar nós do mesmo piso
      if (node.level != poi.level) continue;

      // Calcular distância euclidiana
      final dx = node.x - poi.x;
      final dy = node.y - poi.y;
      final distance = sqrt(dx * dx + dy * dy);

      if (distance < minDistance) {
        minDistance = distance;
        nearest = node;
      }
    }

    return nearest?.id ?? userNodeId;
  }

  /// Método público para fazer zoom num POI (usado pela barra de pesquisa)
  void zoomToPOI(POIModel poi) {
    final poiLocation = _convertToLatLng(poi.x, poi.y);
    _mapController.move(poiLocation, 19.5);
  }

  /// Mostra detalhes do POI num bottom sheet com zoom
  void _showPOIDetails(POIModel poi) async {
    // Guardar apenas o zoom atual (não a posição)
    final previousZoom = _mapController.camera.zoom;

    // Fazer zoom no POI
    final poiLocation = _convertToLatLng(poi.x, poi.y);
    _mapController.move(poiLocation, 19.5);

    // Calcular rota para o POI (apenas para mostrar distância/tempo no popup)
    RouteModel? route;
    try {
      final nearestNode = _findNearestNode(poi);
      route = await _routingService.getRoute(
        fromNode: userNodeId,
        toNode: nearestNode,
      );
    } catch (e) {
      print('[StadiumMapPage] Erro ao calcular rota: $e');
    }

    if (!mounted) return;

    POIDetailsSheet.show(
      context,
      poi: poi,
      route: route,
      onNavigate: () {
        // Apenas desenhar rota quando user clicar em Navigate
        if (route != null) {
          setState(() {
            _currentRoute = route;
          });
        }
      },
    ).whenComplete(() {
      // Apenas fazer zoom-out (mantém a posição centrada no POI)
      if (mounted) {
        final currentCenter = _mapController.camera.center;
        _mapController.move(currentCenter, previousZoom);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Mapa
        if (_errorMessage != null)
          _buildErrorState()
        else if (_isLoading)
          _buildLoadingState()
        else
          _buildMap(),
      ],
    );
  }

  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: stadiumCenter,
        initialZoom: 18.0,
        minZoom: 17.0,
        maxZoom: 20.0,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
      ),
      children: [
        // Remove a atribuição padrão do flutter_map
        RichAttributionWidget(attributions: []),
        // Camada de fundo cinza
        TileLayer(
          tileProvider: NetworkTileProvider(),
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.estadio.dragao.fan_app',
        ),

        // Camada base - Imagem do estádio
        OverlayImageLayer(
          overlayImages: [
            OverlayImage(
              bounds: stadiumBounds,
              opacity: 1.0,
              imageProvider: const AssetImage(
                'assets/images/map_placeholder.png',
              ),
            ),
          ],
        ),

        // Camada de heatmap (se ativa)
        if (widget.showHeatmap) _buildHeatmapLayer(),

        // Camada de rota (polyline)
        if (_currentRoute != null) _buildRouteLayer(),

        // Camada de POIs (markers)
        _buildPOILayer(),
      ],
    );
  }

  /// Camada de heatmap com círculos coloridos baseados na congestão
  Widget _buildHeatmapLayer() {
    if (_heatmapData == null || _heatmapData!.sections.isEmpty) {
      return const SizedBox.shrink();
    }

    // Posições de demo para cada secção (ajustar com dados reais)
    final sectionPositions = {
      'section_A': const LatLng(41.1625, -8.5840),
      'section_B': const LatLng(41.1610, -8.5830),
      'section_C': const LatLng(41.1615, -8.5845),
      'section_D': const LatLng(41.1620, -8.5825),
    };

    final circles = <CircleMarker>[];

    _heatmapData!.sections.forEach((sectionId, congestionLevel) {
      final position = sectionPositions[sectionId];
      if (position == null) return;

      // Cor baseada no nível de congestão (verde→amarelo→vermelho)
      final color = _getCongestionColor(congestionLevel);

      // Círculos concêntricos para efeito de gradiente
      // Círculo exterior (maior, mais transparente)
      circles.add(
        CircleMarker(
          point: position,
          radius: 40,
          color: color.withOpacity(0.2),
          borderColor: Colors.transparent,
          borderStrokeWidth: 0,
        ),
      );

      // Círculo médio
      circles.add(
        CircleMarker(
          point: position,
          radius: 25,
          color: color.withOpacity(0.4),
          borderColor: Colors.transparent,
          borderStrokeWidth: 0,
        ),
      );

      // Círculo interior (menor, mais intenso)
      circles.add(
        CircleMarker(
          point: position,
          radius: 12,
          color: color.withOpacity(0.7),
          borderColor: Colors.transparent,
          borderStrokeWidth: 0,
        ),
      );
    });

    return CircleLayer(circles: circles);
  }

  /// Retorna cor baseada no nível de congestão (0-1)
  Color _getCongestionColor(double level) {
    if (level <= 0.3) {
      // Baixa congestão: verde/cyan
      return const Color(0xFF00D4AA);
    } else if (level <= 0.6) {
      // Média congestão: amarelo/laranja
      return const Color(0xFFFFB800);
    } else {
      // Alta congestão: vermelho/laranja escuro
      return const Color(0xFFFF4444);
    }
  }

  Widget _buildRouteLayer() {
    final route = _currentRoute!;

    // Converter waypoints para LatLng
    final points = route.waypoints
        .where(
          (wp) => wp.level == _currentFloor,
        ) // Só mostrar waypoints do piso atual
        .map((wp) => _convertToLatLng(wp.x, wp.y))
        .toList();

    return PolylineLayer(
      polylines: [
        Polyline(
          points: points,
          color: Colors.blue,
          strokeWidth: 4.0,
          borderColor: Colors.white,
          borderStrokeWidth: 2.0,
        ),
      ],
    );
  }

  Widget _buildPOILayer() {
    // Determinar quais POIs mostrar
    List<POIModel> poisToShow;
    if (widget.showAllPOIs) {
      poisToShow = _pois;
    } else if (widget.highlightedPOI != null) {
      poisToShow = [widget.highlightedPOI!];
    } else {
      poisToShow = [];
    }

    // Adicionar marcador da posição do utilizador (N1)
    final userMarkers = <Marker>[];
    if (_nodes.isNotEmpty) {
      final userNode = _nodes.firstWhere(
        (n) => n.id == userNodeId,
        orElse: () => _nodes.first,
      );

      userMarkers.add(
        Marker(
          point: _convertToLatLng(userNode.x, userNode.y),
          width: 60,
          height: 60,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(
              Icons.person_pin_circle,
              color: Colors.white,
              size: 30,
            ),
          ),
        ),
      );
    }

    return MarkerLayer(
      markers: [
        ...userMarkers,
        ...poisToShow.map<Marker>((POIModel poi) {
          final position = _convertToLatLng(poi.x, poi.y);
          final isHighlighted = widget.highlightedPOI?.id == poi.id;

          return Marker(
            point: position,
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
          );
        }).toList(),
      ],
    );
  }

  Widget _buildFloorSelector() {
    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_upward),
            onPressed: _currentFloor < 2
                ? () {
                    setState(() {
                      _currentFloor++;
                    });
                    _loadMapData();
                  }
                : null,
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Text(
              'Floor $_currentFloor',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_downward),
            onPressed: _currentFloor > 0
                ? () {
                    setState(() {
                      _currentFloor--;
                    });
                    _loadMapData();
                  }
                : null,
          ),
        ],
      ),
    );
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
            Text('Error', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
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
      case 'restroom':
        return Colors.blue.shade700;
      case 'food':
      case 'bar':
        return Colors.orange.shade700;
      case 'emergency_exit':
        return Colors.red.shade700;
      case 'first_aid':
        return Colors.green.shade700;
      case 'information':
        return Colors.purple.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  IconData _getPOIIcon(String category) {
    switch (category.toLowerCase()) {
      case 'restroom':
        return Icons.wc;
      case 'food':
        return Icons.restaurant;
      case 'bar':
        return Icons.local_bar;
      case 'emergency_exit':
        return Icons.exit_to_app;
      case 'first_aid':
        return Icons.local_hospital;
      case 'information':
        return Icons.info;
      default:
        return Icons.place;
    }
  }
}
