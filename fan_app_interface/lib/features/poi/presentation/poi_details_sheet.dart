import 'package:flutter/material.dart';
import '../../map/data/models/poi_model.dart';
import '../../map/data/models/route_model.dart';
import '../../map/data/models/node_model.dart';
import '../../navigation/presentation/navigation_page.dart';

/// Bottom sheet que mostra detalhes de um POI
class POIDetailsSheet extends StatelessWidget {
  final POIModel poi;
  final RouteModel? route;
  final List<NodeModel>? allNodes;
  final VoidCallback? onNavigate;

  const POIDetailsSheet({
    Key? key,
    required this.poi,
    this.route,
    this.allNodes,
    this.onNavigate,
  }) : super(key: key);

  /// Mostra o bottom sheet com detalhes do POI
  static Future<void> show(
    BuildContext context, {
    required POIModel poi,
    RouteModel? route,
    List<NodeModel>? allNodes,
    VoidCallback? onNavigate,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E3F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => POIDetailsSheet(
        poi: poi,
        route: route,
        allNodes: allNodes,
        onNavigate: onNavigate,
      ),
    ).then((_) {});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho com nome e distância
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  poi.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Gabarito',
                  ),
                ),
              ),
              if (route != null)
                Text(
                  '${route!.distance.toStringAsFixed(0)} m',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Descrição do POI (placeholder)
          Text(
            _getPOIDescription(poi.category),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          
          // Informações de tempo
          Row(
            children: [
              // Tempo de caminhada
              _buildTimeInfo(
                icon: Icons.directions_walk,
                label: route != null 
                  ? '${(route!.etaSeconds / 60).round()} min'
                  : '3 min',
              ),
              const SizedBox(width: 24),
              
              // Tempo de fila (fixo por enquanto)
              _buildTimeInfo(
                icon: Icons.group,
                label: '15 min',
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Botão de navegação
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                
                // Se callback fornecido, chamar
                if (onNavigate != null) {
                  onNavigate!();
                }
                // Senão, abrir página de navegação
                else if (route != null && allNodes != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NavigationPage(
                        route: route!,
                        destination: poi,
                        nodes: allNodes!,
                      ),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(50),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.navigation, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'Navigate',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeInfo({required IconData icon, required String label}) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _getPOIDescription(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return 'An hamburguer company...';
      case 'bar':
        return 'Drinks and refreshments available...';
      case 'restroom':
        return 'Public restroom facilities...';
      case 'emergency_exit':
        return 'Emergency exit point...';
      case 'first_aid':
        return 'First aid medical assistance...';
      case 'information':
        return 'Information desk...';
      default:
        return 'Point of interest...';
    }
  }
}
