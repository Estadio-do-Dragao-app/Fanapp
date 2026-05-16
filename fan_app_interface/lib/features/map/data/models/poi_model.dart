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
      id: json['id']?.toString() ?? 'unknown_poi',
      name: json['name']?.toString() ?? 'Unnamed', 
      category: json['type']?.toString() ?? 'unknown',
      description: json['description']?.toString() ?? '',
      x: (json['x'] as num?)?.toDouble() ?? 0.0,
      y: (json['y'] as num?)?.toDouble() ?? 0.0,
      level: json['level'] as int? ?? 0,
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
