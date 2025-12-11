import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:fan_app_interface/l10n/app_localizations.dart';
import '../data/services/ticket_service.dart';
import '../data/services/ticket_storage_service.dart';

/// Página de scanner de QR code para bilhetes
class QRScannerPage extends StatefulWidget {
  const QRScannerPage({Key? key}) : super(key: key);

  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> {
  final MobileScannerController _scannerController = MobileScannerController();
  final TicketService _ticketService = TicketService();
  final TicketStorageService _storageService = TicketStorageService();

  bool _isProcessing = false;
  String? _errorMessage;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _onBarcodeDetected(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? code = barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;

    // Validar formato: deve conter ticket_id:signature
    if (!code.contains(':')) {
      setState(() {
        _errorMessage = 'Código QR inválido';
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      // Buscar informação do bilhete via QR (valida assinatura no backend)
      final ticket = await _ticketService.getTicketByQR(code);

      // Guardar localmente
      await _storageService.saveTicket(ticket);

      if (mounted) {
        // Retornar o bilhete para a página anterior
        Navigator.of(context).pop(ticket);
      }
    } on InvalidQRFormatException {
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Formato de QR code inválido';
      });
    } on InvalidQRSignatureException {
      setState(() {
        _isProcessing = false;
        _errorMessage = 'QR code inválido ou adulterado';
      });
    } on TicketNotFoundException {
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Bilhete não encontrado';
      });
    } on TicketServiceException catch (e) {
      setState(() {
        _isProcessing = false;
        _errorMessage = e.message;
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Erro de conexão. Verifique a sua internet.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Scanner de QR
          MobileScanner(
            controller: _scannerController,
            onDetect: _onBarcodeDetected,
          ),

          // Overlay com instruções
          SafeArea(
            child: Column(
              children: [
                // Barra superior com botão de voltar
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF161A3E).withOpacity(0.8),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          localizations.scanTicketQR,
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

                const Spacer(),

                // Área de visualização do scanner
                Container(
                  margin: const EdgeInsets.all(32),
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xFF929AD4),
                      width: 3,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),

                const Spacer(),

                // Mensagem de estado
                Container(
                  margin: const EdgeInsets.all(24),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161A3E).withOpacity(0.9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      if (_isProcessing)
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            ),
                            SizedBox(width: 12),
                            Text(
                              'A processar...',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontFamily: 'Gabarito',
                              ),
                            ),
                          ],
                        )
                      else if (_errorMessage != null)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 16,
                                  fontFamily: 'Gabarito',
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        Text(
                          localizations.scanTicketQR,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontFamily: 'Gabarito',
                          ),
                          textAlign: TextAlign.center,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
