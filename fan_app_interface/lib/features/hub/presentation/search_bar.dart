import 'package:flutter/material.dart';
import 'package:fan_app_interface/l10n/app_localizations.dart';
import '../../map/data/models/poi_model.dart';
import '../../map/data/models/route_model.dart';
import '../../map/data/models/node_model.dart';
import '../../map/data/services/map_service.dart';
import '../../map/data/services/routing_service.dart';
import '../../poi/presentation/poi_details_sheet.dart';
import 'dart:math';

class SearchBarBottomSheet extends StatefulWidget {
  final Function(POIModel)? onPOISelected;
  
  const SearchBarBottomSheet({Key? key, this.onPOISelected}) : super(key: key);

  @override
  State<SearchBarBottomSheet> createState() => _SearchBarBottomSheetState();
}

class _SearchBarBottomSheetState extends State<SearchBarBottomSheet> {
  late TextEditingController _searchController;
  final MapService _mapService = MapService();
  final RoutingService _routingService = RoutingService();
  
  // Posição fixa do utilizador (mesma do StadiumMapPage)
  static const String userNodeId = 'N1';
  
  List<POIModel> _allPOIs = [];
  List<NodeModel> _allNodes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _loadPOIs();
  }
  
  Future<void> _loadPOIs() async {
    try {
      final pois = await _mapService.getAllPOIs();
      final nodes = await _mapService.getAllNodes();
      setState(() {
        _allPOIs = pois;
        _allNodes = nodes;
        _isLoading = false;
      });
    } catch (e) {
      print('[SearchBar] Erro ao carregar POIs: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  /// Encontra o nó mais próximo de um POI baseado em coordenadas (x, y)
  String _findNearestNode(POIModel poi) {
    if (_allNodes.isEmpty) return userNodeId;
    
    NodeModel? nearest;
    double minDistance = double.infinity;
    
    for (var node in _allNodes) {
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
  
  /// Mostra detalhes do POI selecionado
  Future<void> _showPOIDetails(POIModel poi) async {
    // Fechar a barra de pesquisa primeiro
    Navigator.pop(context);
    
    // Aguardar um frame para garantir que o modal foi fechado
    await Future.delayed(const Duration(milliseconds: 100));
    
    // Notificar callback para fazer zoom (se existir)
    widget.onPOISelected?.call(poi);
    
    // Calcular rota para o POI (apenas para mostrar distância/tempo)
    RouteModel? route;
    try {
      final nearestNode = _findNearestNode(poi);
      route = await _routingService.getRoute(
        fromNode: userNodeId,
        toNode: nearestNode,
      );
    } catch (e) {
      print('[SearchBar] Erro ao calcular rota: $e');
    }
    
    if (!mounted) return;
    
    // Mostrar detalhes do POI (sem desenhar rota)
    POIDetailsSheet.show(
      context,
      poi: poi,
      route: route,
      onNavigate: () {
        // Apenas mostra feedback
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Navegação para ${poi.name}')),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setModalState) {
        final filteredPOIs = _searchController.text.isEmpty
            ? _allPOIs
            : _allPOIs
                .where((poi) => poi.name
                    .toLowerCase()
                    .contains(_searchController.text.toLowerCase()))
                .toList();

        return FractionallySizedBox(
          heightFactor: 1.0,
          child: Column(
            children: [
              // Search Bar
              Container(
                height: 60,
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF161A3E),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                     Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()..scale(-1.0, 1.0, 1.0),
                      child: const Icon(Icons.search, color: Colors.white, size: 30),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        autofocus: true,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Gabarito',
                          fontSize: 20,
                        ),
                        decoration: InputDecoration(
                          hintText: AppLocalizations.of(context)!.search,
                          hintStyle: TextStyle(
                            color: Colors.white70,
                            fontFamily: 'Gabarito',
                            fontSize: 20,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: (value) {
                          setModalState(() {});
                        },
                      ),
                    ),
                    if (_searchController.text.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          setModalState(() {});
                        },
                        child: const Icon(Icons.clear,
                            color: Colors.white, size: 30),
                      ),
                    const SizedBox(width: 12),
                  ],
                ),
              ),
              // Results List
              Expanded(
                child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFF161A3E)),
                    )
                  : ListView.builder(
                      itemCount: filteredPOIs.length,
                      itemBuilder: (context, index) {
                        final poi = filteredPOIs[index];
                        final textColor = const Color(0xFF161A3E);

                        return ListTile(
                          leading: Icon(
                            _getCategoryIcon(poi.category),
                            color: textColor,
                          ),
                          title: Text(
                            poi.name,
                            style: TextStyle(
                              fontFamily: 'Gabarito',
                              fontSize: 16,
                              color: textColor,
                            ),
                          ),
                          subtitle: Text(
                            _getCategoryName(context, poi.category),
                            style: TextStyle(
                              fontSize: 12,
                              color: textColor.withOpacity(0.6),
                            ),
                          ),
                          onTap: () {
                            _showPOIDetails(poi);
                          },
                        );
                      },
                    ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'restroom':
        return Icons.wc;
      case 'food':
      case 'bar':
      case 'restaurant':
        return Icons.restaurant;
      case 'emergency_exit':
        return Icons.exit_to_app;
      case 'first_aid':
        return Icons.local_hospital;
      case 'information':
        return Icons.info;
      case 'merchandise':
        return Icons.shopping_bag;
      default:
        return Icons.place;
    }
  }
  
  String _getCategoryName(BuildContext context, String category) {
    final loc = AppLocalizations.of(context)!;
    switch (category.toLowerCase()) {
      case 'restroom':
        return loc.wc;
      case 'food':
      case 'bar':
      case 'restaurant':
        return loc.food;
      case 'emergency_exit':
        return loc.exit;
      case 'first_aid':
        return loc.firstAid;
      case 'information':
        return loc.information;
      case 'merchandise':
        return loc.merchandising;
      default:
        return category;
    }
  }
}