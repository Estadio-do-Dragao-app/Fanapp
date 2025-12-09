/// Route data from Routing-Service
/// Endpoint: GET /api/route?from_node=X&to_node=Y
class RouteModel {
  final List<String> path; // List of node IDs
  final double distance; // In meters
  final int etaSeconds; // Estimated time in seconds
  final List<WaypointModel> waypoints;

  RouteModel({
    required this.path,
    required this.distance,
    required this.etaSeconds,
    required this.waypoints,
  });

  factory RouteModel.fromJson(Map<String, dynamic> json) {
    return RouteModel(
      path: List<String>.from(json['path']),
      distance: (json['distance'] as num).toDouble(),
      etaSeconds: json['eta_seconds'] as int,
      waypoints: (json['waypoints'] as List)
          .map((w) => WaypointModel.fromJson(w))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'distance': distance,
      'eta_seconds': etaSeconds,
      'waypoints': waypoints.map((w) => w.toJson()).toList(),
    };
  }
}

/// Waypoint with coordinates
class WaypointModel {
  final String nodeId;
  final double x;
  final double y;
  final int level;
  final String type;

  WaypointModel({
    required this.nodeId,
    required this.x,
    required this.y,
    required this.level,
    required this.type,
  });

  factory WaypointModel.fromJson(Map<String, dynamic> json) {
    return WaypointModel(
      nodeId: json['node_id'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      level: json['level'] as int,
      type: json['type'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'node_id': nodeId,
      'x': x,
      'y': y,
      'level': level,
      'type': type,
    };
  }
}
