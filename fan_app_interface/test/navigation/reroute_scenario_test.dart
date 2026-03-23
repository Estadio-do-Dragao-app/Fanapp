import 'package:flutter_test/flutter_test.dart';

import 'package:fan_app_interface/features/map/data/models/node_model.dart';
import 'package:fan_app_interface/features/map/data/models/route_model.dart';
import 'package:fan_app_interface/features/navigation/domain/route_tracker.dart';

NodeModel _node(String id, double x, double y, {int level = 0}) {
  return NodeModel(id: id, x: x, y: y, level: level, type: 'corridor');
}

PathNode _pathNode(String id, double x, double y, {int level = 0}) {
  return PathNode(
    nodeId: id,
    x: x,
    y: y,
    level: level,
    distanceFromStart: 0,
    estimatedTime: 0,
  );
}

RouteModel _route(List<PathNode> path) {
  return RouteModel(
    path: path,
    totalDistance: 100,
    estimatedTime: 70,
    congestionLevel: 0,
    warnings: const [],
  );
}

void main() {
  group('RouteTracker reroute behavior', () {
    final nodes = <NodeModel>[
      _node('n0', -8.630000, 41.160000),
      _node('n1', -8.629900, 41.160000),
      _node('n2', -8.629800, 41.160000),
      _node('n3', -8.629700, 41.160000),
    ];

    final route = _route([
      _pathNode('n0', -8.630000, 41.160000),
      _pathNode('n1', -8.629900, 41.160000),
      _pathNode('n2', -8.629800, 41.160000),
      _pathNode('n3', -8.629700, 41.160000),
    ]);

    test('seedUserPositionForNewRoute clamps waypoint index', () {
      final tracker = RouteTracker(route: route, allNodes: nodes);

      tracker.seedUserPositionForNewRoute(
        -8.629750,
        41.160000,
        level: 0,
        waypointIndex: 99,
      );

      expect(tracker.currentWaypointIndex, route.waypoints.length - 1);
      expect(tracker.currentX, -8.629750);
      expect(tracker.currentY, 41.160000);
      expect(tracker.currentLevel, 0);
    });

    test('seed near current position advances forward after update', () {
      final tracker = RouteTracker(route: route, allNodes: nodes);

      // Simula reroute com início já próximo de n2.
      tracker.seedUserPositionForNewRoute(
        -8.629805,
        41.160000,
        level: 0,
        waypointIndex: 2,
      );

      tracker.updateUserPosition(-8.629805, 41.160000, level: 0);

      expect(tracker.currentWaypointIndex, greaterThanOrEqualTo(2));
      expect(tracker.currentWaypointIndex, lessThanOrEqualTo(3));
    });

    test('does not jump backwards to earlier waypoint after reroute', () {
      final tracker = RouteTracker(route: route, allNodes: nodes);

      tracker.seedUserPositionForNewRoute(
        -8.629805,
        41.160000,
        level: 0,
        waypointIndex: 2,
      );

      // Mesmo que o GPS oscile para trás, o índice não deve regredir.
      tracker.updateUserPosition(-8.629900, 41.160000, level: 0);

      expect(tracker.currentWaypointIndex, greaterThanOrEqualTo(2));
    });

    test('caps forward progress to one waypoint per update', () {
      final tracker = RouteTracker(route: route, allNodes: nodes);

      tracker.seedUserPositionForNewRoute(
        -8.630000,
        41.160000,
        level: 0,
        waypointIndex: 0,
      );

      // Está muito perto de vários waypoints no mesmo eixo.
      tracker.updateUserPosition(-8.629850, 41.160000, level: 0);

      expect(tracker.currentWaypointIndex, lessThanOrEqualTo(1));
    });
  });
}
