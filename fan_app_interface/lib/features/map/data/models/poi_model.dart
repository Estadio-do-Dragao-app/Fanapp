/// POI (Point of Interest) from Map-Service
/// Endpoint: GET /api/pois
class POIModel {
  final String id;
  final String name;
  final String category; // Mapped from 'type' in API
  final String description;
  final double x;
  final double y;
  final int level;

  POIModel({
    required this.id,
    required this.name,
    required this.category,
    this.description = '',
    required this.x,
    required this.y,
    required this.level,
  });

  factory POIModel.fromJson(Map<String, dynamic> json) {
    return POIModel(
      id: json['id'] as String,
      name:
          json['name'] as String? ??
          'Unnamed', // Handle nullable name if occurs
      category: json['type'] as String? ?? 'unknown',
      description: json['description'] as String? ?? '',
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      level: json['level'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': category, // Back to API format
      'description': description,
      'x': x,
      'y': y,
      'level': level,
    };
  }
}
