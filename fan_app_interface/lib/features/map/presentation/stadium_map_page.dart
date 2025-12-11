import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../data/models/poi_model.dart';
import '../data/models/node_model.dart';
import '../data/models/edge_model.dart';
import '../data/models/route_model.dart';
import '../data/services/map_service.dart';
import '../data/services/routing_service.dart';
import '../data/services/congestion_service.dart';
import '../../poi/presentation/poi_details_sheet.dart';
import 'layers/floor_plan_layer.dart';
import '../../navigation/presentation/navigation_page.dart';
import 'dart:async';

/// Página principal do mapa interativo do estádio
class StadiumMapPage extends StatefulWidget {
  final RouteModel? highlightedRoute;
  final POIModel? highlightedPOI;
  final bool showAllPOIs;
  final bool showHeatmap;
  final VoidCallback? onHeatmapConnectionError;
  final VoidCallback? onHeatmapConnectionSuccess;
  final MapController? mapController;
  final bool isNavigating;
  final LatLng? userPosition;
  final double? userHeading;
  final int initialFloor;
  final bool simplifiedMode; // Skip FloorPlanLayer for performance

  const StadiumMapPage({
    Key? key,
    this.highlightedRoute,
    this.highlightedPOI,
    this.showAllPOIs = true,
    this.showHeatmap = false,
    this.onHeatmapConnectionError,
    this.onHeatmapConnectionSuccess,
    this.mapController,
    this.isNavigating = false,
    this.userPosition,
    this.userHeading,
    this.initialFloor = 0,
    this.simplifiedMode = false,
  }) : super(key: key);

  @override
  State<StadiumMapPage> createState() => StadiumMapPageState();
}

class StadiumMapPageState extends State<StadiumMapPage> {
  late final MapController _mapController;
  final MapService _mapService = MapService();
  final RoutingService _routingService = RoutingService();
  final CongestionService _congestionService = CongestionService();

  // Posição fixa do utilizador para testes (entrada principal)
  static const String userNodeId = 'N1';

  // Estado
  int _currentFloor = 0;
  List<POIModel> _pois = [];
  List<NodeModel> _nodes = [];
  List<EdgeModel> _edges = [];
  List<dynamic> _seats = [];
  bool _isLoadingSeats = false;
  RouteModel? _currentRoute;
  bool _isLoading = true;
  String? _errorMessage;

  // Heatmap data
  StadiumHeatmapData? _heatmapData;
  Timer? _heatmapTimer;

  @override
  void initState() {
    super.initState();
    // Usa controller fornecido ou cria um interno
    _mapController = widget.mapController ?? MapController();
    // Inicializar com a rota passada como parâmetro
    _currentRoute = widget.highlightedRoute;
    // Usar o piso inicial fornecido
    _currentFloor = widget.initialFloor;
    _loadMapData();
  }

  @override
  void didUpdateWidget(StadiumMapPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Atualizar rota quando parâmetros mudarem
    if (widget.highlightedRoute != oldWidget.highlightedRoute) {
      setState(() {
        _currentRoute = widget.highlightedRoute;
      });
    }
    // Atualizar piso quando mudar externamente
    if (widget.initialFloor != oldWidget.initialFloor) {
      print(
        '[StadiumMapPage] Piso mudou: ${oldWidget.initialFloor} -> ${widget.initialFloor}',
      );
      setState(() {
        _currentFloor = widget.initialFloor;
      });
      _loadMapData();
    }
    // Carregar heatmap quando ativado
    if (widget.showHeatmap && !oldWidget.showHeatmap) {
      _startHeatmapUpdates();
    } else if (!widget.showHeatmap && oldWidget.showHeatmap) {
      _stopHeatmapUpdates();
    }
  }

  /// Inicia atualização periódica do heatmap (cada 10 segundos)
  void _startHeatmapUpdates() {
    print('[StadiumMapPage] Iniciando atualizações do heatmap (10s)');
    _loadHeatmapData(); // Carregar imediatamente
    _heatmapTimer?.cancel();
    _heatmapTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      print('[StadiumMapPage] Timer tick - atualizando heatmap');
      _loadHeatmapData();
    });
  }

  /// Para atualização periódica do heatmap
  void _stopHeatmapUpdates() {
    print('[StadiumMapPage] Parando atualizações do heatmap');
    _heatmapTimer?.cancel();
    _heatmapTimer = null;
  }

  @override
  void dispose() {
    _stopHeatmapUpdates();
    super.dispose();
  }

  /// Carrega dados de congestão para o heatmap
  Future<void> _loadHeatmapData() async {
    print('[StadiumMapPage] Carregando dados do heatmap...');
    try {
      final data = await _congestionService.getStadiumHeatmap();
      print(
        '[StadiumMapPage] Heatmap carregado: ${data.sections.length} seções, avg: ${data.averageCongestion}',
      );
      if (mounted) {
        setState(() {
          _heatmapData = data;
        });
        // Notificar sucesso de conexão
        widget.onHeatmapConnectionSuccess?.call();
      }
    } catch (e) {
      print('[StadiumMapPage] Erro ao carregar heatmap: $e');
      // Limpar dados do heatmap em caso de erro
      if (mounted) {
        setState(() {
          _heatmapData = null;
        });
        // Notificar erro de conexão
        widget.onHeatmapConnectionError?.call();
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

  Future<void> _loadSeats() async {
    if (_isLoadingSeats || _seats.isNotEmpty) return;

    print('[StadiumMapPage] Carregando lugares (zoom > 19)...');
    setState(() {
      _isLoadingSeats = true;
    });

    try {
      final seats = await _mapService.getAllSeats();
      if (mounted) {
        setState(() {
          _seats = seats;
          _isLoadingSeats = false;
        });
        print('[StadiumMapPage] ${seats.length} lugares carregados');
      }
    } catch (e) {
      print('[StadiumMapPage] Erro ao carregar lugares: $e');
      if (mounted) {
        setState(() {
          _isLoadingSeats = false;
        });
      }
    }
  }

  Future<void> _loadMapData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      print('[StadiumMapPage] Carregando POIs do piso $_currentFloor...');

      // Carregar POIs, nós e arestas
      final pois = await _mapService.getPOIsByFloor(_currentFloor);
      final nodes = await _mapService.getAllNodes();
      final edges = await _mapService.getAllEdges();

      print('[StadiumMapPage] ${pois.length} POIs carregados');
      print('[StadiumMapPage] ${nodes.length} nós carregados');
      print('[StadiumMapPage] ${edges.length} arestas carregadas');

      setState(() {
        _pois = pois;
        _nodes = nodes;
        _edges = edges;
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
  /// O backend usa coordenadas em unidades arbitrárias:
  /// X: 82 a 916 (centro ~499)
  /// Y: 60 a 740 (centro ~400)
  LatLng _convertToLatLng(double x, double y) {
    // Centro das coordenadas do backend
    const backendCenterX = 499.0; // (82 + 916) / 2
    const backendCenterY = 400.0; // (60 + 740) / 2

    // Aproximação: 1 unidade do backend ≈ graus
    // Ajustado para que o estádio (~800 unidades largura) caiba nos bounds
    const unitsToLatDegrees = 0.000004; // Ajustado para melhor escala
    const unitsToLngDegrees = 0.000005; // Longitude ligeiramente diferente

    // Centrar as coordenadas antes de converter
    final centeredX = x - backendCenterX;
    final centeredY = y - backendCenterY;

    return LatLng(
      stadiumCenter.latitude + (centeredY * unitsToLatDegrees),
      stadiumCenter.longitude + (centeredX * unitsToLngDegrees),
    );
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
      // Obter posição do utilizador a partir do nó N1
      final userNode = _nodes.firstWhere(
        (n) => n.id == userNodeId,
        orElse: () => _nodes.first,
      );

      print('[StadiumMapPage] === DEBUG ROTA ===');
      print(
        '[StadiumMapPage] Utilizador: ${userNode.id} em (${userNode.x}, ${userNode.y}) level ${userNode.level}',
      );
      print(
        '[StadiumMapPage] Destino POI: ${poi.id} "${poi.name}" em (${poi.x}, ${poi.y}) level ${poi.level}',
      );
      print(
        '[StadiumMapPage] Convertido utilizador: ${_convertToLatLng(userNode.x, userNode.y)}',
      );
      print(
        '[StadiumMapPage] Convertido destino: ${_convertToLatLng(poi.x, poi.y)}',
      );

      // Usar rota por coordenadas para evitar 404 se o ID não existir no backend
      route = await _routingService.getRouteToCoordinates(
        startX: userNode.x,
        startY: userNode.y,
        startLevel: userNode.level,
        endX: poi.x,
        endY: poi.y,
        endLevel: poi.level,
        allNodes: _nodes,
      );

      print('[StadiumMapPage] Rota calculada com sucesso!');
      print('[StadiumMapPage] - Distância: ${route.distance}m');
      print('[StadiumMapPage] - Tempo estimado: ${route.estimatedTime}s');
      print('[StadiumMapPage] - Waypoints: ${route.waypoints.length}');
      if (route.waypoints.isNotEmpty) {
        print(
          '[StadiumMapPage] - Primeiro waypoint: (${route.waypoints.first.x}, ${route.waypoints.first.y})',
        );
        print(
          '[StadiumMapPage] - Último waypoint: (${route.waypoints.last.x}, ${route.waypoints.last.y})',
        );
      }
    } catch (e) {
      print('[StadiumMapPage] ERRO ao calcular rota: $e');
    }

    if (!mounted) return;

    POIDetailsSheet.show(
      context,
      poi: poi,
      route: route,
      onNavigate: () {
        if (route != null) {
          // Navegar para a página de navegação
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NavigationPage(
                route: route!,
                destination: poi,
                nodes: _nodes,
              ),
            ),
          );

          // Também desenhar rota no mapa caso volte
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

        // Botão de centrar foi removido - aparece apenas na NavigationPage
      ],
    );
  }

  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: stadiumCenter,
        initialZoom: 16.5,
        minZoom: 16.0,
        maxZoom: 20.0,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
        onMapEvent: (event) {
          if (event.camera.zoom >= 19.0 && _seats.isEmpty) {
            _loadSeats();
          }
        },
      ),
      children: [
        // Remove a atribuição padrão do flutter_map
        RichAttributionWidget(attributions: []),

        // Camada do Mapa Gerado (Floor Plan) - Skip in simplified mode for performance
        if (!widget.simplifiedMode)
          FloorPlanLayer(
            edges: _edges,
            nodes: _nodes,
            currentLevel: _currentFloor,
            converter: _convertToLatLng,
          ),

        // Camada de Lugares (Seats) - Apenas se zoom > 19 e não simplificado
        if (!widget.simplifiedMode &&
            _seats.isNotEmpty &&
            _mapController.camera.zoom >= 19.0)
          CircleLayer(
            circles: _seats.map((seat) {
              // seat espera-se que seja Map {"x":123, "y":456, ...}
              final x = (seat['x'] as num).toDouble();
              final y = (seat['y'] as num).toDouble();
              return CircleMarker(
                point: _convertToLatLng(x, y),
                radius: 2,
                color: Colors.green.shade800,
                borderColor: Colors.transparent,
              );
            }).toList(),
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

    final circles = <CircleMarker>[];

    _heatmapData!.sections.forEach((cellId, congestionLevel) {
      // Ignorar congestão abaixo de 20%
      if (congestionLevel < 0.20) return;

      // Converter cell_X_Y para coordenadas do grid
      final position = _cellIdToLatLng(cellId);
      if (position == null) return;

      // Cor baseada no nível de congestão (verde→amarelo→laranja→vermelho)
      final color = _getCongestionColor(congestionLevel);

      // Círculos concêntricos para efeito de gradiente
      // Círculo exterior (maior, mais transparente)
      circles.add(
        CircleMarker(
          point: position,
          radius: 20,
          color: color.withOpacity(0.3),
          borderColor: Colors.transparent,
          borderStrokeWidth: 0,
        ),
      );

      // Círculo interior (menor, mais intenso)
      circles.add(
        CircleMarker(
          point: position,
          radius: 10,
          color: color.withOpacity(0.6),
          borderColor: Colors.transparent,
          borderStrokeWidth: 0,
        ),
      );
    });

    return CircleLayer(circles: circles);
  }

  /// Converte ID de célula (cell_X_Y) para coordenadas LatLng
  LatLng? _cellIdToLatLng(String cellId) {
    // Formato esperado: cell_X_Y
    final parts = cellId.split('_');
    if (parts.length != 3 || parts[0] != 'cell') return null;

    final x = int.tryParse(parts[1]);
    final y = int.tryParse(parts[2]);
    if (x == null || y == null) return null;

    // Converter coordenadas do grid para posição no mapa
    // O grid parece ter células de ~10 unidades, mapeando para o estádio
    // Ajustar escala para corresponder aos bounds do estádio
    const gridSize = 20; // Tamanho de cada célula no grid
    final mapX = (x * gridSize).toDouble();
    final mapY = (y * gridSize).toDouble();

    return _convertToLatLng(mapX, mapY);
  }

  /// Retorna cor baseada no nível de congestão (0.2-1.0)
  /// Gradiente: verde → amarelo → laranja → vermelho → vermelho escuro
  Color _getCongestionColor(double level) {
    if (level <= 0.30) {
      // 20-30%: Verde claro
      return const Color(0xFF4CAF50);
    } else if (level <= 0.40) {
      // 30-40%: Verde amarelado
      return const Color(0xFF8BC34A);
    } else if (level <= 0.50) {
      // 40-50%: Amarelo
      return const Color(0xFFFFEB3B);
    } else if (level <= 0.60) {
      // 50-60%: Laranja claro
      return const Color(0xFFFF9800);
    } else if (level <= 0.70) {
      // 60-70%: Laranja escuro
      return const Color(0xFFFF5722);
    } else if (level <= 0.80) {
      // 70-80%: Vermelho
      return const Color(0xFFF44336);
    } else {
      // 80-100%: Vermelho escuro
      return const Color(0xFFB71C1C);
    }
  }

  Widget _buildRouteLayer() {
    final route = _currentRoute!;

    // IMPORTANTE: O Routing Service retorna coordenadas incorretas!
    // Usamos os node_ids para buscar as coordenadas corretas dos nós do Map Service
    final nodesMap = {for (var n in _nodes) n.id: n};

    print('[StadiumMapPage] === DESENHANDO ROTA ===');
    print(
      '[StadiumMapPage] Waypoints do Routing Service: ${route.waypoints.length}',
    );

    final points = <LatLng>[];
    int foundCount = 0;
    int notFoundCount = 0;

    for (var wp in route.waypoints) {
      // Tentar encontrar o nó no Map Service
      final node = nodesMap[wp.nodeId];
      if (node != null) {
        points.add(_convertToLatLng(node.x, node.y));
        foundCount++;
      } else {
        // Fallback: usar coordenadas do routing service (podem estar erradas)
        print(
          '[StadiumMapPage] AVISO: Nó ${wp.nodeId} não encontrado no Map Service!',
        );
        points.add(_convertToLatLng(wp.x, wp.y));
        notFoundCount++;
      }
    }

    print('[StadiumMapPage] Nós encontrados no Map Service: $foundCount');
    print('[StadiumMapPage] Nós NÃO encontrados: $notFoundCount');
    print('[StadiumMapPage] Total de pontos na linha: ${points.length}');

    if (points.isNotEmpty) {
      print('[StadiumMapPage] Primeiro ponto: ${points.first}');
      print('[StadiumMapPage] Último ponto: ${points.last}');
    }

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

    // Durante navegação: mostrar apenas o destino (se houver)
    if (widget.isNavigating) {
      poisToShow = widget.highlightedPOI != null
          ? [widget.highlightedPOI!]
          : [];
    } else if (widget.showAllPOIs) {
      poisToShow = _pois;
    } else if (widget.highlightedPOI != null) {
      poisToShow = [widget.highlightedPOI!];
    } else {
      poisToShow = [];
    }

    // Adicionar marcador da posição do utilizador
    final userMarkers = <Marker>[];

    if (widget.isNavigating && widget.userPosition != null) {
      // Modo Navegação: Usar posição dinâmica
      userMarkers.add(
        Marker(
          point: widget.userPosition!,
          width: 60,
          height: 60,
          child: Transform.rotate(
            angle: widget.userHeading ?? 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.blueAccent, // Cor diferente para navegação
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
                Icons.navigation,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
        ),
      );
    } else if (_nodes.isNotEmpty) {
      // Modo Estático: Usar posição fixa (N1)
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
        return Colors.orange.shade700;
      case 'bar':
        return Colors.purple.shade700;
      case 'emergency_exit':
        return Colors.red.shade700;
      case 'first_aid':
        return Colors.green.shade700;
      case 'information':
        return Colors.cyan.shade700;
      case 'gate':
        return Colors.indigo.shade700;
      case 'merchandise':
      case 'shop':
        return Colors.pink.shade700;
      case 'stairs':
      case 'ramp':
        return Colors.amber.shade700;
      case 'entrance':
        return Colors.teal.shade700;
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
      case 'gate':
        return Icons.door_front_door;
      case 'merchandise':
      case 'shop':
        return Icons.store;
      case 'stairs':
        return Icons.stairs;
      case 'ramp':
        return Icons.accessible;
      case 'entrance':
        return Icons.login;
      default:
        return Icons.place;
    }
  }
}
