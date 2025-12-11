import 'package:flutter/material.dart';
import 'package:fan_app_interface/l10n/app_localizations.dart';
import '../data/models/ticket_model.dart';
import '../data/services/ticket_storage_service.dart';
import 'qr_scanner_page.dart';
import 'ticket_info_card.dart';

/// Bottom sheet menu para gestão de bilhetes
class TicketMenu extends StatefulWidget {
  const TicketMenu({Key? key}) : super(key: key);

  /// Mostra o menu como bottom sheet
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const TicketMenu(),
    );
  }

  @override
  State<TicketMenu> createState() => _TicketMenuState();
}

class _TicketMenuState extends State<TicketMenu> {
  final TicketStorageService _storageService = TicketStorageService();
  TicketModel? _ticket;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTicket();
  }

  Future<void> _loadTicket() async {
    final ticket = await _storageService.getTicket();
    if (mounted) {
      setState(() {
        _ticket = ticket;
        _isLoading = false;
      });
    }
  }

  Future<void> _openScanner() async {
    final result = await Navigator.of(context).push<TicketModel>(
      MaterialPageRoute(
        builder: (context) => const QRScannerPage(),
      ),
    );
    
    if (result != null && mounted) {
      setState(() {
        _ticket = result;
      });
    }
  }

  Future<void> _deleteTicket() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.deleteTicket),
        content: Text(AppLocalizations.of(context)!.deleteTicketConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(AppLocalizations.of(context)!.deleteTicket),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      await _storageService.deleteTicket();
      if (mounted) {
        setState(() {
          _ticket = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    
    return DraggableScrollableSheet(
      initialChildSize: _ticket != null ? 0.7 : 0.3,
      minChildSize: 0.2,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF5F5F5),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                if (_isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_ticket != null)
                  TicketInfoCard(
                    ticket: _ticket!,
                    onDelete: _deleteTicket,
                  )
                else
                  _buildAddTicketOption(localizations),
                
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAddTicketOption(AppLocalizations localizations) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: InkWell(
        onTap: _openScanner,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF929AD4).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.qr_code_scanner,
                  color: Color(0xFF161A3E),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizations.addTicket,
                      style: const TextStyle(
                        color: Color(0xFF161A3E),
                        fontSize: 18,
                        fontFamily: 'Gabarito',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      localizations.scanTicketQR,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                        fontFamily: 'Gabarito',
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: Color(0xFF161A3E),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
