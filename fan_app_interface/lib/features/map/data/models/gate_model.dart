/// Gate/Entrance from Map-Service
/// Endpoint: GET /api/gates
class GateModel {
  final String id;
  final String? gateNumber;
  final double x;
  final double y;
  final int level;

  GateModel({
    required this.id,
    this.gateNumber,
    required this.x,
    required this.y,
    required this.level,
  });

  factory GateModel.fromJson(Map<String, dynamic> json) {
    return GateModel(
      id: json['id'] as String,
      gateNumber: json['gate_number'] as String?,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      level: json['level'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'gate_number': gateNumber,
      'x': x,
      'y': y,
      'level': level,
    };
  }
}
