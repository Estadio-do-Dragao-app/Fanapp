import 'package:flutter/material.dart';
import 'package:fan_app_interface/core/widgets/category_buttons.dart';
import 'package:fan_app_interface/features/poi/presentation/destination_selection.dart';
import 'package:fan_app_interface/features/ticket/data/services/ticket_storage_service.dart';
import 'package:fan_app_interface/features/ticket/presentation/ticket_menu.dart';
import 'package:fan_app_interface/l10n/app_localizations.dart';
import 'package:fan_app_interface/features/map/data/services/map_service.dart';
import 'package:fan_app_interface/features/map/data/services/routing_service.dart';
import 'package:fan_app_interface/features/map/data/models/node_model.dart';
import 'package:fan_app_interface/features/map/data/models/poi_model.dart';
import 'package:fan_app_interface/features/ticket/data/models/ticket_model.dart';
import 'package:fan_app_interface/features/poi/presentation/poi_details_sheet.dart';
import 'dart:math';

/// Simple MapPage implementation that shows a placeholder 'map' area and a
/// horizontal row of category buttons overlayed at the top.
class Navbar extends StatefulWidget {
  const Navbar({Key? key}) : super(key: key);

  @override
  State<Navbar> createState() => _NavbarState();
}

class _NavbarState extends State<Navbar> {
  final List<String> categoryIds = ['seat', 'wc', 'food', 'exit'];
  final TicketStorageService _ticketStorage = TicketStorageService();
  final MapService _mapService = MapService();
  final RoutingService _routingService = RoutingService();
  int selected = 0;

  // Posição fixa do utilizador (mesma do StadiumMapPage)
  static const String userNodeId = 'N1';

  Future<void> _handleCategorySelect(
    int i,
    AppLocalizations localizations,
  ) async {
    setState(() => selected = i);

    // Caso especial para o botão "seat"
    if (categoryIds[i] == 'seat') {
      // Verificar se tem bilhete digitalizado
      final ticket = await _ticketStorage.getTicket();
      if (ticket == null) {
        // Não tem bilhete - mostrar diálogo
        if (!mounted) return;
        _showNoTicketDialog(localizations);
        return;
      }

      // Tem bilhete - navegar diretamente para o lugar
      if (!mounted) return;
      await _navigateToSeat(ticket, localizations);
      return;
    }

    // Para outras categorias, comportamento normal
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            DestinationSelectionPage(categoryId: categoryIds[i]),
        transitionsBuilder: _buildSlideTransition,
      ),
    );
  }

  /// Encontra o nó mais próximo de uma coordenada
  String _findNearestNode(
    double x,
    double y,
    int level,
    List<NodeModel> nodes,
  ) {
    if (nodes.isEmpty) return userNodeId;

    NodeModel? nearest;
    double minDistance = double.infinity;

    for (var node in nodes) {
      if (node.level != level) continue;

      final dx = node.x - x;
      final dy = node.y - y;
      final distance = sqrt(dx * dx + dy * dy);

      if (distance < minDistance) {
        minDistance = distance;
        nearest = node;
      }
    }

    return nearest?.id ?? userNodeId;
  }

  /// Navega diretamente para o lugar do utilizador baseado no bilhete
  Future<void> _navigateToSeat(
    TicketModel ticket,
    AppLocalizations localizations,
  ) async {
    // Mostrar loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          const Center(child: CircularProgressIndicator(color: Colors.white)),
    );

    try {
      // Buscar todos os nós do mapa
      final allNodes = await _mapService.getAllNodes();

      // Criar um POI virtual para o lugar do utilizador
      // Assumimos que o lugar está numa posição fixa baseada no sector
      // TODO: Implementar lógica real de mapeamento de lugares para coordenadas
      final seatPOI = POIModel(
        id: 'seat_${ticket.sectorId}_${ticket.rowId}_${ticket.seatId}',
        name:
            '${ticket.sectorId} - Fila ${ticket.rowId} - Lugar ${ticket.seatId}',
        category: 'seat',
        x: 50.0, // TODO: Calcular posição real baseada no sector/fila/lugar
        y: 50.0,
        level: 0,
      );

      // Encontrar o nó mais próximo do lugar
      final nearestNodeId = _findNearestNode(
        seatPOI.x,
        seatPOI.y,
        seatPOI.level,
        allNodes,
      );

      // Calcular rota
      final route = await _routingService.getRoute(
        fromNode: userNodeId,
        toNode: nearestNodeId,
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // Fechar loading

      // Mostrar bottom sheet com detalhes e botão de navegação
      POIDetailsSheet.show(
        context,
        poi: seatPOI,
        route: route,
        onNavigate: () {
          // Feedback de navegação
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('A navegar para ${seatPOI.name}'),
              backgroundColor: const Color(0xFF161A3E),
            ),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Fechar loading

      // Mostrar erro
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao calcular rota: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildSlideTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    const begin = Offset(0.0, 1.0);
    const end = Offset.zero;
    const curve = Curves.easeInOut;
    final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
    final offsetAnimation = animation.drive(tween);
    return SlideTransition(position: offsetAnimation, child: child);
  }

  void _showNoTicketDialog(AppLocalizations localizations) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange),
            const SizedBox(width: 12),
            Text(localizations.noTicketScanned),
          ],
        ),
        content: Text(localizations.noTicketScannedMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(localizations.cancel),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              TicketMenu.show(context);
            },
            icon: const Icon(Icons.qr_code_scanner),
            label: Text(localizations.scanNow),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF161A3E),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final categories = [
      localizations.seat,
      localizations.wc,
      localizations.food,
      localizations.exit,
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF929AD4),
                  Color(0xFF929AD4).withOpacity(0.8),
                  Color(0xFF929AD4).withOpacity(0.5),
                  Colors.transparent,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          // Top overlay: category buttons inside SafeArea
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.topLeft,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          localizations.whereToQuestion,
                          style: const TextStyle(
                            fontSize: 32,
                            fontFamily: 'Gabarito',
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.left,
                        ),
                        const SizedBox(height: 16),
                        CategoryButtons(
                          labels: categories,
                          selectedIndex: selected,
                          onSelect: (i) =>
                              _handleCategorySelect(i, localizations),
                          iconBuilder: (label) {
                            // Match against translated labels
                            if (label == localizations.seat) {
                              return const Icon(
                                Icons.event_seat,
                                color: Colors.black,
                              );
                            } else if (label == localizations.wc) {
                              return const Icon(Icons.wc, color: Colors.black);
                            } else if (label == localizations.food) {
                              return const Icon(
                                Icons.fastfood,
                                color: Colors.black,
                              );
                            } else if (label == localizations.exit) {
                              return const Icon(
                                Icons.meeting_room,
                                color: Colors.black,
                              );
                            } else {
                              return const Icon(
                                Icons.help,
                                color: Colors.black,
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  // Search button in top right
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
