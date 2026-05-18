import 'package:flutter_test/flutter_test.dart';
import 'package:fan_app_interface/features/map/data/models/route_model.dart';

void main() {
  group('Coordinates', () {
    test('toJson serializes x, y, level', () {
      final coords = Coordinates(x: 1.5, y: 2.5, level: 1);
      final json = coords.toJson();
      expect(json['x'], 1.5);
      expect(json['y'], 2.5);
      expect(json['level'], 1);
    });

    test('default level is 0', () {
      final coords = Coordinates(x: 0.0, y: 0.0);
      expect(coords.level, 0);
    });
  });

  group('RouteRequest', () {
    test('toJson serializes all fields', () {
      final request = RouteRequest(
        start: Coordinates(x: 10.0, y: 20.0, level: 1),
        destinationType: 'poi',
        destinationId: 'toilet-1',
        avoidStairs: true,
      );
      final json = request.toJson();
      expect(json['destination_type'], 'poi');
      expect(json['destination_id'], 'toilet-1');
      expect(json['avoid_stairs'], true);
      expect(json['start'], isA<Map>());
    });

    test('avoidStairs defaults to false', () {
      final request = RouteRequest(
        start: Coordinates(x: 0.0, y: 0.0),
        destinationType: 'node',
        destinationId: 'N1',
      );
      expect(request.avoidStairs, false);
    });
  });

  group('PathNode', () {
    group('fromJson', () {
      test('parses node_id field', () {
        final json = {
          'node_id': 'N1',
          'x': 10.0,
          'y': 20.0,
          'level': 1,
          'distance_from_start': 5.0,
          'estimated_time': 3.0,
        };
        final node = PathNode.fromJson(json);
        expect(node.nodeId, 'N1');
        expect(node.x, 10.0);
        expect(node.y, 20.0);
        expect(node.level, 1);
        expect(node.distanceFromStart, 5.0);
        expect(node.estimatedTime, 3.0);
      });

      test('falls back to id field when node_id missing', () {
        final json = {'id': 'N2', 'x': 0.0, 'y': 0.0};
        final node = PathNode.fromJson(json);
        expect(node.nodeId, 'N2');
      });

      test('handles missing fields with defaults', () {
        final node = PathNode.fromJson({});
        expect(node.nodeId, 'unknown_node');
        expect(node.x, 0.0);
        expect(node.y, 0.0);
        expect(node.level, 0);
        expect(node.distanceFromStart, 0.0);
        expect(node.estimatedTime, 0.0);
      });
    });

    group('toJson', () {
      test('serializes all fields', () {
        final node = PathNode(
          nodeId: 'N3',
          x: 5.0,
          y: 6.0,
          level: 2,
          distanceFromStart: 10.0,
          estimatedTime: 7.0,
        );
        final json = node.toJson();
        expect(json['node_id'], 'N3');
        expect(json['x'], 5.0);
        expect(json['y'], 6.0);
        expect(json['level'], 2);
        expect(json['distance_from_start'], 10.0);
        expect(json['estimated_time'], 7.0);
      });
    });

    test('type getter returns "node"', () {
      final node = PathNode(nodeId: 'N1', x: 0, y: 0, level: 0, distanceFromStart: 0, estimatedTime: 0);
      expect(node.type, 'node');
    });
  });

  group('RouteModel', () {
    PathNode _makeNode(String id) => PathNode(
      nodeId: id, x: 0, y: 0, level: 0, distanceFromStart: 0, estimatedTime: 0);

    group('fromJson', () {
      test('parses standard fields', () {
        final json = {
          'path': [
            {'node_id': 'N1', 'x': 0.0, 'y': 0.0, 'level': 0},
            {'node_id': 'N2', 'x': 5.0, 'y': 5.0, 'level': 0},
          ],
          'total_distance': 10.0,
          'estimated_time': 7.0,
          'congestion_level': 0.3,
          'wait_time': 2.5,
          'warnings': ['Slow area'],
        };
        final route = RouteModel.fromJson(json);
        expect(route.path.length, 2);
        expect(route.totalDistance, 10.0);
        expect(route.estimatedTime, 7.0);
        expect(route.congestionLevel, 0.3);
        expect(route.waitTime, 2.5);
        expect(route.warnings, ['Slow area']);
      });

      test('negative distance is clamped to 0', () {
        final route = RouteModel.fromJson({'path': [], 'distance': -5.0, 'duration': 0.0});
        expect(route.totalDistance, 0.0);
      });

      test('negative time is clamped to 0', () {
        final route = RouteModel.fromJson({'path': [], 'distance': 0.0, 'duration': -3.0});
        expect(route.estimatedTime, 0.0);
      });

      test('accepts "distance" alias for total_distance', () {
        final route = RouteModel.fromJson({'path': [], 'distance': 42.0, 'duration': 0.0});
        expect(route.totalDistance, 42.0);
      });

      test('accepts "duration" alias for estimated_time', () {
        final route = RouteModel.fromJson({'path': [], 'distance': 0.0, 'duration': 15.0});
        expect(route.estimatedTime, 15.0);
      });

      test('missing wait_time is null', () {
        final route = RouteModel.fromJson({'path': [], 'distance': 0.0, 'duration': 0.0});
        expect(route.waitTime, isNull);
      });

      test('missing warnings defaults to empty list', () {
        final route = RouteModel.fromJson({'path': [], 'distance': 0.0, 'duration': 0.0});
        expect(route.warnings, isEmpty);
      });

      test('missing path defaults to empty list', () {
        final route = RouteModel.fromJson({'distance': 0.0, 'duration': 0.0});
        expect(route.path, isEmpty);
      });
    });

    group('toJson', () {
      test('serializes all fields', () {
        final route = RouteModel(
          path: [_makeNode('N1')],
          totalDistance: 20.0,
          estimatedTime: 14.0,
          congestionLevel: 0.5,
          waitTime: 3.0,
          warnings: ['High traffic'],
        );
        final json = route.toJson();
        expect(json['total_distance'], 20.0);
        expect(json['estimated_time'], 14.0);
        expect(json['congestion_level'], 0.5);
        expect(json['wait_time'], 3.0);
        expect(json['warnings'], ['High traffic']);
        expect((json['path'] as List).length, 1);
      });

      test('wait_time can be null in toJson', () {
        final route = RouteModel(
          path: [],
          totalDistance: 0,
          estimatedTime: 0,
          congestionLevel: 0,
          warnings: [],
        );
        final json = route.toJson();
        expect(json['wait_time'], isNull);
      });
    });

    group('compatibility getters', () {
      test('waypoints is alias for path', () {
        final node = _makeNode('N1');
        final route = RouteModel(
          path: [node],
          totalDistance: 5.0,
          estimatedTime: 3.0,
          congestionLevel: 0.0,
          warnings: [],
        );
        expect(route.waypoints, equals(route.path));
      });

      test('distance is alias for totalDistance', () {
        final route = RouteModel(
          path: [],
          totalDistance: 99.5,
          estimatedTime: 0,
          congestionLevel: 0,
          warnings: [],
        );
        expect(route.distance, 99.5);
      });

      test('etaSeconds rounds estimatedTime', () {
        final route = RouteModel(
          path: [],
          totalDistance: 0,
          estimatedTime: 14.7,
          congestionLevel: 0,
          warnings: [],
        );
        expect(route.etaSeconds, 15);
      });

      test('etaSeconds rounds down correctly', () {
        final route = RouteModel(
          path: [],
          totalDistance: 0,
          estimatedTime: 14.2,
          congestionLevel: 0,
          warnings: [],
        );
        expect(route.etaSeconds, 14);
      });
    });

    group('copy', () {
      test('creates new instance with same data', () {
        final original = RouteModel(
          path: [_makeNode('N1'), _makeNode('N2')],
          totalDistance: 30.0,
          estimatedTime: 20.0,
          congestionLevel: 0.2,
          waitTime: 1.5,
          warnings: ['Info'],
        );
        final copy = original.copy();

        expect(copy.path.length, 2);
        expect(copy.totalDistance, 30.0);
        expect(copy.estimatedTime, 20.0);
        expect(copy.congestionLevel, 0.2);
        expect(copy.waitTime, 1.5);
        expect(copy.warnings, ['Info']);
      });

      test('copy has different path list identity', () {
        final original = RouteModel(
          path: [_makeNode('N1')],
          totalDistance: 0,
          estimatedTime: 0,
          congestionLevel: 0,
          warnings: [],
        );
        final copy = original.copy();
        expect(identical(original.path, copy.path), isFalse);
      });
    });
  });

  group('WaypointModel typedef', () {
    test('WaypointModel is alias for PathNode', () {
      final node = WaypointModel(
        nodeId: 'W1',
        x: 1.0,
        y: 2.0,
        level: 0,
        distanceFromStart: 0,
        estimatedTime: 0,
      );
      expect(node.nodeId, 'W1');
    });
  });
}
