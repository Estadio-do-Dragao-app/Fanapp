import 'package:flutter/material.dart';
import '../../map/presentation/stadium_map_page.dart';
import '../../map/data/models/poi_model.dart';
import '../../map/data/models/node_model.dart';
import '../../map/data/models/route_model.dart';
import '../../map/data/services/map_service.dart';
import '../../map/data/services/routing_service.dart';
import '../../navigation/presentation/navigation_page.dart';
import 'package:fan_app_interface/l10n/app_localizations.dart';
import 'dart:math';

class POIWithRoute {
  final POIModel poi;
  final RouteModel route;
  final double distance;
  final int etaMinutes;

  POIWithRoute({
    required this.poi,
    required this.route,
    required this.distance,
    required this.etaMinutes,
  });
}

class DestinationSelectionPage extends StatefulWidget {
  final String categoryId;
  const DestinationSelectionPage({Key? key, required this.categoryId}) : super(key: key);

  @override
  State<DestinationSelectionPage> createState() => _DestinationSelectionPageState();
}

class _DestinationSelectionPageState extends State<DestinationSelectionPage> {
  final MapService _mapService = MapService();
  final RoutingService _routingService = RoutingService();
  
  // Posição fixa do utilizador (mesma do StadiumMapPage)
  static const String userNodeId = 'N1';
  
  int? selectedIndex;
  List<POIWithRoute> _poisWithRoutes = [];
  List<NodeModel> _allNodes = [];
  bool _isLoading = true;
  String? _errorMessage;
  
  @override
  void initState() {
    super.initState();
    _loadPOIsWithRoutes();
  }
  
  /// Normaliza categorias do backend para as categorias da UI
  /// Mapeia categorias do backend para os IDs usados na navbar
  String _normalizeCategory(String backendCategory) {
    final category = backendCategory.toLowerCase();
    
    // Mapeamento completo
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
  
  /// Encontra o nó mais próximo de um POI baseado em coordenadas (x, y)
  String _findNearestNode(POIModel poi, List<NodeModel> nodes) {
    if (nodes.isEmpty) return userNodeId;
    
    NodeModel? nearest;
    double minDistance = double.infinity;
    
    for (var node in nodes) {
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
  
  Future<void> _loadPOIsWithRoutes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      print('[DestinationSelection] Carregando POIs da categoria: ${widget.categoryId}');
      
      // Buscar todos os POIs e nós
      final allPois = await _mapService.getAllPOIs();
      final allNodes = await _mapService.getAllNodes();
      print('[DestinationSelection] Total de POIs recebidos: ${allPois.length}');
      print('[DestinationSelection] Total de nós recebidos: ${allNodes.length}');
      
      // Guardar nodes para uso posterior
      _allNodes = allNodes;
      
      // Log de todas as categorias encontradas
      final categoriesFound = <String, int>{};
      for (var poi in allPois) {
        final cat = poi.category.toLowerCase();
        categoriesFound[cat] = (categoriesFound[cat] ?? 0) + 1;
      }
      print('[DestinationSelection] Categorias encontradas: $categoriesFound');
      
      // Filtrar POIs da categoria solicitada (com normalização)
      final categoryPois = allPois.where((poi) {
        final normalizedCategory = _normalizeCategory(poi.category);
        return normalizedCategory == widget.categoryId.toLowerCase();
      }).toList();
      
      print('[DestinationSelection] POIs da categoria ${widget.categoryId}: ${categoryPois.length}');
      if (categoryPois.isEmpty) {
        print('[DestinationSelection] Nenhum POI encontrado após normalização');
      }
      
      // Calcular rotas para cada POI
      List<POIWithRoute> poisWithRoutes = [];
      for (var poi in categoryPois) {
        try {
          // Encontrar o nó mais próximo do POI
          final nearestNodeId = _findNearestNode(poi, allNodes);
          print('[DestinationSelection] POI ${poi.name} (${poi.id}) -> Nó mais próximo: $nearestNodeId');
          
          final route = await _routingService.getRoute(
            fromNode: userNodeId,
            toNode: nearestNodeId,
          );
          
          poisWithRoutes.add(POIWithRoute(
            poi: poi,
            route: route,
            distance: route.distance,
            etaMinutes: (route.etaSeconds / 60).round(),
          ));
          
          print('[DestinationSelection] Rota calculada: ${route.distance.toStringAsFixed(0)}m, ${(route.etaSeconds / 60).round()} min');
        } catch (e) {
          print('[DestinationSelection] Erro ao calcular rota para ${poi.name}: $e');
          // Continua com os outros POIs
        }
      }
      
      // Ordenar por tempo de rota (mais rápido primeiro)
      poisWithRoutes.sort((a, b) => a.etaMinutes.compareTo(b.etaMinutes));
      
      print('[DestinationSelection] Total de POIs com rotas calculadas: ${poisWithRoutes.length}');
      
      setState(() {
        _poisWithRoutes = poisWithRoutes;
        _isLoading = false;
        // Pré-seleciona o mais rápido
        if (_poisWithRoutes.isNotEmpty) {
          selectedIndex = 0;
        }
      });
    } catch (e) {
      print('[DestinationSelection] Erro: $e');
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  static IconData getCategoryIcon(String categoryId) {
    switch (categoryId.toLowerCase()) {
      case 'seat': return Icons.event_seat;
      case 'wc': return Icons.wc;
      case 'food': return Icons.fastfood;
      case 'bar': return Icons.local_bar;
      case 'exit': return Icons.meeting_room;
      case 'first_aid': return Icons.local_hospital;
      case 'information': return Icons.info;
      case 'merchandising': return Icons.store;
      default: return Icons.place;
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    
    // Obter rota e POI do item selecionado
    final selectedPOIWithRoute = (selectedIndex != null && selectedIndex! < _poisWithRoutes.length)
        ? _poisWithRoutes[selectedIndex!]
        : null;

    return Scaffold(
      backgroundColor: const Color(0xFF161A3E),
      body: Stack(
        children: [
          // Mapa ocupa 40% superior - mostra rota do POI selecionado
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.4,
            child: StadiumMapPage(
              highlightedRoute: selectedPOIWithRoute?.route,
              highlightedPOI: selectedPOIWithRoute?.poi,
              showAllPOIs: false, // Só mostrar o POI selecionado
            ),
          ),
          
          // Botão voltar no canto superior esquerdo
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
          
          // Lista ocupa 60% inferior
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
                  // Título "Choose a location"
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      localizations.chooseLocation,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Gabarito',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Divider(color: Colors.white24, thickness: 1),
                  
                  // Lista de opções
                  Expanded(
                    child: _buildContent(),
                  ),
                ],
              ),
            ),
          ),
          
          // Botão "Choose location" fixo no fundo
          if (!_isLoading && _errorMessage == null)
            Positioned(
              bottom: 24,
              left: 24,
              right: 24,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: selectedIndex != null ? Colors.indigo[200] : Colors.grey[600],
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: selectedIndex != null 
                  ? () {
                      final selectedPOI = _poisWithRoutes[selectedIndex!];
                      
                      // Navegar para NavigationPage
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => NavigationPage(
                            route: selectedPOI.route,
                            destination: selectedPOI.poi,
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
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                localizations.chooseLocation,
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadPOIsWithRoutes,
                icon: const Icon(Icons.refresh),
                label: Text(localizations.tapToSelect),
              ),
            ],
          ),
        ),
      );
    }
    
    if (_poisWithRoutes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            localizations.tapToSelect,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: _poisWithRoutes.length,
      itemBuilder: (context, index) {
        final poiWithRoute = _poisWithRoutes[index];
        final poi = poiWithRoute.poi;
        final isSelected = selectedIndex == index;
        final isFastest = index == 0; // O primeiro é sempre o mais rápido
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () {
              setState(() {
                selectedIndex = index;
              });
            },
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF161A3E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected 
                    ? Colors.white 
                    : Colors.white24,
                  width: isSelected ? 3 : (isFastest ? 2 : 1),
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(getCategoryIcon(widget.categoryId), color: Colors.white, size: 32),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          poi.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Gabarito',
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.access_time, color: Colors.white, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              localizations.minutes(poiWithRoute.etaMinutes),
                              style: const TextStyle(color: Colors.white),
                            ),
                            if (isFastest)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blueAccent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  localizations.faster,
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${poiWithRoute.distance.toStringAsFixed(0)}m',
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