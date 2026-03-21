import 'package:flutter/material.dart';
import 'package:flutter_map_animations/flutter_map_animations.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math';
import '../../map/presentation/stadium_map_page.dart';
import '../../map/data/models/poi_model.dart';
import '../../map/data/models/node_model.dart';
import '../../map/data/models/route_model.dart';
import '../../map/data/services/map_service.dart';
import '../../map/data/services/routing_service.dart';
import '../../navigation/presentation/navigation_page.dart';

import '../../../core/utils/geographic_utils.dart';
import '../../../core/utils/top_feedback.dart';
import '../../../core/widgets/poi_icon.dart';
import '../../../core/widgets/animated_glow.dart';
import '../../map/data/services/waittime_cache.dart';
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
    // First try MQTT cache (real-time)
    final cachedWait = WaittimeCache().getWaitTime(poi.id);
    if (cachedWait != null) {
      return cachedWait.round();
    }
    // Fallback to API response
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
  final bool avoidStairs;

  const DestinationSelectionPage({
    Key? key,
    required this.categoryId,
    this.preselectedSeatInfo,
    this.avoidStairs = false,
  }) : super(key: key);

  @override
  State<DestinationSelectionPage> createState() =>
      _DestinationSelectionPageState();
}

class _DestinationSelectionPageState extends State<DestinationSelectionPage>
    with TickerProviderStateMixin {
  final MapService _mapService = MapService();
  final RoutingService _routingService = RoutingService();
  late final AnimatedMapController _animatedMapController;

  int? selectedIndex;
  List<POIWithRoute> _poisWithRoutes = [];
  List<NodeModel> _allNodes = [];
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

  // Posição do utilizador
  double _userX = 0.0;
  double _userY = 0.0;
  int _userLevel = 0;
  bool _hasValidLocation = true;
  bool _didAutoZoomDefaultPOI = false;
  bool _isAutoZoomingDefaultPOI = false;

  @override
  void initState() {
    super.initState();
    _animatedMapController = AnimatedMapController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
    _loadPOIs();
  }

  @override
  void dispose() {
    _animatedMapController.dispose();
    super.dispose();
  }

  String _normalizeCategory(String backendCategory) {
    final category = backendCategory.toLowerCase();
    switch (category) {
      case 'bar':
      case 'bar_p':
      case 'restaurant':
        return 'food';
      case 'restroom':
      case 'toilet':
      case 'wc':
        return 'wc';
      case 'emergency_exit':
        return 'exit';
      case 'merchandise':
      case 'merchandising':
      case 'store':
        return 'shop';
      case 'parking':
      case 'parking_lot':
      case 'parkinglot':
      case 'car_park':
      case 'carpark':
      case 'park':
        return 'parking';
      case 'first_aid':
      case 'firstaid':
      case 'first-aid':
        return 'first_aid';
      case 'information':
      case 'info':
      case 'poi':
        return 'poi';
      default:
        return category;
    }
  }

  double _euclideanDistance(double x1, double y1, double x2, double y2) {
    return sqrt(pow(x2 - x1, 2) + pow(y2 - y1, 2));
  }

  /// Sem GPS, garante que o POI selecionado por defeito (índice 0) também faz zoom.
  /// O segundo zoom curto cobre casos em que o mapa ainda está a terminar o carregamento.
  void _scheduleDefaultPOIAutoZoom() {
    if (_hasValidLocation || _poisWithRoutes.isEmpty || selectedIndex != 0)
      return;
    if (_didAutoZoomDefaultPOI || _isAutoZoomingDefaultPOI) return;

    _isAutoZoomingDefaultPOI = true;
    final defaultPoi = _poisWithRoutes[0].poi;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        _isAutoZoomingDefaultPOI = false;
        return;
      }

      if (_hasValidLocation || _poisWithRoutes.isEmpty || selectedIndex != 0) {
        _isAutoZoomingDefaultPOI = false;
        return;
      }

      _zoomToPOI(defaultPoi);

      Future.delayed(const Duration(milliseconds: 450), () {
        if (!mounted) {
          _isAutoZoomingDefaultPOI = false;
          return;
        }

        if (!_hasValidLocation &&
            _poisWithRoutes.isNotEmpty &&
            selectedIndex == 0) {
          _zoomToPOI(defaultPoi);
        }

        _didAutoZoomDefaultPOI = true;
        _isAutoZoomingDefaultPOI = false;
      });
    });
  }

  /// Carrega POIs e inicia cálculo de rotas em background
  Future<void> _loadPOIs() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _allRoutesCalculated = false;
      _fastestIndex = null;
      _didAutoZoomDefaultPOI = false;
      _isAutoZoomingDefaultPOI = false;
    });

    try {
      final allPois = await _mapService.getAllPOIs();
      final allNodes = await _mapService.getAllNodes();

      // Carregar posição real do utilizador (GPS ou Saved)
      final userPos = await GeographicUtils.getCurrentUserPosition();

      if (userPos == null) {
        // Se não houver GPS, mostramos o aviso mas deixamos ver a lista
        _userX = 0.0;
        _userY = 0.0;
        _userLevel = 0;
        _hasValidLocation = false;

        if (mounted) {
          AppTopFeedback.showWarning(
            context,
            AppLocalizations.of(context)!.gpsRequiredMessage,
          );
        }
      } else {
        _userX = userPos.x;
        _userY = userPos.y;
        _userLevel = userPos.level;
        _hasValidLocation = true;
      }

      print(
        '[DestinationSelection] Usando posição real/guardada: ($_userX, $_userY, level=$_userLevel)',
      );

      _allNodes = allNodes;

      // Filtrar POIs da categoria
      final categoryPois = allPois.where((poi) {
        return _normalizeCategory(poi.category) ==
            widget.categoryId.toLowerCase();
      }).toList();

      // Criar lista com distâncias estimadas (usando posição real do utilizador)
      List<POIWithRoute> poisWithRoutes = categoryPois.map((poi) {
        final distance = _hasValidLocation
            ? _euclideanDistance(_userX, _userY, poi.x, poi.y)
            : 0.0;
        return POIWithRoute(poi: poi, estimatedDistance: distance);
      }).toList();

      if (_hasValidLocation) {
        // Ordenar por distância euclidiana (aproximação inicial)
        poisWithRoutes.sort(
          (a, b) => a.estimatedDistance.compareTo(b.estimatedDistance),
        );
      } else {
        // Sem GPS, ordenar alfabeticamente
        poisWithRoutes.sort((a, b) => a.poi.name.compareTo(b.poi.name));
      }

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
        if (_hasValidLocation) {
          _calculateRouteForSelected(0);
        } else {
          _scheduleDefaultPOIAutoZoom();
        }
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
    if (_poisWithRoutes.isEmpty || !_hasValidLocation) {
      if (mounted && !_hasValidLocation) {
        setState(() {
          _allRoutesCalculated = true;
        });
      }
      return;
    }

    setState(() {
      _isCalculatingAllRoutes = true;
    });

    try {
      // Calcular todas as rotas em paralelo
      final futures = _poisWithRoutes.map((item) async {
        try {
          final route = await _routingService.getRouteToPOI(
            startX: _userX,
            startY: _userY,
            startLevel: _userLevel,
            poiId: item.poi.id,
            avoidStairs: widget.avoidStairs,
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
        if (_hasValidLocation) {
          // Reordenar a lista pelo tempo total (Menor tempo primeiro)
          _poisWithRoutes.sort(
            (a, b) => a.totalEtaMinutes.compareTo(b.totalEtaMinutes),
          );
        }

        // Como ordenámos, o mais rápido é o primeiro (índice 0)
        int fastestIdx = 0;

        setState(() {
          _isCalculatingAllRoutes = false;
          _allRoutesCalculated = true;
          _fastestIndex = fastestIdx;

          // Selecionar automaticamente o primeiro (mais rápido)
          if (_poisWithRoutes.isNotEmpty) {
            selectedIndex = 0;
            if (_poisWithRoutes[0].hasRoute) {
              _selectedRoute = _poisWithRoutes[0].route;
            }
          }
        });

        // Atualizar zoom para a rota do mais rápido
        if (_selectedRoute != null) {
          // Pequeno delay para garantir que o UI atualizou a lista
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _zoomToRoute(_selectedRoute!);
          });
        }
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

    if (!_hasValidLocation) return;

    setState(() {
      _isCalculatingSelectedRoute = true;
    });

    try {
      final route = await _routingService.getRouteToPOI(
        startX: _userX,
        startY: _userY,
        startLevel: _userLevel,
        poiId: item.poi.id,
        avoidStairs: widget.avoidStairs,
      );

      item.route = route;

      if (mounted && selectedIndex == index) {
        setState(() {
          _selectedRoute = route;
          _isCalculatingSelectedRoute = false;
        });
        // Atrasar zoom para garantir que o mapa está pronto (especialmente na primeira vez)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _zoomToRoute(route);
          }
        });
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

  LatLng _convertToLatLng(double x, double y) {
    // x = Longitude, y = Latitude no nosso novo modelo
    return LatLng(y, x);
  }

  /// Faz zoom para mostrar o início e fim da rota
  void _zoomToRoute(RouteModel route) {
    if (route.path.isEmpty) return;

    // Obter posição do utilizador (real) e do destino
    final startLatLng = _convertToLatLng(_userX, _userY);
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

      _animatedMapController.animateTo(
        dest: LatLng(centerLat, centerLng),
        zoom: zoom,
      );
    } catch (e) {
      print('[DestinationSelection] Erro ao fazer zoom: $e');
    }
  }

  /// Faz zoom para um POI específico (usado quando não há GPS)
  void _zoomToPOI(POIModel poi) {
    try {
      _animatedMapController.animateTo(
        dest: _convertToLatLng(poi.x, poi.y),
        zoom: 18.0,
      );
    } catch (e) {
      print('[DestinationSelection] Erro ao fazer zoom para POI: $e');
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
                  mapController: _animatedMapController.mapController,
                  highlightedRoute: _selectedRoute,
                  highlightedPOI: selectedPOI,
                  showAllPOIs: false,
                  showOtherPOIs: false,
                  interactivePOIs: false,
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
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            localizations.calculatingRoute,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
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
                  backgroundColor: Colors.indigo[200],
                  disabledBackgroundColor:
                      Colors.grey[700], // Fundo cinzento quando indisponível
                  disabledForegroundColor: Colors.white70, // Texto mais fraco
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: selectedIndex != null
                    ? () {
                        if (!_hasValidLocation) {
                          AppTopFeedback.showWarning(
                            context,
                            localizations.gpsRequiredMessage,
                          );
                          return;
                        }

                        if (_selectedRoute == null) {
                          return;
                        }

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => NavigationPage(
                              route: _selectedRoute!,
                              destination: _poisWithRoutes[selectedIndex!].poi,
                              nodes: _allNodes,
                              initialX: _userX,
                              initialY: _userY,
                              initialLevel: _userLevel,
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
              label: Text(localizations.tryAgain),
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

    return AnimatedBuilder(
      animation: WaittimeCache(),
      builder: (context, child) {
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: _poisWithRoutes.length,
      itemBuilder: (context, index) {
        final item = _poisWithRoutes[index];
        final isSelected = selectedIndex == index;
        final isDepartmentOrPoi = _normalizeCategory(widget.categoryId) == 'department' || _normalizeCategory(widget.categoryId) == 'poi';
        final isFastest = _allRoutesCalculated && _fastestIndex == index && !isDepartmentOrPoi;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () {
              setState(() {
                selectedIndex = index;
                _selectedRoute = item.route;
              });
              if (item.hasRoute) {
                // Já tem rota - fazer zoom (atrasar para evitar conflito com build)
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    _zoomToRoute(item.route!);
                  }
                });
              } else if (!_hasValidLocation) {
                // Sem GPS - fazer zoom apenas para o POI
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    _zoomToPOI(item.poi);
                  }
                });
              } else {
                // Calcular rota (zoom será feito após cálculo no _calculateRouteForSelected)
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
                      : Colors.white24,
                  width: isSelected ? 3 : 1,
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  POIIcon(
                    categoryId: widget.categoryId,
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
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            // Tempo de caminhada
                            AnimatedSelectionGlow(
                              play: isSelected,
                              child: _buildInfoChip(
                                icon: Icons.directions_walk,
                                label: (!_hasValidLocation || !item.hasRoute)
                                    ? '-- min'
                                    : localizations.walkTime(item.walkingMinutes),
                                faded: !(item.hasRoute && _hasValidLocation),
                              ),
                            ),
                            // Tempo de fila (apenas categorias com fila)
                            if ([
                              'wc',
                              'food',
                              'store',
                              'bar',
                              'bar_p',
                            ].contains(item.poi.category) ||
                                item.poi.name
                                    .toLowerCase()
                                    .contains('farmácia'))
                              AnimatedSelectionGlow(
                                play: isSelected,
                                child: _buildInfoChip(
                                  icon: Icons.group,
                                  label: localizations
                                      .queueTime(item.waitMinutes),
                                ),
                              ),
                            // Badge "Mais rápido"
                            if (isFastest)
                              Container(
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
                  AnimatedSelectionGlow(
                    play: isSelected,
                    child: Text(
                      (!_hasValidLocation || !item.hasRoute)
                          ? '-- m'
                          : '${item.distance.toStringAsFixed(0)}m',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ); // end Padding
      },
    ); // end ListView.builder
      }, // end AnimatedBuilder builder
    ); // end return AnimatedBuilder
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    bool faded = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF252A5E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: faded ? Colors.white54 : Colors.white, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: faded ? Colors.white54 : Colors.white,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
