import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:fan_app_interface/l10n/app_localizations.dart';
import 'dart:math' as math;
import '../data/models/poi_model.dart';
import '../data/models/node_model.dart';
import '../data/models/edge_model.dart';
import '../data/models/route_model.dart';
import '../data/models/tile_model.dart';
import '../data/services/map_service.dart';
import '../data/services/routing_service.dart';
import '../data/services/congestion_service.dart';
// import '../data/services/saved_places_service.dart'; // Removed favorites
import '../../poi/presentation/poi_details_sheet.dart';
import 'layers/floor_plan_layer.dart';
import '../../navigation/presentation/navigation_page.dart';
import '../../navigation/data/services/user_position_service.dart';
import '../../navigation/data/services/user_position_service.dart';
import '../../ticket/data/models/ticket_model.dart'; // Import TicketModel
import '../../ticket/data/services/ticket_storage_service.dart'; // Import Storage
import 'dart:async';
import '../../../core/utils/geographic_utils.dart';
import '../../../core/config/map_config.dart';

/// Página principal do mapa interativo do estádio
class StadiumMapPage extends StatefulWidget {
  final RouteModel? highlightedRoute;
  final POIModel? highlightedPOI;
  final bool showAllPOIs;
  final bool showHeatmap;
  final bool
  showOtherPOIs; // Se false, esconde todos os POIs genéricos (mostra apenas highlighted/user)
  final VoidCallback? onHeatmapConnectionError;
  final VoidCallback? onHeatmapConnectionSuccess;
  final MapController? mapController;
  final bool isNavigating;
  final LatLng? userPosition;
  final double? userHeading;
  final int initialFloor;
  final bool simplifiedMode; // Skip FloorPlanLayer for performance
  final int routeStartWaypointIndex; // Índice onde começa a linha da rota
  final Function(POIModel)? onTapPOI;
  final ValueChanged<int>? onFloorChanged;
  final bool avoidStairs;
  final void Function(MapCamera, bool)? onPositionChanged;

  const StadiumMapPage({
    super.key,
    this.initialFloor = 0,
    this.mapController,
    this.highlightedRoute,
    this.highlightedPOI,
    this.showAllPOIs = true,
    this.showOtherPOIs = true,
    this.showHeatmap = false,
    this.onHeatmapConnectionSuccess,
    this.onHeatmapConnectionError,
    this.onTapPOI,
    this.onFloorChanged,
    this.isNavigating = false,
    this.userPosition,
    this.userHeading,
    this.simplifiedMode = false,
    this.routeStartWaypointIndex = 0,
    this.avoidStairs = false,
    this.onPositionChanged,
    this.isEmergency = false,
  });

  final bool isEmergency;

  @override
  State<StadiumMapPage> createState() => StadiumMapPageState();
}

class StadiumMapPageState extends State<StadiumMapPage>
    with SingleTickerProviderStateMixin {
  late final MapController _mapController;
  late final AnimationController _blinkController;
  final MapService _mapService = MapService();
  final RoutingService _routingService = RoutingService();
  final CongestionService _congestionService = CongestionService();

  // Posição do utilizador (carregada do UserPositionService)
  double _userPositionX = 0.0;
  double _userPositionY = 0.0;
  int _userLevel = 0; // Guardar nível real do utilizador
  String _userNodeId = 'N1';
  bool _userPositionLoaded = false;
  double _userHeading = 0.0; // Heading em graus (0 = Norte)

  // Estado
  int _currentFloor = 0;
  List<POIModel> _pois = [];
  // List<POIModel> _savedPlaces = []; // Removed favorites
  List<NodeModel> _nodes = [];
  List<EdgeModel> _edges = [];
  List<TileModel> _tiles = []; // Tiles para verificar walkable
  RouteModel? _currentRoute;
  bool _isLoading = true;
  String? _errorMessage;

  // Heatmap data
  StadiumHeatmapData? _heatmapData;
  Timer? _heatmapTimer;

  // Ticket data
  TicketModel? _userTicket;
  final TicketStorageService _ticketStorage = TicketStorageService();

  @override
  void initState() {
    super.initState();
    // Usa controller fornecido ou cria um interno
    _mapController = widget.mapController ?? MapController();
    // Inicializar com a rota passada como parâmetro
    _currentRoute = widget.highlightedRoute;
    // Usar o piso inicial fornecido
    _currentFloor = widget.initialFloor;
    // Posição inicial: será carregada do UserPositionService
    _userNodeId = 'N1';
    _userPositionX = 0.0;
    _userPositionY = 0.0;
    _userLevel = 0;
    _userPositionLoaded = false;

    // Initialize blink animation for emergency mode
    _blinkController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..repeat(reverse: true);

    loadUserPosition(); // Carregar posição guardada
    _loadMapData();
  }

  @override
  void dispose() {
    _blinkController.dispose();
    _stopHeatmapUpdates();
    super.dispose();
  }

  /// Carrega a posição guardada do utilizador
  Future<void> loadUserPosition({bool updateFloor = true}) async {
    final position = await UserPositionService.getPosition();
    if (mounted) {
      double x = position.x;
      double y = position.y;

      // VALIDAÇÃO: Se a posição carregada estiver fora dos limites (ex: pixels do dragão), resetar para o centro
      // Coordenadas válidas para UA devem estar perto de (40.6, -8.6)
      final LatLng currentLatLng = _convertToLatLng(x, y);
      if (!stadiumBounds.contains(currentLatLng)) {
        // Ignorar se estiver em navegação (permitir movimento livre durante simulação)
        if (widget.isNavigating) return;

        print(
          "[StadiumMapPage] ⚠️ Invalid position detected (${x}, ${y}). Resetting to center.",
        );
        x = stadiumCenter.longitude;
        y = stadiumCenter.latitude;
      }

      print(
        "[StadiumMapPage] 📥 Loading user position from service: $x, $y (Level ${position.level})",
      );
      setState(() {
        _userPositionX = x;
        _userPositionY = y;
        _userNodeId = position.nodeId;
        _userLevel = position.level; // Guardar nível real

        // Só atualizar _currentFloor a partir da posição guardada se solicitado E não estivermos em navegação
        if (updateFloor && !widget.isNavigating) {
          if (_currentFloor != position.level) {
            _currentFloor = position.level;
            widget.onFloorChanged?.call(_currentFloor);
            _loadMapData();
          }
        }
        _userPositionLoaded = true;
      });
    }
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
      // Atualizar _currentFloor sempre que o pai mandar (NavigationPage ou FilterButton)
      _currentFloor = widget.initialFloor;
      loadUserPosition(
        updateFloor: false,
      ); // Reload position data but keep current floor
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
    _loadHeatmapData(); // Carregar imediatamente
    _heatmapTimer?.cancel();
    _heatmapTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _loadHeatmapData();
    });
  }

  /// Para atualização periódica do heatmap
  void _stopHeatmapUpdates() {
    _heatmapTimer?.cancel();
    _heatmapTimer = null;
  }

  /// Carrega dados de congestão para o heatmap
  Future<void> _loadHeatmapData() async {
    try {
      final data = _congestionService.getStadiumHeatmap();
      if (mounted) {
        setState(() {
          _heatmapData = data;
        });
        // Notificar sucesso de conexão
        widget.onHeatmapConnectionSuccess?.call();
      }
    } catch (e) {
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

  /// Public method to reload map data (called from parent)
  void reloadMapData() {
    print("🔁 Reloading map data requested...");
    _loadMapData();
  }

  Iterable<Marker> _buildTicketMarkers() sync* {
    print(
      "🎫 Building ticket markers. Ticket: $_userTicket, SeatNodeId: ${_userTicket?.seatNodeId}",
    );
    if (_userTicket == null || _userTicket!.seatNodeId == null) return;

    try {
      print("🔍 Searching for seat node: ${_userTicket!.seatNodeId}");
      final seatNode = _nodes.firstWhere(
        (n) => n.id == _userTicket!.seatNodeId,
      );
      print(
        "✅ Seat node found: ${seatNode.id} at level ${seatNode.level} (Current floor: $_currentFloor)",
      );

      if (seatNode.level == _currentFloor) {
        final seatPos = _convertToLatLng(seatNode.x, seatNode.y);
        yield Marker(
          point: seatPos,
          width: 50,
          height: 50,
          child: GestureDetector(
            onTap: () {
              // Create a temporary POI for the seat to allow navigation
              final l = AppLocalizations.of(context)!;
              final seatPOI = POIModel(
                id: seatNode.id,
                name: l.yourSeat,
                x: seatNode.x,
                y: seatNode.y,
                level: seatNode.level,
                category: 'seat',
                description: l.ticketId(_userTicket!.id),
              );
              _showPOIDetails(seatPOI);
            },
            child: Container(
              decoration: BoxDecoration(
                color: Colors.green, // Destaque Verde
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
                Icons.event_seat,
                color: Colors.white,
                size: 28, // Ícone maior
              ),
            ),
          ),
        );
      }
    } catch (e) {
      print("❌ Error building ticket marker: $e");
      // Ignore
    }
  }

  // Coordenadas da Universidade de Aveiro 
  static const LatLng stadiumCenter = LatLng(40.6300, -8.6558);

  // Bounding box da UA (aproximado)
  static final LatLngBounds stadiumBounds = LatLngBounds(
    const LatLng(40.6250, -8.6600), // Southwest
    const LatLng(40.6350, -8.6500), // Northeast
  );

  Future<void> _loadMapData() async {
    final floorToLoad = _currentFloor;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Carregar POIs, nós, arestas, tiles e lugares guardados
      // Usar a variável capturada para garantir consistência
      final pois = await _mapService.getPOIsByFloor(floorToLoad);
      final nodes = await _mapService.getAllNodes();
      final edges = await _mapService.getAllEdges();
      final tiles = await _mapService.getAllTiles(level: floorToLoad);

      // final savedPlaces = await SavedPlacesService.getSavedPlaces(); // Removed favorites
      final ticket = await _ticketStorage.getTicket(); // Carregar bilhete
      print(
        "📥 Loaded ticket from storage: ${ticket?.id} - Seat: ${ticket?.seatNodeId}",
      );

      if (!mounted) return;
      if (_currentFloor != floorToLoad) {
        return;
      }

      // Se temos bilhete, carregar o nó do lugar especificamente (pois getAllNodes filtra seats)
      if (ticket != null && ticket.seatNodeId != null) {
        try {
          print("💺 Fetching specific seat node: ${ticket.seatNodeId}");
          final seatNode = await _mapService.getSeatById(ticket.seatNodeId!);
          if (seatNode != null) {
            print("✅ Seat node fetched: ${seatNode.id}");
            // Adicionar à lista de nós se ainda não existir
            if (!nodes.any((n) => n.id == seatNode.id)) {
              nodes.add(seatNode);
            }
          } else {
            print("⚠️ Seat node not found in backend: ${ticket.seatNodeId}");
          }
        } catch (e) {
          print("❌ Error fetching seat node: $e");
        }
      }

      setState(() {
        _pois = pois;
        _nodes = nodes;
        _edges = edges;
        _tiles = tiles;
        // _savedPlaces = savedPlaces; // Removed favorites
        _userTicket = ticket;
        _isLoading = false;
      });

      // Fazer zoom na posição do utilizador após carregar dados (apenas se não estiver em navegação)
      if (!widget.isNavigating) {
        _zoomToUserPosition();
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  /// Faz zoom na posição atual do utilizador
  void _zoomToUserPosition() {
    // Esperar um frame e um pequeno delay para garantir que o mapa está renderizado
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      // Delay adicional para garantir que o FlutterMap está pronto
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;

      try {
        // Se tem posição guardada válida (não é 0.0), usar essa
        if (_userPositionLoaded &&
            (_userPositionX != 0.0 || _userPositionY != 0.0)) {
          final userLatLng = _convertToLatLng(_userPositionX, _userPositionY);
          
          // Verificar se a posição carregada faz sentido no contexto atual
          // Se for uma coordenada legada (ex: x=219.7, y=112.3 do estádio), ignoramos
          if (stadiumBounds.contains(userLatLng)) {
            _mapController.move(userLatLng, 20.0);
          } else {
            // Posicao antiga era do outro mapa - resetamos para o centro da UA
            _mapController.move(stadiumCenter, 17.5);
          }
        } else if (_nodes.isNotEmpty) {
          // Fallback: usar nó N1 ou primeiro nó
          final userNode = _nodes.firstWhere(
            (n) => n.id == _userNodeId,
            orElse: () => _nodes.first,
          );
          final userLatLng = _convertToLatLng(userNode.x, userNode.y);
          _mapController.move(userLatLng, 20.0);
        }
      } catch (e) {}
    });
  }

  /// Agora que o backend e Frontend usam GPS real, esta função
  /// apenas passa os valores `x` (Longitude) e `y` (Latitude).
  /// Nota: O leaflet/flutter_map usa LatLng (Latitude=y, Longitude=x) padrão
  LatLng _convertToLatLng(double x, double y) {
    // x = Longitude, y = Latitude no nosso novo modelo
    return LatLng(y, x);
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
    // Calcular rota para o POI (apenas para mostrar distância/tempo no popup)
    RouteModel? route;
    try {
      // 1. Obter posição fresca do utilizador
      final savedPos = await UserPositionService.getPosition();
      double startX;
      double startY;
      int startLevel;

      if (savedPos.x != 0.0 || savedPos.y != 0.0) {
        startX = savedPos.x;
        startY = savedPos.y;
        startLevel = savedPos.level;
      } else {
        startX = _userPositionX;
        startY = _userPositionY;
        // Se não há posição guardada, usar _userLevel se disponível, se não, fallback inteligente
        // Se startX é 0 (posição default), assumimos N1 (nível 1).
        // Se startX != 0 mas _userLevel é 0, usamos _currentFloor como "melhor palpite" (mas isso causou o bug, então preferimos 1 se startX for 0)
        startLevel = _userLevel != 0
            ? _userLevel
            : (startX != 0.0 ? _currentFloor : 1);
      }

      // Usar rota por POI ID para obter wait_time do cache
      route = await _routingService.getRouteToPOI(
        startX: startX,
        startY: startY,
        startLevel: startLevel,
        poiId: poi.id,
        avoidStairs: widget.avoidStairs,
      );
    } catch (e) {}

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
                initialX: _userPositionX,
                initialY: _userPositionY,
                initialLevel: _userLevel,
              ),
            ),
          ).then((_) {
            // Recarregar posição do utilizador quando voltar da navegação
            loadUserPosition();
          });

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

        // Controlos de movimento (apenas na Home, não durante navegação)
        if (!widget.isNavigating && !_isLoading && _errorMessage == null)
          Positioned(
            left: 16,
            bottom: 110,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Botão de mover para frente (Simulação)
                FloatingActionButton(
                  heroTag: 'home_forward',
                  backgroundColor: const Color(0xFF161A3E),
                  onPressed: () => _moveForward(3),
                  tooltip: 'Mover para frente',
                  child: const Icon(Icons.navigation, color: Colors.white),
                ),
                const SizedBox(height: 12),
                
                // Botão de rodar (Simulação)
                FloatingActionButton(
                  heroTag: 'home_rotate',
                  mini: true,
                  backgroundColor: Colors.white,
                  onPressed: () => _rotateUser(45),
                  tooltip: 'Rodar 45°',
                  child: const Icon(
                    Icons.rotate_right,
                    color: Color(0xFF161A3E),
                  ),
                ),
                const SizedBox(height: 24),

                // Recenter
                FloatingActionButton(
                  heroTag: 'recenter',
                  backgroundColor: Colors.white,
                  mini: true,
                  onPressed: _zoomToUserPosition,
                  tooltip: 'Ir para minha posição',
                  child: const Icon(Icons.my_location, color: Colors.blue),
                ),
                const SizedBox(height: 12),

                // Reset Pos
                FloatingActionButton(
                  heroTag: 'reset_pos',
                  backgroundColor: Colors.white,
                  mini: true,
                  onPressed: () async {
                    await UserPositionService.resetToDefault();
                    await loadUserPosition();
                    _zoomToUserPosition();
                  },
                  tooltip: 'Resetar Posição (Emergência)',
                  child: const Icon(Icons.restore, color: Colors.orange),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Roda o utilizador em graus
  void _rotateUser(double degrees) {
    setState(() {
      _userHeading += degrees;
      _userHeading = _userHeading % 360;
      if (_userHeading < 0) _userHeading += 360;
    });
  }

  /// Move o utilizador para a frente na direção atual
  /// Move para o nó mais próximo na direção pretendida
  void _moveForward(double meters) async {
    if (_nodes.isEmpty) return;

    final rad = _userHeading * (math.pi / 180.0);
    final deltaMetersX = meters * math.sin(rad);
    final deltaMetersY = meters * -math.cos(rad);

    // Converter metros para graus (aproximação para o campus da UA)
    final deltaX = GeographicUtils.metersToDegrees(deltaMetersX);
    final deltaY = GeographicUtils.metersToDegrees(deltaMetersY);

    await _moveUser(deltaX, deltaY);
  }

  /// Move o utilizador e guarda a posição
  /// Limita o movimento a áreas walkable
  Future<void> _moveUser(double deltaX, double deltaY) async {
    if (_nodes.isEmpty) return;

    // Obter posição atual
    double currentX = _userPositionX;
    double currentY = _userPositionY;

    // Se posição atual é 0,0, usar posição do nó guardado
    if (currentX == 0.0 && currentY == 0.0) {
      final userNode = _nodes.firstWhere(
        (n) => n.id == _userNodeId,
        orElse: () => _nodes.first,
      );
      currentX = userNode.x;
      currentY = userNode.y;
    }

    // Calcular posição pretendida
    final targetX = currentX + deltaX;
    final targetY = currentY + deltaY;

    // Verificar se a posição pretendida é walkable
    if (!_isPositionWalkable(targetX, targetY)) {
      return;
    }

    // Encontrar nó mais próximo da posição pretendida (para guardar o nodeId)
    NodeModel? nearestNode;
    double minDist = double.infinity;
    for (final node in _nodes) {
      final d = GeographicUtils.calculateDistance(node.x, node.y, targetX, targetY);
      if (d < minDist) {
        minDist = d;
        nearestNode = node;
      }
    }

    if (nearestNode == null) return;

    // Usar a posição target (não snap to node) para movimento mais livre dentro dos corredores
    final newX = targetX;
    final newY = targetY;

    // Atualizar estado
    setState(() {
      _userPositionX = newX;
      _userPositionY = newY;
      _userNodeId = nearestNode!.id;
      _userPositionLoaded = true; // Garantir que está marcado como carregado
    });

    // Guardar posição
    await UserPositionService.savePosition(
      x: newX,
      y: newY,
      nodeId: nearestNode.id,
      level: _currentFloor,
    );

    // Centrar mapa no utilizador
    try {
      final userLatLng = _convertToLatLng(newX, newY);
      _mapController.move(userLatLng, _mapController.camera.zoom);
    } catch (e) {}
  }

  /// Verifica se uma posição está numa área walkable
  /// Para outdoor OSM, verificamos apenas se está perto de um nó do grafo
  bool _isPositionWalkable(double x, double y) {
    if (_nodes.isEmpty) return true;

    // Encontrar nó mais próximo usando Haversine
    double minDist = double.infinity;
    for (final node in _nodes) {
      final d = GeographicUtils.calculateDistance(node.x, node.y, x, y);
      if (d < minDist) {
        minDist = d;
      }
    }

    // Permitir movimento até X metros do nó mais próximo
    return minDist < MapConfig.walkableRadius;
  }



  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: widget.isNavigating && widget.userPosition != null 
          ? widget.userPosition! 
          : stadiumCenter,
        initialZoom: widget.isNavigating ? 20.0 : 17.0,
        minZoom: 14.0,
        maxZoom: 20.0,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
        onPositionChanged: widget.onPositionChanged,
      ),
      children: [
        // Base layer: OSM tiles (outdoor) ou fundo vazio (indoor)
        if (MapConfig.useOSMTiles)
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.dragao.fanapp',
          ),

        // Remove a atribuição padrão do flutter_map
        RichAttributionWidget(attributions: []),

        // Camada do Floor Plan (indoor mode)
        if (MapConfig.useFloorPlan && !widget.simplifiedMode)
          FloorPlanLayer(
            edges: _edges,
            nodes: _nodes,
            currentLevel: _currentFloor,
            converter: _convertToLatLng,
          ),

        // REMOVIDO: Camada de seats para melhor performance
        // O lugar do utilizador é mostrado separadamente se tiver bilhete

        // Camada de heatmap (se ativa)
        if (widget.showHeatmap) _buildHeatmapLayer(),

        // Camada de rota (polyline) - durante navegação OU quando há rota destacada (preview)
        if (_currentRoute != null &&
            (widget.isNavigating || widget.highlightedRoute != null))
          _buildRouteLayer(),

        // Camada de POIs (markers)
        _buildPOILayer(),
      ],
    );
  }

  /// Camada de heatmap com retângulos coloridos baseados na congestão
  Widget _buildHeatmapLayer() {
    if (_heatmapData == null || _heatmapData!.sections.isEmpty) {
      return const SizedBox.shrink();
    }

    final polygons = <Polygon>[];
    const cellSize =
        50; // Tamanho da célula do grid (50x50 unidades, igual ao simulator)

    _heatmapData!.sections.forEach((cellId, cellData) {
      // Filtrar pelo piso atual
      if (cellData.level != _currentFloor) return;

      // Extrair coordenadas do cellId
      // Suporta formato antigo (cell_X_Y) e novo (cell_L_X_Y)
      final parts = cellId.split('_');
      int? x, y;

      if (parts.length == 3 && parts[0] == 'cell') {
        // Formato antigo: cell_X_Y
        x = int.tryParse(parts[1]);
        y = int.tryParse(parts[2]);
      } else if (parts.length == 4 && parts[0] == 'cell') {
        // Novo formato: cell_L_X_Y
        x = int.tryParse(parts[2]);
        y = int.tryParse(parts[3]);
      } else {
        return;
      }

      if (x == null || y == null) return;

      // Cor baseada no nível de congestão
      final color = _getCongestionColor(cellData.congestionLevel);

      // Criar retângulo para a célula (cantos do quadrado)
      // Como agora x/y representam Lat/Lng
      // cellsize deixa de ser 50(pixeis) -> 0.0005 graus (aprox ~50 metros)
      const cellSizeLat = 0.0005; 
      const cellSizeLng = 0.0005;

      final topLeft = LatLng(
        y.toDouble() + cellSizeLat / 2,
        x.toDouble() - cellSizeLng / 2,
      );
      final topRight = LatLng(
        y.toDouble() + cellSizeLat / 2,
        x.toDouble() + cellSizeLng / 2,
      );
      final bottomRight = LatLng(
        y.toDouble() - cellSizeLat / 2,
        x.toDouble() + cellSizeLng / 2,
      );
      final bottomLeft = LatLng(
        y.toDouble() - cellSizeLat / 2,
        x.toDouble() - cellSizeLng / 2,
      );

      polygons.add(
        Polygon(
          points: [topLeft, topRight, bottomRight, bottomLeft],
          color: color.withOpacity(0.5),
          borderColor: color.withOpacity(0.7),
          borderStrokeWidth: 1,
        ),
      );
    });

    return PolygonLayer(polygons: polygons);
  }

  /// Converte ID de célula (cell_X_Y ou cell_L_X_Y) para coordenadas LatLng
  LatLng? _cellIdToLatLng(String cellId) {
    // Formato esperado: cell_X_Y ou cell_L_X_Y
    final parts = cellId.split('_');
    int? x, y;

    if (parts.length == 3 && parts[0] == 'cell') {
      x = int.tryParse(parts[1]);
      y = int.tryParse(parts[2]);
    } else if (parts.length == 4 && parts[0] == 'cell') {
      x = int.tryParse(parts[2]);
      y = int.tryParse(parts[3]);
    } else {
      return null;
    }

    if (x == null || y == null) return null;

    // As coordenadas X,Y já são absolutas (ex: 125, 425)
    // Não precisa multiplicar, usar diretamente
    return _convertToLatLng(x.toDouble(), y.toDouble());
  }

  /// Retorna cor baseada no nível de congestão (0.0-1.0)
  /// Gradiente ajustado para valores realistas (0-30%):
  /// verde → amarelo → laranja → vermelho
  Color _getCongestionColor(double level) {
    if (level <= 0.05) {
      // 0-5%: Verde claro
      return const Color(0xFF4CAF50);
    } else if (level <= 0.10) {
      // 5-10%: Verde amarelado
      return const Color(0xFF8BC34A);
    } else if (level <= 0.15) {
      // 10-15%: Amarelo
      return const Color(0xFFFFEB3B);
    } else if (level <= 0.20) {
      // 15-20%: Laranja claro
      return const Color(0xFFFF9800);
    } else if (level <= 0.25) {
      // 20-25%: Laranja escuro
      return const Color(0xFFFF5722);
    } else if (level <= 0.30) {
      // 25-30%: Vermelho
      return const Color(0xFFF44336);
    } else {
      // >30%: Vermelho escuro
      return const Color(0xFFB71C1C);
    }
  }

  Widget _buildRouteLayer() {
    final route = _currentRoute!;

    // IMPORTANTE: O Routing Service retorna coordenadas incorretas!
    // Usamos os node_ids para buscar as coordenadas corretas dos nós do Map Service
    // Mas confiamos no LEVEL retornado pelo Routing Service (pois define a rota 3D)
    final nodesMap = {for (var n in _nodes) n.id: n};

    // Lista de segmentos de rota (listas de pontos) para desenhar
    // O traço pode ser interrompido (ex: vai ao piso 0 e volta ao 1)
    final segments = <List<LatLng>>[];
    var currentSegment = <LatLng>[];

    // FILTRAR: Começar a partir do índice do próximo waypoint
    final startIndex = widget.routeStartWaypointIndex.clamp(
      0,
      route.waypoints.length,
    );
    final remainingWaypoints = route.waypoints.skip(startIndex);

    // Durante navegação: a semirreta do utilizador
    // Só adicionamos se o utilizador estiver neste piso
    if (widget.isNavigating &&
        widget.userPosition != null &&
        widget.initialFloor == _currentFloor) {
      currentSegment.add(widget.userPosition!);
      // Nota: Não adicionamos aos segments ainda, esperamos pelo primeiro ponto válido da rota para conectar
    }

    for (var wp in remainingWaypoints) {
      // Verificar se este ponto pertence ao piso atual OU se estamos em modo preview (mostrar tudo)
      if (!widget.isNavigating || wp.level == _currentFloor) {
        // Tentar encontrar o nó no Map Service para coords precisas
        final node = nodesMap[wp.nodeId];
        LatLng point;
        if (node != null) {
          point = _convertToLatLng(node.x, node.y);
        } else {
          point = _convertToLatLng(wp.x, wp.y);
        }
        currentSegment.add(point);
      } else {
        // Mudança de piso!
        // Se tínhamos um segmento sendo construído, finalizamo-lo agora.
        if (currentSegment.isNotEmpty) {
          // Se o segmento tem apenas 1 ponto (o utilizador ou um ponto isolado),
          // e esse ponto conecta a outro piso, talvez devêssemos mostrar?
          // Mas geralmente queremos linhas com >1 ponto.
          // Contudo, se for userPos -> Stairs (mesmo piso), são 2 pontos.
          // Se for apenas userPos (sem waypoints neste piso), ignoramos?
          if (currentSegment.length > 1 ||
              (widget.isNavigating && currentSegment.isNotEmpty)) {
            segments.add(List.from(currentSegment));
          }
          currentSegment = [];
        }
      }
    }

    // Adicionar o último segmento se existir
    if (currentSegment.isNotEmpty) {
      segments.add(currentSegment);
    }

    return AnimatedBuilder(
      animation: _blinkController,
      builder: (context, child) {
        final double opacity = widget.isEmergency
            ? 0.5 + (_blinkController.value * 0.5)
            : 1.0;

        return PolylineLayer(
          polylines: segments.map((points) {
            return Polyline(
              points: points,
              strokeWidth: 4.0,
              color: widget.isEmergency
                  ? const Color(0xFFBD453D).withOpacity(opacity)
                  : Colors.blue,
              borderColor: Colors.white,
              borderStrokeWidth: 1.0,
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildPOILayer() {
    // Adicionar marcador da posição do utilizador (sempre visível)
    final userMarkers = <Marker>[];

    // OTIMIZAÇÃO: Esconder POIs quando zoom está muito afastado (< 17.5)
    // Exceto durante navegação onde temos apenas o destino
    // NOTA: Usar try-catch porque o MapController pode não estar pronto na primeira renderização
    double currentZoom = 18.0; // Valor por defeito
    try {
      currentZoom = _mapController.camera.zoom;
    } catch (e) {
      // MapController ainda não está pronto, usar valor por defeito
    }
    // Regra de visibilidade baseada no Zoom (Janela de Visão)
    final showGenericPOIs = currentZoom >= 17.5;

    // Determinar quais POIs mostrar
    List<POIModel> poisToShow = [];

    // 1. Mostrar POIs genéricos se o zoom permitir ou "Show All" estiver ativo
    // MAS apenas se showOtherPOIs for true
    if (widget.showOtherPOIs && (showGenericPOIs || widget.showAllPOIs)) {
      poisToShow.addAll(_pois);
    }

    // 2. Garantir que o POI destacado (Destino ou Seleção) é SEMPRE visível em modo Preview
    // Em modo Navegação, respeita o piso.
    if (widget.highlightedPOI != null) {
      // Se NÃO estamos navegando (Preview), mostramos sempre.
      // Se ESTAMOS navegando, só mostramos se for do piso atual.
      bool show =
          !widget.isNavigating || widget.highlightedPOI!.level == _currentFloor;

      if (show) {
        if (!poisToShow.any((p) => p.id == widget.highlightedPOI!.id)) {
          poisToShow.add(widget.highlightedPOI!);
        }
      }
    }

    // Usar o userMarkers já definido acima

    if (widget.isNavigating && widget.userPosition != null) {
      // Modo Navegação: Usar posição dinâmica
      // Só mostrar se o utilizador estiver no piso atual visualizado
      // widget.initialFloor segue o nível do utilizador durante a navegação
      if (widget.initialFloor == _currentFloor) {
        // O mapa roda pelo heading, então precisamos contra-rodar o ícone
        // para que a seta fique SEMPRE a apontar para CIMA no ecrã
        final headingRadians = (widget.userHeading ?? 0) * (math.pi / 180.0);

        userMarkers.add(
          Marker(
            point: widget.userPosition!,
            width: 60,
            height: 60,
            child: AnimatedBuilder(
              animation: _blinkController,
              builder: (context, child) {
                final double opacity = widget.isEmergency
                    ? 0.7 + (_blinkController.value * 0.3)
                    : 1.0;

                return Transform.rotate(
                  angle:
                      -headingRadians +
                      math.pi, // Contra-rodar + 180° para correção
                  child: Container(
                    decoration: BoxDecoration(
                      color: widget.isEmergency
                          ? const Color(0xFFBD453D).withOpacity(opacity)
                          : Colors.blueAccent,
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
                );
              },
            ),
          ),
        );
      }
    } else if ((_nodes.isNotEmpty || _userPositionLoaded) &&
        _userLevel == _currentFloor) {
      // Modo Estático: Usar posição guardada do utilizador APENAS no mesmo piso
      LatLng userLatLng;

      if (_userPositionLoaded &&
          (_userPositionX != 0.0 || _userPositionY != 0.0)) {
        // Usar posição guardada
        userLatLng = _convertToLatLng(_userPositionX, _userPositionY);
      } else {
        // Fallback: usar nó
        final userNode = _nodes.firstWhere(
          (n) => n.id == _userNodeId,
          orElse: () => _nodes.first,
        );
        // Verificar nível do nó também? Assume-se que _userLevel está correto.
        userLatLng = _convertToLatLng(userNode.x, userNode.y);
      }

      userMarkers.add(
        Marker(
          point: userLatLng,
          width: 50,
          height: 50,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blue,
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
            child: const Icon(Icons.my_location, color: Colors.white, size: 30),
          ),
        ),
      );
    }

    // Calcular posição do utilizador para detetar sobreposição
    LatLng? currentUserLatLng;
    if (widget.isNavigating && widget.userPosition != null) {
      currentUserLatLng = widget.userPosition;
    } else if (_userPositionLoaded &&
        (_userPositionX != 0.0 || _userPositionY != 0.0)) {
      currentUserLatLng = _convertToLatLng(_userPositionX, _userPositionY);
    }

    final poiMarkers = poisToShow.map<Marker>((POIModel poi) {
      final position = _convertToLatLng(poi.x, poi.y);
      final isHighlighted = widget.highlightedPOI?.id == poi.id;

      // Detetar sobreposição com o user (< 15m)
      bool isNearUser = false;
      if (currentUserLatLng != null) {
        final dist = GeographicUtils.calculateDistance(
          position.longitude, position.latitude,
          currentUserLatLng.longitude, currentUserLatLng.latitude,
        );
        isNearUser = dist < 15.0;
      }

      return Marker(
        point: position,
        width: isHighlighted ? 60 : 50,
        height: isNearUser ? 70 : (isHighlighted ? 60 : 50),
        // Quando perto do user, desloca o POI para cima para não sobrepor
        alignment: isNearUser
            ? const Alignment(0.0, -1.5) // Sobe o marcador
            : Alignment.center,
        child: GestureDetector(
          onTap: () => _showPOIDetails(poi),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
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
                      color: Colors.black.withValues(alpha: 0.3),
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
              // Quando perto do user, mostra uma setinha a indicar a posição real
              if (isNearUser)
                const Icon(
                  Icons.arrow_drop_down,
                  color: Colors.grey,
                  size: 16,
                ),
            ],
          ),
        ),
      );
    }).toList();

    // Dois MarkerLayers separados:
    // 1) User markers — rodam com o mapa (seta de navegação)
    // 2) POI markers — ficam sempre alinhados ao ecrã (rotate: false)
    return Stack(
      children: [
        // POIs: sempre verticais, alinhados ao ecrã
        MarkerLayer(
          rotate: false,
          markers: [
            ..._buildTicketMarkers(),
            ...poiMarkers,
          ],
        ),
        // User: roda com o mapa (navegação), renderizado por cima dos POIs
        MarkerLayer(
          markers: userMarkers,
        ),
      ],
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
      case 'wc':
        return Colors.blue.shade700;
      case 'food':
      case 'cafe':
      case 'restaurant':
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
      case 'seat':
        return Colors.green.shade700;
      case 'library':
        return Colors.brown.shade700;
      case 'parking':
        return Colors.blueGrey.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  IconData _getPOIIcon(String category) {
    switch (category.toLowerCase()) {
      case 'restroom':
      case 'wc':
        return Icons.wc;
      case 'food':
      case 'restaurant':
        return Icons.restaurant;
      case 'cafe':
        return Icons.local_cafe;
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
      case 'seat':
        return Icons.event_seat;
      case 'library':
        return Icons.local_library;
      case 'parking':
        return Icons.local_parking;
      default:
        return Icons.place;
    }
  }
}
