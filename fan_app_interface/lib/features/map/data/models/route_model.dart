/// Route data from Routing-Service
/// Endpoint: POST /api/route
///
/// New API uses coordinates for start position and destination_type for target

// ========== REQUEST MODELS ==========

/// Coordinates for positioning
class Coordinates {
  final double x;
  final double y;
  final int level;

  Coordinates({required this.x, required this.y, this.level = 0});

  Map<String, dynamic> toJson() {
    return {'x': x, 'y': y, 'level': level};
  }
}

/// Request model for route calculation
class RouteRequest {
  final Coordinates start;
  final String destinationType; // "node", "poi", "seat", "gate"
  final String destinationId;
  final bool avoidStairs;

  RouteRequest({
    required this.start,
    required this.destinationType,
    required this.destinationId,
    this.avoidStairs = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'start': start.toJson(),
      'destination_type': destinationType,
      'destination_id': destinationId,
      'avoid_stairs': avoidStairs,
    };
  }
}

// ========== RESPONSE MODELS ==========

/// Route response from Routing-Service
class RouteModel {
  final List<PathNode> path;
  final double totalDistance;
  final double estimatedTime; // In seconds
  final double congestionLevel; // 0.0 to 1.0
  final double? waitTime; // Optional wait time in minutes
  final List<String> warnings;

  RouteModel({
    required this.path,
    required this.totalDistance,
    required this.estimatedTime,
    required this.congestionLevel,
    this.waitTime,
    required this.warnings,
  });

  factory RouteModel.fromJson(Map<String, dynamic> json) {
    return RouteModel(
      path: (json['path'] as List).map((p) => PathNode.fromJson(p)).toList(),
      totalDistance: (json['total_distance'] as num).toDouble(),
      estimatedTime: (json['estimated_time'] as num).toDouble(),
      congestionLevel: (json['congestion_level'] as num?)?.toDouble() ?? 0.0,
      waitTime: json['wait_time'] != null
          ? (json['wait_time'] as num).toDouble()
          : null,
      warnings: json['warnings'] != null
          ? List<String>.from(json['warnings'])
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'path': path.map((p) => p.toJson()).toList(),
      'total_distance': totalDistance,
      'estimated_time': estimatedTime,
      'congestion_level': congestionLevel,
      'wait_time': waitTime,
      'warnings': warnings,
    };
  }

  // ========== COMPATIBILITY GETTERS ==========
  // These provide backward compatibility with old code that uses waypoints

  /// Alias for path - backward compatibility
  List<PathNode> get waypoints => path;

  /// Distance in meters - backward compatibility
  double get distance => totalDistance;

  /// ETA in seconds - backward compatibility
  int get etaSeconds => estimatedTime.round();
}

/// Path node with coordinates and timing info
class PathNode {
  final String nodeId;
  final double x;
  final double y;
  final int level;
  final double distanceFromStart;
  final double estimatedTime;

  PathNode({
    required this.nodeId,
    required this.x,
    required this.y,
    required this.level,
    required this.distanceFromStart,
    required this.estimatedTime,
  });

  factory PathNode.fromJson(Map<String, dynamic> json) {
    return PathNode(
      nodeId: json['node_id'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      level: json['level'] as int,
      distanceFromStart: (json['distance_from_start'] as num).toDouble(),
      estimatedTime: (json['estimated_time'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'node_id': nodeId,
      'x': x,
      'y': y,
      'level': level,
      'distance_from_start': distanceFromStart,
      'estimated_time': estimatedTime,
    };
  }

  // ========== COMPATIBILITY GETTER ==========
  // Old WaypointModel had 'type' field - provide default for compatibility
  String get type => 'node';
}

/// Type alias for backward compatibility
typedef WaypointModel = PathNode;
