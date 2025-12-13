import 'package:flutter/material.dart';
import 'package:fan_app_interface/l10n/app_localizations.dart';
import '../../data/models/navigation_instruction.dart';

/// Widget que mostra a próxima instrução no topo da tela
/// Exemplo: "Vire à esquerda em 15 m"
class NavigationHeader extends StatelessWidget {
  final NavigationInstruction? instruction;
  final bool isEmergency;

  const NavigationHeader({
    Key? key,
    required this.instruction,
    this.isEmergency = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    
    if (instruction == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isEmergency 
              ? [
                  const Color(0xFFBD453D),
                  const Color(0xFFBD453D).withOpacity(0.8),
                  const Color(0xFFBD453D).withOpacity(0.5),
                  Colors.transparent,
                ]
              : [
                  const Color(0xFF929AD4),
                  const Color(0xFF929AD4).withOpacity(0.8),
                  const Color(0xFF929AD4).withOpacity(0.5),
                  Colors.transparent,
                ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Row(
            children: [
              // Ícone da instrução (seta)
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  _getIconData(instruction!.type),
                  color: isEmergency ? const Color(0xFFBD453D) : const Color(0xFF929AD4),
                  size: 40,
                ),
              ),
              
              const SizedBox(width: 20),
              
              // Texto da instrução
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      instruction!.formattedDistance,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      instruction!.getDescription((key) => _translate(localizations, key)),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIconData(String type) {
    switch (type) {
      case 'left':
        return Icons.turn_left;
      case 'right':
        return Icons.turn_right;
      case 'straight':
        return Icons.arrow_upward;
      case 'arrive':
        return Icons.location_on;
      default:
        return Icons.arrow_upward;
    }
  }

  String _translate(AppLocalizations localizations, String key) {
    switch (key) {
      case 'turn_left':
        return localizations.turnLeft;
      case 'turn_right':
        return localizations.turnRight;
      case 'continue_straight':
        return localizations.continueStraight;
      case 'arrive_at_destination':
        return localizations.arriveAtDestination;
      default:
        return '';
    }
  }
}
