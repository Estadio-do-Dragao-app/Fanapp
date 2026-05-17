/// Node representation from Map-Service
/// Endpoint: GET /api/nodes
class NodeModel {
  final String id;
  final double x;
  final double y;
  final int level;
  final String type;

  NodeModel({
    required this.id,
    required this.x,
    required this.y,
    required this.level,
    required this.type,
  });

  factory NodeModel.fromJson(Map<String, dynamic> json) {
    return NodeModel(
      id: json['id']?.toString() ?? 'unknown_node',
      x: (json['x'] as num?)?.toDouble() ?? 0.0,
      y: (json['y'] as num?)?.toDouble() ?? 0.0,
      level: json['level'] as int? ?? 0,
      type: json['type']?.toString() ?? 'normal',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'x': x,
      'y': y,
      'level': level,
      'type': type,
    };
  }
}
