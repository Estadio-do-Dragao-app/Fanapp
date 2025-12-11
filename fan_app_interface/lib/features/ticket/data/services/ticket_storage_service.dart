import 'package:shared_preferences/shared_preferences.dart';
import '../models/ticket_model.dart';

/// Serviço de persistência local para o bilhete do utilizador
class TicketStorageService {
  static const String _ticketKey = 'user_ticket';

  /// Guarda o bilhete localmente
  Future<void> saveTicket(TicketModel ticket) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ticketKey, ticket.toJsonString());
  }

  /// Obtém o bilhete guardado (null se não existir)
  Future<TicketModel?> getTicket() async {
    final prefs = await SharedPreferences.getInstance();
    final ticketJson = prefs.getString(_ticketKey);
    if (ticketJson == null) return null;
    try {
      return TicketModel.fromJsonString(ticketJson);
    } catch (e) {
      // Se o JSON estiver corrompido, remove-o
      await deleteTicket();
      return null;
    }
  }

  /// Apaga o bilhete guardado
  Future<void> deleteTicket() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_ticketKey);
  }

  /// Verifica se existe um bilhete guardado
  Future<bool> hasTicket() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_ticketKey);
  }
}
