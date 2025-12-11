import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/ticket_model.dart';

/// Serviço para comunicar com a API do Ticket-Service
class TicketService {
  // URL base do Ticket-Service (alterar para produção)
  static const String baseUrl = 'http://localhost:8001';

  /// GET /ticket/{ticket_id} - Obtém informação de um bilhete
  Future<TicketModel> getTicket(int ticketId) async {
    final response = await http
        .get(
          Uri.parse('$baseUrl/ticket/$ticketId'),
          headers: {'Content-Type': 'application/json'},
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return TicketModel.fromJson(json.decode(response.body));
    } else if (response.statusCode == 404) {
      throw TicketNotFoundException('Bilhete não encontrado');
    } else {
      throw TicketServiceException(
        'Erro ao obter bilhete: ${response.statusCode}',
      );
    }
  }

  /// GET /ticket/scan/{qr_data} - Obtém bilhete através do QR code
  /// O formato do QR é: {ticket_id}:{signature}
  Future<TicketModel> getTicketByQR(String qrData) async {
    // Encode do qrData para URL (contém ':')
    final encodedQrData = Uri.encodeComponent(qrData);

    final response = await http
        .get(
          Uri.parse('$baseUrl/ticket/scan/$encodedQrData'),
          headers: {'Content-Type': 'application/json'},
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return TicketModel.fromJson(json.decode(response.body));
    } else if (response.statusCode == 400) {
      throw InvalidQRFormatException('Formato de QR code inválido');
    } else if (response.statusCode == 401) {
      throw InvalidQRSignatureException('QR code inválido ou adulterado');
    } else if (response.statusCode == 404) {
      throw TicketNotFoundException('Bilhete não encontrado');
    } else {
      throw TicketServiceException(
        'Erro ao validar QR code: ${response.statusCode}',
      );
    }
  }

  /// PUT /ticket/{ticket_id} - Reserva um bilhete
  Future<TicketModel> reserveTicket(int ticketId) async {
    final response = await http
        .put(
          Uri.parse('$baseUrl/ticket/$ticketId'),
          headers: {'Content-Type': 'application/json'},
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return TicketModel.fromJson(json.decode(response.body));
    } else if (response.statusCode == 404) {
      throw TicketNotFoundException('Bilhete não encontrado');
    } else {
      throw TicketServiceException(
        'Erro ao reservar bilhete: ${response.statusCode}',
      );
    }
  }
}

/// Exceção quando o bilhete não é encontrado
class TicketNotFoundException implements Exception {
  final String message;
  TicketNotFoundException(this.message);

  @override
  String toString() => message;
}

/// Exceção genérica do serviço de bilhetes
class TicketServiceException implements Exception {
  final String message;
  TicketServiceException(this.message);

  @override
  String toString() => message;
}

/// Exceção quando o formato do QR code é inválido
class InvalidQRFormatException implements Exception {
  final String message;
  InvalidQRFormatException(this.message);

  @override
  String toString() => message;
}

/// Exceção quando a assinatura do QR code é inválida
class InvalidQRSignatureException implements Exception {
  final String message;
  InvalidQRSignatureException(this.message);

  @override
  String toString() => message;
}
