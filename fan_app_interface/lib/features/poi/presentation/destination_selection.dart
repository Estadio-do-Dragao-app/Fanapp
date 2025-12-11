import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math';
import '../../map/presentation/stadium_map_page.dart';
import '../../map/data/models/poi_model.dart';
import '../../map/data/models/node_model.dart';
import '../../map/data/models/route_model.dart';
import '../../map/data/services/map_service.dart';
import '../../map/data/services/routing_service.dart';
import '../../navigation/presentation/navigation_page.dart';
import 'package:fan_app_interface/l10n/app_localizations.dart';

/// POI com rota calculada
class POIWithRoute {
  final POIModel poi;
  RouteModel? route;
  final double estimatedDistance; // Distância euclidiana (fallback)

  POIWithRoute({
    required this.poi,
    this.route,
    required this.estimatedDistance,
  });

  /// Tempo de caminhada em minutos
  int get walkingMinutes {
    if (route != null) {
      return (route!.etaSeconds / 60).round();
    }
    // Fallback: estimar baseado em distância euclidiana
    return ((estimatedDistance * 1.5) / 1.4 / 60).round().clamp(1, 99);
  }

  /// Tempo de espera na fila em minutos (0 se não disponível)
  int get waitMinutes {
    if (route != null && route!.waitTime != null) {
      return route!.waitTime!.round();
    }
    return 0;
  }

  /// Tempo TOTAL = caminhada + espera (usado para determinar "mais rápido")
  int get totalEtaMinutes => walkingMinutes + waitMinutes;

  /// Distância real se rota calculada, senão estimativa
  double get distance => route?.distance ?? estimatedDistance;

  bool get hasRoute => route != null;
}

class DestinationSelectionPage extends StatefulWidget {
  final String categoryId;
  final String? preselectedSeatInfo;

  const DestinationSelectionPage({
    Key? key,
    required this.categoryId,
    this.preselectedSeatInfo,
  }) : super(key: key);

  @override
  State<DestinationSelectionPage> createState() =>
      _DestinationSelectionPageState();
}

class _DestinationSelectionPageState extends State<DestinationSelectionPage> {
  final MapService _mapService = MapService();
  final RoutingService _routingService = RoutingService();
  final MapController _mapController = MapController();

  static const String userNodeId = 'N1';

  int? selectedIndex;
  List<POIWithRoute> _poisWithRoutes = [];
  List<NodeModel> _allNodes = [];
  NodeModel? _userNode;
  bool _isLoading = true;
  String? _errorMessage;

  // Estado do cálculo de rotas em background
  bool _isCalculatingAllRoutes = false;
  bool _allRoutesCalculated = false;
  int?
  _fastestIndex; // Índice do POI mais rápido (após calcular todas as rotas)

  // Rota selecionada
  RouteModel? _selectedRoute;
  bool _isCalculatingSelectedRoute = false;

  @override
  void initState() {
    super.initState();
    _loadPOIs();
  }

  String _normalizeCategory(String backendCategory) {
    final category = backendCategory.toLowerCase();
    switch (category) {
      case 'bar':
      case 'restaurant':
        return 'food';
      case 'restroom':
      case 'toilet':
      case 'wc':
        return 'wc';
      case 'emergency_exit':
        return 'exit';
      case 'merchandise':
        return 'merchandising';
      case 'first_aid':
      case 'firstaid':
      case 'first-aid':
        return 'first_aid';
      case 'information':
      case 'info':
        return 'information';
      default:
        return category;
    }
  }

  double _euclideanDistance(double x1, double y1, double x2, double y2) {
    return sqrt(pow(x2 - x1, 2) + pow(y2 - y1, 2));
  }

  /// Carrega POIs e inicia cálculo de rotas em background
  Future<void> _loadPOIs() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _allRoutesCalculated = false;
      _fastestIndex = null;
    });

    try {
      final allPois = await _mapService.getAllPOIs();
      final allNodes = await _mapService.getAllNodes();

      _allNodes = allNodes;
      _userNode = allNodes.firstWhere(
        (n) => n.id == userNodeId,
        orElse: () => allNodes.first,
      );

      // Filtrar POIs da categoria
      final categoryPois = allPois.where((poi) {
        return _normalizeCategory(poi.category) ==
            widget.categoryId.toLowerCase();
      }).toList();

      // Criar lista com distâncias estimadas
      List<POIWithRoute> poisWithRoutes = categoryPois.map((poi) {
        final distance = _euclideanDistance(
          _userNode!.x,
          _userNode!.y,
          poi.x,
          poi.y,
        );
        return POIWithRoute(poi: poi, estimatedDistance: distance);
      }).toList();

      // Ordenar por distância euclidiana (aproximação inicial)
      poisWithRoutes.sort(
        (a, b) => a.estimatedDistance.compareTo(b.estimatedDistance),
      );

      setState(() {
        _poisWithRoutes = poisWithRoutes;
        _isLoading = false;
        if (_poisWithRoutes.isNotEmpty) {
          selectedIndex = 0;
          _selectedRoute = null;
        }
      });

      // Iniciar cálculo de TODAS as rotas em paralelo (background)
      _calculateAllRoutesInBackground();

      // Calcular rota do primeiro selecionado imediatamente
      if (_poisWithRoutes.isNotEmpty) {
        _calculateRouteForSelected(0);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  /// Calcula todas as rotas em paralelo no background
  Future<void> _calculateAllRoutesInBackground() async {
    if (_poisWithRoutes.isEmpty || _userNode == null) return;

    setState(() {
      _isCalculatingAllRoutes = true;
    });

    try {
      // Calcular todas as rotas em paralelo
      final futures = _poisWithRoutes.map((item) async {
        try {
          final route = await _routingService.getRouteToCoordinates(
            startX: _userNode!.x,
            startY: _userNode!.y,
            startLevel: _userNode!.level,
            endX: item.poi.x,
            endY: item.poi.y,
            endLevel: item.poi.level,
            allNodes: _allNodes,
          );
          item.route = route;
        } catch (e) {
          print(
            '[DestinationSelection] Erro ao calcular rota para ${item.poi.name}: $e',
          );
          // Manter route como null - usará estimativa
        }
      }).toList();

      await Future.wait(futures);

      if (mounted) {
        // Encontrar o mais rápido (menor ETA)
        int? fastestIdx;
        int? fastestTime;

        for (int i = 0; i < _poisWithRoutes.length; i++) {
          final eta = _poisWithRoutes[i].totalEtaMinutes;
          if (fastestTime == null || eta < fastestTime) {
            fastestTime = eta;
            fastestIdx = i;
          }
        }

        setState(() {
          _isCalculatingAllRoutes = false;
          _allRoutesCalculated = true;
          _fastestIndex = fastestIdx;

          // Atualizar rota selecionada se já temos
          if (selectedIndex != null &&
              _poisWithRoutes[selectedIndex!].hasRoute) {
            _selectedRoute = _poisWithRoutes[selectedIndex!].route;
          }
        });
      }
    } catch (e) {
      print('[DestinationSelection] Erro no cálculo em background: $e');
      if (mounted) {
        setState(() {
          _isCalculatingAllRoutes = false;
        });
      }
    }
  }

  /// Calcula rota para o POI selecionado (se ainda não calculada)
  Future<void> _calculateRouteForSelected(int index) async {
    final item = _poisWithRoutes[index];

    // Se já tem rota, usa diretamente
    if (item.hasRoute) {
      setState(() {
        _selectedRoute = item.route;
      });
      _zoomToRoute(item.route!);
      return;
    }

    setState(() {
      _isCalculatingSelectedRoute = true;
    });

    try {
      final route = await _routingService.getRouteToCoordinates(
        startX: _userNode!.x,
        startY: _userNode!.y,
        startLevel: _userNode!.level,
        endX: item.poi.x,
        endY: item.poi.y,
        endLevel: item.poi.level,
        allNodes: _allNodes,
      );

      item.route = route;

      if (mounted && selectedIndex == index) {
        setState(() {
          _selectedRoute = route;
          _isCalculatingSelectedRoute = false;
        });
        _zoomToRoute(route);
      }
    } catch (e) {
      print('[DestinationSelection] Erro ao calcular rota: $e');
      if (mounted) {
        setState(() {
          _isCalculatingSelectedRoute = false;
        });
      }
    }
  }

  /// Converte coordenadas do backend para LatLng (mesmo método do StadiumMapPage)
  LatLng _convertToLatLng(double x, double y) {
    const backendCenterX = 499.0;
    const backendCenterY = 400.0;
    const stadiumCenterLat = 41.161758;
    const stadiumCenterLng = -8.583933;
    const unitsToLatDegrees = 0.000004;
    const unitsToLngDegrees = 0.000005;

    final centeredX = x - backendCenterX;
    final centeredY = y - backendCenterY;

    return LatLng(
      stadiumCenterLat + (centeredY * unitsToLatDegrees),
      stadiumCenterLng + (centeredX * unitsToLngDegrees),
    );
  }

  /// Faz zoom para mostrar o início e fim da rota
  void _zoomToRoute(RouteModel route) {
    if (route.path.isEmpty || _userNode == null) return;

    // Obter posição do utilizador e do destino
    final startLatLng = _convertToLatLng(_userNode!.x, _userNode!.y);
    final endLatLng = _convertToLatLng(route.path.last.x, route.path.last.y);

    // Calcular bounds para incluir início e fim
    final minLat = min(startLatLng.latitude, endLatLng.latitude);
    final maxLat = max(startLatLng.latitude, endLatLng.latitude);
    final minLng = min(startLatLng.longitude, endLatLng.longitude);
    final maxLng = max(startLatLng.longitude, endLatLng.longitude);

    // Adicionar padding (30% de margem)
    final latPadding = (maxLat - minLat) * 0.3;
    final lngPadding = (maxLng - minLng) * 0.3;

    // Fazer zoom para mostrar início e fim
    try {
      final centerLat = (minLat + maxLat) / 2;
      final centerLng = (minLng + maxLng) / 2;

      // Calcular zoom level baseado na distância
      final latDiff = maxLat - minLat + 2 * latPadding;
      final lngDiff = maxLng - minLng + 2 * lngPadding;
      final maxDiff = max(latDiff, lngDiff);

      // Zoom: maior diferença = menor zoom
      double zoom = 18.0;
      if (maxDiff > 0.001) zoom = 17.0;
      if (maxDiff > 0.002) zoom = 16.5;
      if (maxDiff > 0.003) zoom = 16.0;

      _mapController.move(LatLng(centerLat, centerLng), zoom);
    } catch (e) {
      print('[DestinationSelection] Erro ao fazer zoom: $e');
    }
  }

  static IconData getCategoryIcon(String categoryId) {
    switch (categoryId.toLowerCase()) {
      case 'seat':
        return Icons.event_seat;
      case 'wc':
        return Icons.wc;
      case 'food':
        return Icons.fastfood;
      case 'bar':
        return Icons.local_bar;
      case 'exit':
        return Icons.meeting_room;
      case 'first_aid':
        return Icons.local_hospital;
      case 'information':
        return Icons.info;
      case 'merchandising':
        return Icons.store;
      default:
        return Icons.place;
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    final selectedPOI =
        (selectedIndex != null && selectedIndex! < _poisWithRoutes.length)
        ? _poisWithRoutes[selectedIndex!].poi
        : null;

    return Scaffold(
      backgroundColor: const Color(0xFF161A3E),
      body: Stack(
        children: [
          // Mapa com zoom na rota
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.4,
            child: Stack(
              children: [
                StadiumMapPage(
                  mapController: _mapController,
                  highlightedRoute: _selectedRoute,
                  highlightedPOI: selectedPOI,
                  showAllPOIs: false,
                ),
                if (_isCalculatingSelectedRoute)
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'A calcular rota...',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Botão voltar
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF161A3E),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          // Lista de POIs
          Positioned(
            top: MediaQuery.of(context).size.height * 0.38,
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF161A3E),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          localizations.chooseLocation,
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'Gabarito',
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_isCalculatingAllRoutes)
                          const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white54,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white24, thickness: 1),
                  Expanded(child: _buildContent()),
                ],
              ),
            ),
          ),

          // Botão confirmar
          if (!_isLoading && _errorMessage == null)
            Positioned(
              bottom: 24,
              left: 24,
              right: 24,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      (selectedIndex != null && _selectedRoute != null)
                      ? Colors.indigo[200]
                      : Colors.grey[600],
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: (selectedIndex != null && _selectedRoute != null)
                    ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => NavigationPage(
                              route: _selectedRoute!,
                              destination: _poisWithRoutes[selectedIndex!].poi,
                              nodes: _allNodes,
                            ),
                          ),
                        );
                      }
                    : null,
                child: Text(
                  localizations.chooseLocationButton,
                  style: const TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final localizations = AppLocalizations.of(context)!;

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(_errorMessage!, style: const TextStyle(color: Colors.white70)),
            ElevatedButton.icon(
              onPressed: _loadPOIs,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
    }

    if (_poisWithRoutes.isEmpty) {
      return Center(
        child: Text(
          localizations.tapToSelect,
          style: const TextStyle(color: Colors.white),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: _poisWithRoutes.length,
      itemBuilder: (context, index) {
        final item = _poisWithRoutes[index];
        final isSelected = selectedIndex == index;
        final isFastest = _allRoutesCalculated && _fastestIndex == index;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () {
              setState(() {
                selectedIndex = index;
                _selectedRoute = item.route;
              });
              if (item.hasRoute) {
                // Já tem rota - fazer zoom imediatamente
                _zoomToRoute(item.route!);
              } else {
                // Calcular rota (zoom será feito após cálculo)
                _calculateRouteForSelected(index);
              }
            },
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF161A3E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? Colors.white
                      : (isFastest ? Colors.green : Colors.white24),
                  width: isSelected ? 3 : (isFastest ? 2 : 1),
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    getCategoryIcon(widget.categoryId),
                    color: Colors.white,
                    size: 32,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.poi.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Gabarito',
                          ),
                        ),
                        Row(
                          children: [
                            // Tempo de caminhada
                            const Icon(
                              Icons.directions_walk,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              item.hasRoute
                                  ? '${item.walkingMinutes} min'
                                  : '~${item.walkingMinutes} min',
                              style: TextStyle(
                                color: item.hasRoute
                                    ? Colors.white
                                    : Colors.white70,
                              ),
                            ),
                            // Tempo de espera (se existir)
                            if (item.waitMinutes > 0) ...[
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.hourglass_bottom,
                                color: Colors.orange,
                                size: 16,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '+${item.waitMinutes} min',
                                style: const TextStyle(color: Colors.orange),
                              ),
                            ],
                            // Badge "Mais rápido"
                            if (isFastest)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  localizations.faster,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${item.distance.toStringAsFixed(0)}m',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
