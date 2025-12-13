import 'dart:convert';

/// Modelo de dados para o bilhete do estádio
class TicketModel {
  final int id;
  final int eventId;
  final String gatesOpen;
  final String gateId;
  final String rowId;
  final String seatId;
  final String sectorId;
  final String ticketType;
  final bool state;
  // ID do seat no Map-Service (ex: Seat-Norte-T0-R05-12)
  final String? seatNodeId;

  const TicketModel({
    required this.id,
    required this.eventId,
    required this.gatesOpen,
    required this.gateId,
    required this.rowId,
    required this.seatId,
    required this.sectorId,
    required this.ticketType,
    required this.state,
    this.seatNodeId,
  });

  factory TicketModel.fromJson(Map<String, dynamic> json) {
    return TicketModel(
      id: json['id'] as int,
      eventId: json['event_id'] as int,
      gatesOpen: json['gates_open'] as String,
      gateId: json['gate_id'] as String,
      rowId: json['row_id'] as String,
      seatId: json['seat_id'] as String,
      sectorId: json['sector_id'] as String,
      ticketType: json['ticket_type'] as String,
      state: json['state'] as bool,
      seatNodeId: json['seat_node_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'event_id': eventId,
      'gates_open': gatesOpen,
      'gate_id': gateId,
      'row_id': rowId,
      'seat_id': seatId,
      'sector_id': sectorId,
      'ticket_type': ticketType,
      'state': state,
      'seat_node_id': seatNodeId,
    };
  }

  String toJsonString() => jsonEncode(toJson());

  factory TicketModel.fromJsonString(String jsonString) {
    return TicketModel.fromJson(jsonDecode(jsonString));
  }

  /// Retorna uma descrição legível do lugar
  String get seatDescription => 'Setor $sectorId - Fila $rowId - Lugar $seatId';
}
