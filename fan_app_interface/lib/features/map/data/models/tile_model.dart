/// Tile representation from Map-Service
/// Endpoint: GET /maps/grid/tiles
class TileModel {
  final String id;
  final double gridX;
  final double gridY;
  final int level;
  final double minX;
  final double maxX;
  final double minY;
  final double maxY;
  final bool walkable;

  TileModel({
    required this.id,
    required this.gridX,
    required this.gridY,
    required this.level,
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
    required this.walkable,
  });

  factory TileModel.fromJson(Map<String, dynamic> json) {
    final bounds = json['bounds'] as Map<String, dynamic>;
    return TileModel(
      id: json['id'] as String,
      gridX: (json['grid_x'] as num).toDouble(),
      gridY: (json['grid_y'] as num).toDouble(),
      level: json['level'] as int,
      minX: (bounds['min_x'] as num).toDouble(),
      maxX: (bounds['max_x'] as num).toDouble(),
      minY: (bounds['min_y'] as num).toDouble(),
      maxY: (bounds['max_y'] as num).toDouble(),
      walkable: json['walkable'] as bool,
    );
  }

  /// Verifica se um ponto está dentro deste tile
  bool containsPoint(double x, double y) {
    return x >= minX && x <= maxX && y >= minY && y <= maxY;
  }
}
