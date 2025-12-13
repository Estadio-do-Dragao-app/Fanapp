import 'package:flutter/material.dart';
import 'package:fan_app_interface/l10n/app_localizations.dart';
import '../../../map/data/models/poi_model.dart';

/// Bottom sheet expansível com informações de navegação
/// Estado normal (compacto) e expandido (com botão End Route)
class NavigationBottomSheet extends StatefulWidget {
  final String arrivalTime; // Ex: "19:39"
  final String remainingTime; // Ex: "0:05 hrs"
  final String remainingDistance; // Ex: "40 m"
  final POIModel destination;
  final VoidCallback onEndRoute;
  final bool isEmergency;

  const NavigationBottomSheet({
    Key? key,
    required this.arrivalTime,
    required this.remainingTime,
    required this.remainingDistance,
    required this.destination,
    required this.onEndRoute,
    this.isEmergency = false,
  }) : super(key: key);

  @override
  State<NavigationBottomSheet> createState() => _NavigationBottomSheetState();
}

class _NavigationBottomSheetState extends State<NavigationBottomSheet>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _heightAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _heightAnimation = Tween<double>(begin: 120, end: 280).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return GestureDetector(
      onVerticalDragUpdate: (details) {
        if (details.primaryDelta! < -5) {
          // Swipe para cima - expandir
          if (!_isExpanded) _toggleExpanded();
        } else if (details.primaryDelta! > 5) {
          // Swipe para baixo - contrair
          if (_isExpanded) _toggleExpanded();
        }
      },
      child: AnimatedBuilder(
        animation: _heightAnimation,
        builder: (context, child) {
          return Container(
            height: _heightAnimation.value,
            decoration: BoxDecoration(
              color: widget.isEmergency 
                  ? const Color(0xFF1E1E3F)
                  : const Color(0xFF1E1E3F),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Indicador de arrasto
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Conteúdo compacto (sempre visível)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildInfoColumn(
                          localizations.arrival,
                          widget.arrivalTime,
                          widget.isEmergency,
                        ),
                        _buildInfoColumn(
                          localizations.time,
                          widget.remainingTime,
                          widget.isEmergency,
                        ),
                        _buildInfoColumn(
                          localizations.distance,
                          widget.remainingDistance,
                          widget.isEmergency,
                        ),
                      ],
                    ),
                  ),

                  // Conteúdo expandido
                  if (_isExpanded) ...[
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            localizations.destination,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.destination.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 16),
                          
                          // Botão End Route
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: widget.onEndRoute,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: widget.isEmergency
                                    ? const Color(0xFFBD453D)
                                    : const Color(0xFFE74C3C),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                localizations.endRoute,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoColumn(String label, String value, bool isEmergency) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: isEmergency 
                ? const Color(0xFFFF6B6B)
                : Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
