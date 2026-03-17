import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_compass/flutter_map_compass.dart';
import 'package:flutter_map_heatmap/flutter_map_heatmap.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:fan_app_interface/l10n/app_localizations.dart';
import '../data/models/poi_model.dart';
import '../data/models/node_model.dart';
import '../data/models/edge_model.dart';
import '../data/models/route_model.dart';
import '../data/models/tile_model.dart';
import '../data/services/map_service.dart';
import '../data/services/routing_service.dart';
import '../data/services/congestion_service.dart';
import '../data/services/saved_places_service.dart';
import '../../../core/utils/poi_style.dart';
import 'layers/floor_plan_layer.dart';
import '../../navigation/presentation/navigation_page.dart';
import '../../navigation/data/services/user_position_service.dart';
// import '../../ticket/data/models/ticket_model.dart'; // Ticket feature disabled
// import '../../ticket/data/services/ticket_storage_service.dart'; // Ticket feature disabled
import '../../../core/utils/geographic_utils.dart';
import '../../../core/utils/cached_tile_provider.dart';
import '../../../core/utils/top_feedback.dart';

import 'dart:async';
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
  final ValueChanged<bool>? onPOIPanelChanged;
  final RouteModel? previewRoute;
  final bool interactivePOIs; // Allows disabling POI taps when shown in a menu
  final bool isFollowingUser; // Indicates if map should rotate with gyro
  final VoidCallback? onToggleNavigationHeatmap;
  final VoidCallback? onRecenterNavigation;
  final double? navigationControlsBottomInset;

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
    this.onPOIPanelChanged,
    this.previewRoute,
    this.interactivePOIs = true,
    this.isFollowingUser = true,
    this.onToggleNavigationHeatmap,
    this.onRecenterNavigation,
    this.navigationControlsBottomInset,
    this.customPOIsToShow,
    this.zoomOutToPOIs = false,
  });

  final bool isEmergency;
  final List<POIModel>? customPOIsToShow;
  final bool zoomOutToPOIs;

  @override
  State<StadiumMapPage> createState() => StadiumMapPageState();
}

class StadiumMapPageState extends State<StadiumMapPage>
    with SingleTickerProviderStateMixin {
  static const double _controlsCardRightInset = 20;
  static const double _controlsCardBottomInset = 100;
  static const double _controlsCardHeight = 116;
  static const double _controlsCardGapAbovePanel = 16;
  static const double _emergencyButtonGap = 12;
  static const double _emergencyButtonSize = 50;

  late final MapController _mapController;
  late final AnimationController _blinkController;
  final MapService _mapService = MapService();
  final RoutingService _routingService = RoutingService();
  final CongestionService _congestionService = CongestionService();

  // Posição do utilizador (carregada do UserPositionService)
  double _userPositionX = 0.0;
  double _userPositionY = 0.0;
  int _userLevel = 0; // Guardar nível real do utilizador
  // Estado
  int _currentFloor = 0;
  List<POIModel> _pois = [];
  List<NodeModel> _nodes = [];
  List<EdgeModel> _edges = [];
  List<TileModel> _tiles = []; // Tiles para verificar walkable
  RouteModel? _currentRoute;
  bool _isLoading = true;
  String? _errorMessage;

  // POI preview panel (non-modal, allows map interaction)
  POIModel? _selectedPOI;
  RouteModel? _previewRoute;
  bool _isCalculatingPreviewRoute = false;
  bool _isSelectedPOISaved = false;

  // Heatmap data
  StadiumHeatmapData? _heatmapData;
  Timer? _heatmapTimer;

  // Ticket data (temporariamente desativado)
  // TicketModel? _userTicket;
  // final TicketStorageService _ticketStorage = TicketStorageService();

  // Stream para pedir ao plugin para centrar no GPS (parâmetro do CurrentLocationLayer)
  final StreamController<double?> _alignPositionStreamController =
      StreamController<double?>.broadcast();
  bool _isLocationLayerAvailable = false;
  bool _isUserPositionLocked = false;

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
    _userPositionX = 0.0;
    _userPositionY = 0.0;
    _userLevel = 0;

    // Initialize blink animation for emergency mode
    _blinkController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..repeat(reverse: true);

    // Initialize blink animation for emergency mode

    _checkLocationLayerAvailability();
    loadUserPosition(); // Carregar posição guardada
    _loadMapData();
  }

  Future<void> _checkLocationLayerAvailability() async {
    try {
      await Geolocator.checkPermission();
      if (mounted) {
        setState(() {
          _isLocationLayerAvailable = true;
        });
      }
    } on MissingPluginException catch (e) {
      print('[StadiumMapPage] Geolocator plugin unavailable: $e');
      if (mounted) {
        setState(() {
          _isLocationLayerAvailable = false;
          _isUserPositionLocked = false;
        });
      }
    } catch (_) {
      // Plugin exists but permission/service may still fail later; keep layer enabled.
      if (mounted) {
        setState(() {
          _isLocationLayerAvailable = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _alignPositionStreamController.close();
    _blinkController.dispose();
    _stopHeatmapUpdates();
    super.dispose();
  }

  /// Carrega a posição guardada do utilizador
  Future<void> loadUserPosition({bool updateFloor = true}) async {
    final position = await UserPositionService.getPosition();
    if (position == null) {
      if (mounted) {
        setState(() {
          _userPositionX = 0.0;
          _userPositionY = 0.0;
          _userLevel = _currentFloor;
        });
      }
      return;
    }

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
          "[StadiumMapPage] Invalid position detected (${x}, ${y}). Resetting to center.",
        );
        x = stadiumCenter.longitude;
        y = stadiumCenter.latitude;
      }

      print(
        "[StadiumMapPage] Loading user position from service: $x, $y (Level ${position.level})",
      );
      setState(() {
        _userPositionX = x;
        _userPositionY = y;
        _userLevel = position.level; // Guardar nível real

        // Só atualizar _currentFloor a partir da posição guardada se solicitado E não estivermos em navegação
        if (updateFloor && !widget.isNavigating) {
          if (_currentFloor != position.level) {
            _currentFloor = position.level;
            widget.onFloorChanged?.call(_currentFloor);
            _loadMapData();
          }
        }
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
    print("Reloading map data requested...");
    _loadMapData();
  }

  Iterable<Marker> _buildTicketMarkers() sync* {
    /*
    print(
      "Building ticket markers. Ticket: $_userTicket, SeatNodeId: ${_userTicket?.seatNodeId}",
    );
    if (_userTicket == null || _userTicket!.seatNodeId == null) return;

    try {
      print("Searching for seat node: ${_userTicket!.seatNodeId}");
      final seatNode = _nodes.firstWhere(
        (n) => n.id == _userTicket!.seatNodeId,
      );
      print(
        "Seat node found: ${seatNode.id} at level ${seatNode.level} (Current floor: $_currentFloor)",
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
      print("Error building ticket marker: $e");
      // Ignore
    }
    */
    // Ticket markers disabled on purpose.
    return;
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
      // Ticket feature disabled:
      // final ticket = await _ticketStorage.getTicket();
      // print(
      //   "Loaded ticket from storage: ${ticket?.id} - Seat: ${ticket?.seatNodeId}",
      // );

      if (!mounted) return;
      if (_currentFloor != floorToLoad) {
        return;
      }

      /*
      // Ticket feature disabled:
      // Se temos bilhete, carregar o nó do lugar especificamente (pois getAllNodes filtra seats)
      if (ticket != null && ticket.seatNodeId != null) {
        try {
          print("Fetching specific seat node: ${ticket.seatNodeId}");
          final seatNode = await _mapService.getSeatById(ticket.seatNodeId!);
          if (seatNode != null) {
            print("Seat node fetched: ${seatNode.id}");
            // Adicionar à lista de nós se ainda não existir
            if (!nodes.any((n) => n.id == seatNode.id)) {
              nodes.add(seatNode);
            }
          } else {
            print("Seat node not found in backend: ${ticket.seatNodeId}");
          }
        } catch (e) {
          print("Error fetching seat node: $e");
        }
      }
      */

      setState(() {
        _pois = pois;
        _nodes = nodes;
        _edges = edges;
        _tiles = tiles;
        // _savedPlaces = savedPlaces; // Removed favorites
        // _userTicket = ticket; // Ticket feature disabled
        _isLoading = false;
      });

      // Centrar na posição GPS real via plugin (sempre, não só fora de navegação)
      _zoomToUserPosition();
      // Se pedirmos para focar nos POIs customizados
      if (widget.customPOIsToShow != null &&
          widget.zoomOutToPOIs &&
          widget.customPOIsToShow!.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            try {
              final coordinates = widget.customPOIsToShow!
                  .map((poi) => _convertToLatLng(poi.x, poi.y))
                  .toList();

              _mapController.fitCamera(
                CameraFit.coordinates(
                  coordinates: coordinates,
                  padding: const EdgeInsets.all(50.0),
                ),
              );
            } catch (e) {
              print('Error fitting camera to POIs: $e');
            }
          }
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

  /// Faz zoom na posição atual do utilizador
  void _zoomToUserPosition() {
    if (!_isLocationLayerAvailable) {
      if (mounted && _isUserPositionLocked) {
        setState(() {
          _isUserPositionLocked = false;
        });
      }
      return;
    }

    if (mounted && !_isUserPositionLocked) {
      setState(() {
        _isUserPositionLocked = true;
      });
    }

    // Pede ao plugin para centrar na posição GPS real com zoom 18
    _alignPositionStreamController.add(18);
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

  /// Método público para abrir o mesmo fluxo de detalhes/rota do clique no POI
  void openPOIDetails(POIModel poi) {
    _showPOIDetails(poi);
  }

  /// Mostra detalhes do POI como painel in-stack (sem bloquear o mapa)
  void _showPOIDetails(POIModel poi) async {
    // Show panel immediately with loading state
    setState(() {
      _selectedPOI = poi;
      _previewRoute = null;
      _isCalculatingPreviewRoute = true;
      _currentRoute = null;
      _isSelectedPOISaved = false;
    });
    widget.onPOIPanelChanged?.call(true);

    final isSaved = await SavedPlacesService.isSaved(poi.id);
    if (mounted && _selectedPOI?.id == poi.id) {
      setState(() {
        _isSelectedPOISaved = isSaved;
      });
    }

    RouteModel? route;
    double startX = 0;
    double startY = 0;
    int startLevel = 0;

    try {
      final currentPos = await GeographicUtils.getCurrentUserPosition();

      if (currentPos == null) {
        if (mounted) {
          AppTopFeedback.showWarning(
            context,
            AppLocalizations.of(context)!.gpsRequiredMessage,
          );
        }
        // Não faz return nem fecha o painel - apenas deixa a rota a null para mostrar só os detalhes
      } else {
        startX = currentPos.x;
        startY = currentPos.y;
        startLevel = currentPos.level;

        route = await _routingService.getRouteToPOI(
          startX: startX,
          startY: startY,
          startLevel: startLevel,
          poiId: poi.id,
          avoidStairs: widget.avoidStairs,
        );
      }
    } catch (e) {}

    if (!mounted) return;

    setState(() {
      _previewRoute = route;
      _currentRoute = route;
      _isCalculatingPreviewRoute = false;
    });

    // Zoom to fit user and destination
    if (route != null) {
      try {
        // Use the exact start location that the route actually used
        final userLatLng = _convertToLatLng(startX, startY);
        final poiLatLng = _convertToLatLng(poi.x, poi.y);

        // Add all points from the route to ensure it's fully visible
        final allPoints = <LatLng>[userLatLng, poiLatLng];
        for (final wp in route.waypoints) {
          allPoints.add(_convertToLatLng(wp.x, wp.y));
        }

        final bounds = LatLngBounds.fromPoints(allPoints);
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.fromLTRB(
              40,
              40,
              40,
              240,
            ), // Reduce excessive bottom/top padding
            maxZoom: 19.0, // Keep highest zoom high enough
          ),
        );
      } catch (e) {}
    } else {
      _mapController.move(_convertToLatLng(poi.x, poi.y), 19.5);
    }
  }

  /// Fecha o painel de preview do POI
  void _closePOIPanel() {
    setState(() {
      _selectedPOI = null;
      _previewRoute = null;
      _currentRoute = null;
      _isCalculatingPreviewRoute = false;
      _isSelectedPOISaved = false;
    });
    widget.onPOIPanelChanged?.call(false);
  }

  Future<void> _toggleSelectedPOIFavorite() async {
    final poi = _selectedPOI;
    if (poi == null) return;

    if (_isSelectedPOISaved) {
      await SavedPlacesService.removePlace(poi.id);
    } else {
      await SavedPlacesService.savePlace(poi);
    }

    if (!mounted || _selectedPOI?.id != poi.id) return;
    setState(() {
      _isSelectedPOISaved = !_isSelectedPOISaved;
    });
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    Color backgroundColor = const Color(0x22FFFFFF),
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompassButton() {
    return Transform.scale(
      scale: 0.8,
      child: const MapCompass.cupertino(
        hideIfRotatedNorth: false,
        alignment: Alignment.center,
        padding: EdgeInsets.zero,
      ),
    );
  }

  void _handleRecenterButtonPressed() {
    if (!_isLocationLayerAvailable) {
      AppTopFeedback.showWarning(
        context,
        AppLocalizations.of(context)!.gpsRequiredMessage,
      );
      return;
    }

    _zoomToUserPosition();
  }

  Widget _buildRecenterButton() {
    final bool isActive = _isLocationLayerAvailable && _isUserPositionLocked;
    final Color iconColor = isActive
        ? Colors.blue
        : (_isLocationLayerAvailable
              ? const Color(0xFF6B7280)
              : const Color(0xFF9CA3AF));
    final IconData icon = isActive
        ? Icons.my_location
        : Icons.my_location_outlined;

    return InkWell(
      borderRadius: BorderRadius.circular(23),
      onTap: _handleRecenterButtonPressed,
      child: SizedBox(
        width: 50,
        height: 50,
        child: Center(child: Icon(icon, color: iconColor, size: 24)),
      ),
    );
  }

  Widget _buildMapControlsCard() {
    return Material(
      color: Colors.white,
      elevation: 8,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        width: 50,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 50,
              height: 50,
              child: Center(child: _buildCompassButton()),
            ),
            Container(width: 35, height: 2, color: Colors.black12),
            _buildRecenterButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationControlButton({
    IconData? icon,
    Color iconColor = const Color(0xFF6B7280),
    VoidCallback? onTap,
    Widget? child,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(23),
      onTap: onTap,
      child: SizedBox(
        width: 50,
        height: 50,
        child: Center(child: child ?? Icon(icon, color: iconColor, size: 24)),
      ),
    );
  }

  Widget _buildNavigationControlsCard() {
    return Material(
      color: Colors.white,
      elevation: 8,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        width: 50,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 50,
              height: 50,
              child: Center(child: _buildCompassButton()),
            ),
            Container(width: 35, height: 2, color: Colors.black12),
            _buildNavigationControlButton(
              icon: Icons.local_fire_department_rounded,
              iconColor: widget.showHeatmap
                  ? Colors.deepOrange
                  : const Color(0xFF6B7280),
              onTap: widget.onToggleNavigationHeatmap,
            ),
            Container(width: 35, height: 2, color: Colors.black12),
            _buildNavigationControlButton(
              icon: widget.isFollowingUser
                  ? Icons.my_location
                  : Icons.my_location_outlined,
              iconColor: widget.isFollowingUser
                  ? Colors.blue
                  : const Color(0xFF6B7280),
              onTap: widget.onRecenterNavigation,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencySimulationButton() {
    return Material(
      color: Colors.redAccent,
      elevation: 8,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () async {
          await UserPositionService.clearPosition();
          await loadUserPosition();
          _zoomToUserPosition();

          if (mounted) {
            Navigator.of(
              context,
            ).pushNamedAndRemoveUntil('/emergency-alert', (route) => false);
          }
        },
        child: const SizedBox(
          width: _emergencyButtonSize,
          height: _emergencyButtonSize,
          child: Icon(Icons.warning_amber_rounded, color: Colors.white),
        ),
      ),
    );
  }

  /// Constrói o painel inline de detalhes do POI
  Widget _buildPOIPreviewPanel() {
    final poi = _selectedPOI!;
    final route = _previewRoute;
    final isLoading = _isCalculatingPreviewRoute;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Dismissible(
        key: Key('poi_preview_${poi.id}'),
        direction: DismissDirection.down,
        onDismissed: (_) => _closePOIPanel(),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1E1E3F),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Swipe indicator pill
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Header: icon + name + actions (favorite)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Icon(Icons.place, color: Colors.white70, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          poi.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Gabarito',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: _isSelectedPOISaved
                            ? AppLocalizations.of(context)!.removeFromFavorites
                            : AppLocalizations.of(context)!.addToFavorites,
                        onPressed: _toggleSelectedPOIFavorite,
                        icon: Icon(
                          _isSelectedPOISaved ? Icons.star : Icons.star_border,
                          color: _isSelectedPOISaved
                              ? Colors.amberAccent
                              : Colors.white70,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Route metrics
                  if (isLoading)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white54,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            AppLocalizations.of(context)!.calculatingRoute,
                            style: const TextStyle(color: Colors.white54),
                          ),
                        ],
                      ),
                    )
                  else if (route != null)
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _buildInfoChip(
                          icon: Icons.directions_walk,
                          label: AppLocalizations.of(
                            context,
                          )!.walkTime((route.etaSeconds / 60).round()),
                        ),
                        _buildInfoChip(
                          icon: Icons.straighten,
                          label: AppLocalizations.of(
                            context,
                          )!.distanceM(route.distance.round()),
                        ),
                        if ([
                              'wc',
                              'food',
                              'ticket',
                              'store',
                              'bar',
                              'bar_p',
                            ].contains(_selectedPOI!.category) ||
                            _selectedPOI!.name.toLowerCase().contains(
                              'farmácia',
                            ))
                          _buildInfoChip(
                            icon: Icons.group,
                            label: AppLocalizations.of(
                              context,
                            )!.queueTime(route.waitTime?.round() ?? 0),
                          ),
                      ],
                    ),
                  const SizedBox(height: 20),

                  // Navigate button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isCalculatingPreviewRoute
                          ? null
                          : () {
                              if (route == null) {
                                AppTopFeedback.showWarning(
                                  context,
                                  AppLocalizations.of(
                                    context,
                                  )!.gpsRequiredMessage,
                                );
                                return;
                              }

                              _closePOIPanel();
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => NavigationPage(
                                    route: route,
                                    destination: poi,
                                    nodes: _nodes,
                                    initialX: _userPositionX,
                                    initialY: _userPositionY,
                                    initialLevel: _userLevel,
                                  ),
                                ),
                              ).then((_) => loadUserPosition());
                            },
                      icon: const Icon(Icons.navigation, color: Colors.white),
                      label: Text(
                        AppLocalizations.of(context)!.navigate,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        disabledBackgroundColor: Colors
                            .grey[700], // Fundo cinzento quando indisponível
                        disabledForegroundColor:
                            Colors.white70, // Texto mais fraco
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(50),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: _controlsCardRightInset,
              top: -(_controlsCardHeight + _controlsCardGapAbovePanel),
              child: _buildMapControlsCard(),
            ),
            Positioned(
              right: _controlsCardRightInset,
              top: -_controlsCardGapAbovePanel + _emergencyButtonGap,
              child: _buildEmergencySimulationButton(),
            ),
          ],
        ),
      ),
    );
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
        initialCenter: widget.isNavigating && widget.userPosition != null
            ? widget.userPosition!
            : stadiumCenter,
        initialZoom: widget.isNavigating ? 19.0 : 17.0,
        minZoom: 14.0,
        maxZoom: 19.0,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
        ),
        onPositionChanged: (camera, hasGesture) {
          if (hasGesture && _isUserPositionLocked) {
            setState(() {
              _isUserPositionLocked = false;
            });
          }
          widget.onPositionChanged?.call(camera, hasGesture);
        },
        onTap: (_, __) {
          if (_selectedPOI != null && !widget.isNavigating) {
            _closePOIPanel();
          }
        },
      ),
      children: [
        // Base layer: OSM tiles (outdoor) ou fundo vazio (indoor)
        if (MapConfig.useOSMTiles && !widget.simplifiedMode)
          TileLayer(
            tileProvider: CachedTileProvider(),
            urlTemplate:
                'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
            subdomains: const ['a', 'b', 'c', 'd'],
            userAgentPackageName: 'com.dragao.fanapp',
            retinaMode: RetinaMode.isHighDensity(context),
            maxNativeZoom: 19,
          ),

        // Remove a atribuição padrão do flutter_map
        RichAttributionWidget(
          attributions: [
            TextSourceAttribution(
              '© OpenStreetMap contributors © CARTO',
              onTap: () {},
            ),
          ],
        ),

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

        // Camada de rota (polyline) — ocultar quando há rota alternativa em preview
        if (_currentRoute != null && widget.previewRoute == null)
          _buildRouteLayer(),

        // Preview da nova rota (quando a selecionar um POI durante navegação) — verde
        if (widget.previewRoute != null) _buildPreviewRouteLayer(),

        // Camada de POIs (markers)
        _buildPOILayer(),

        // Posição do utilizador (plugin gere GPS e permissões sozinho)
        if (_isLocationLayerAvailable)
          CurrentLocationLayer(
            alignPositionStream: _alignPositionStreamController.stream,
            alignPositionOnUpdate: widget.isNavigating && widget.isFollowingUser
                ? AlignOnUpdate.always
                : AlignOnUpdate.never,
            alignDirectionOnUpdate:
                widget.isNavigating && widget.isFollowingUser
                ? AlignOnUpdate.always
                : AlignOnUpdate.never,
            indicators: const LocationMarkerIndicators(
              serviceDisabled: SizedBox.shrink(),
              permissionRequesting: SizedBox.shrink(),
              permissionDenied: SizedBox.shrink(),
            ),
          ),

        // Card de controlos (compass + reposicionar) sem painel POI
        if (!widget.isNavigating &&
            !_isLoading &&
            _errorMessage == null &&
            widget.interactivePOIs &&
            _selectedPOI == null)
          Positioned(
            right: _controlsCardRightInset,
            bottom: _controlsCardBottomInset,
            child: _buildMapControlsCard(),
          ),

        if (!widget.isNavigating &&
            !_isLoading &&
            _errorMessage == null &&
            widget.interactivePOIs &&
            _selectedPOI == null)
          Positioned(
            right: _controlsCardRightInset,
            bottom:
                _controlsCardBottomInset -
                _emergencyButtonSize -
                _emergencyButtonGap,
            child: _buildEmergencySimulationButton(),
          ),

        if (widget.isNavigating && !_isLoading && _errorMessage == null)
          Positioned(
            right: _controlsCardRightInset,
            bottom:
                widget.navigationControlsBottomInset ??
                _controlsCardBottomInset,
            child: _buildNavigationControlsCard(),
          ),

        // Inline POI preview panel (non-modal, allows map interaction)
        if (_selectedPOI != null && !widget.isNavigating)
          _buildPOIPreviewPanel(),
      ],
    );
  }

  /// Camada de heatmap usando o plugin flutter_map_heatmap
  Widget _buildHeatmapLayer() {
    if (_heatmapData == null || _heatmapData!.sections.isEmpty) {
      return const SizedBox.shrink();
    }

    final data = <WeightedLatLng>[];

    _heatmapData!.sections.forEach((cellId, cellData) {
      // Filtrar pelo piso atual
      if (cellData.level != _currentFloor) return;

      // Extrair coordenadas do cellId (cell_X_Y ou cell_L_X_Y)
      final parts = cellId.split('_');
      double? x, y;

      if (parts.length == 3 && parts[0] == 'cell') {
        x = double.tryParse(parts[1]);
        y = double.tryParse(parts[2]);
      } else if (parts.length == 4 && parts[0] == 'cell') {
        x = double.tryParse(parts[2]);
        y = double.tryParse(parts[3]);
      } else {
        return;
      }

      if (x == null || y == null) return;

      // Ponto com peso = nível de congestão
      data.add(
        WeightedLatLng(
          LatLng(y.toDouble(), x.toDouble()),
          cellData.congestionLevel,
        ),
      );
    });

    if (data.isEmpty) return const SizedBox.shrink();

    return HeatMapLayer(
      heatMapDataSource: InMemoryHeatMapDataSource(data: data),
      heatMapOptions: HeatMapOptions(radius: 30, minOpacity: 0.1),
    );
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
              strokeWidth: 7.0,
              color: widget.isEmergency
                  ? Color.lerp(
                      const Color(0xFFE53935),
                      const Color(0xFFFF7043),
                      opacity,
                    )!
                  : const Color(0xFF4285F4),
              borderColor: widget.isEmergency
                  ? const Color(0xFF8B1A1A)
                  : const Color(0xFF1A56DB),
              borderStrokeWidth: 2.0,
            );
          }).toList(),
        );
      },
    );
  }

  /// Renders the candidate new route (green) when user selects a POI mid-navigation
  Widget _buildPreviewRouteLayer() {
    final route = widget.previewRoute!;
    final nodesMap = {for (var n in _nodes) n.id: n};
    final points = <LatLng>[];

    for (final wp in route.waypoints) {
      final node = nodesMap[wp.nodeId];
      if (node != null) {
        points.add(_convertToLatLng(node.x, node.y));
      } else {
        points.add(_convertToLatLng(wp.x, wp.y));
      }
    }

    if (points.isEmpty) return const SizedBox.shrink();

    return PolylineLayer(
      polylines: [
        Polyline(
          points: points,
          strokeWidth: 6.0,
          color: const Color(0xFF22C55E),
          borderColor: const Color(0xFF166534),
          borderStrokeWidth: 1.5,
        ),
      ],
    );
  }

  Widget _buildPOILayer() {
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

    if (widget.customPOIsToShow != null) {
      // Isolates specific POIs if given (like emergency exits)
      poisToShow.addAll(widget.customPOIsToShow!);
    } else {
      // 1. Mostrar POIs genéricos se o zoom permitir ou "Show All" estiver ativo
      // MAS apenas se showOtherPOIs for true
      if (widget.showOtherPOIs && (showGenericPOIs || widget.showAllPOIs)) {
        poisToShow.addAll(_pois);
      }
    }

    // 2. Garantir que o POI destacado (Destino ou Seleção) é SEMPRE visível em modo Preview
    // Em modo Navegação, respeita o piso.
    if (widget.highlightedPOI != null) {
      // Se NÃO estamos navegando (Preview), mostramos sempre.
      // Se ESTAMOS navegando, só mostramos se for do piso atual.
      bool show =
          !widget.isNavigating || widget.highlightedPOI!.level == _currentFloor;

      if (show) {
        // Always replace any same-id POI with highlightedPOI instance.
        // This keeps marker coordinates stable across zoom-level filtering
        // (generic list may carry slightly different coordinates).
        poisToShow.removeWhere((p) => p.id == widget.highlightedPOI!.id);
        poisToShow.add(widget.highlightedPOI!);
      }
    }

    final poiMarkers = poisToShow.map<Marker>((POIModel poi) {
      final position = _convertToLatLng(poi.x, poi.y);
      final isHighlighted = widget.highlightedPOI?.id == poi.id;

      return Marker(
        point: position,
        width: isHighlighted ? 60 : 50,
        height: isHighlighted ? 60 : 50,
        alignment: Alignment.center,
        child: GestureDetector(
          onTap: !widget.interactivePOIs
              ? null // Allow no interaction if set to false
              : widget.isNavigating
              ? (widget.onTapPOI != null ? () => widget.onTapPOI!(poi) : null)
              : () => _showPOIDetails(poi),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(isHighlighted ? 10 : 8),
                decoration: BoxDecoration(
                  color: POIStyle.getColor(poi.category, name: poi.name),
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
                  POIStyle.getIcon(poi.category, name: poi.name),
                  color: Colors.white,
                  size: isHighlighted ? 24 : 20,
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();

    return Stack(
      children: [
        // POIs: sempre verticais, alinhados ao ecrã (rotate: true)
        MarkerLayer(
          rotate: true,
          markers: [..._buildTicketMarkers(), ...poiMarkers],
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
}
