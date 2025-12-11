import 'package:flutter/material.dart';
import 'package:fan_app_interface/l10n/app_localizations.dart';
import '../data/models/ticket_model.dart';

/// Widget que exibe as informações do bilhete
class TicketInfoCard extends StatelessWidget {
  final TicketModel ticket;
  final VoidCallback onDelete;

  const TicketInfoCard({
    Key? key,
    required this.ticket,
    required this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFF161A3E),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.confirmation_number,
                  color: Colors.white,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    localizations.ticketInfo,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontFamily: 'Gabarito',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Informações do bilhete
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildInfoRow(
                  icon: Icons.grid_view,
                  label: localizations.sector,
                  value: ticket.sectorId,
                ),
                const Divider(height: 24),
                _buildInfoRow(
                  icon: Icons.table_rows,
                  label: localizations.row,
                  value: ticket.rowId,
                ),
                const Divider(height: 24),
                _buildInfoRow(
                  icon: Icons.event_seat,
                  label: localizations.seat,
                  value: ticket.seatId,
                ),
                const Divider(height: 24),
                _buildInfoRow(
                  icon: Icons.door_front_door,
                  label: localizations.gate,
                  value: ticket.gateId,
                ),
                const Divider(height: 24),
                _buildInfoRow(
                  icon: Icons.category,
                  label: localizations.ticketType,
                  value: ticket.ticketType,
                ),
              ],
            ),
          ),
          
          // Botão de apagar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: OutlinedButton.icon(
              onPressed: onDelete,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.delete_outline),
              label: Text(
                localizations.deleteTicket,
                style: const TextStyle(
                  fontSize: 16,
                  fontFamily: 'Gabarito',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF929AD4).withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: const Color(0xFF161A3E),
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                  fontFamily: 'Gabarito',
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: Color(0xFF161A3E),
                  fontSize: 18,
                  fontFamily: 'Gabarito',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
