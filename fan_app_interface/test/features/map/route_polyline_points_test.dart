import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:fan_app_interface/features/map/data/models/route_model.dart';
import 'package:fan_app_interface/features/map/data/models/node_model.dart';

typedef LatLngConvert = LatLng Function(double x, double y);

List<LatLng> buildRoutePoints({
  required RouteModel route,
  required Map<String, NodeModel> nodesMap,
  required LatLng? head,
  required int startIndex,
  required bool isNavigating,
  required LatLngConvert convert,
}) {
  final points = <LatLng>[];

  final start = isNavigating ? startIndex.clamp(0, route.waypoints.length) : 0;

  if (isNavigating && head != null) {
    points.add(head);
  }

  for (int i = start; i < route.waypoints.length; i++) {
    final wp = route.waypoints[i];
    final node = nodesMap[wp.nodeId];
    points.add(convert(node?.x ?? wp.x, node?.y ?? wp.y));
  }

  return points;
}
PathNode _wp(String id) => PathNode(
      nodeId: id,
      x: 0,
      y: 0,
      level: 0,
      distanceFromStart: 0,
      estimatedTime: 0,
    );

NodeModel _node(String id, double x, double y) => NodeModel(
      id: id,
      x: x,
      y: y,
      level: 0,
      type: 'node',
    );

RouteModel _route(List<String> ids) => RouteModel(
      path: ids.map(_wp).toList(),
      totalDistance: 0,
      estimatedTime: 0,
      congestionLevel: 0,
      warnings: const [],
    );

LatLng _identity(double x, double y) => LatLng(y, x);

void main() {
  group('buildRoutePoints (Task 2 / Fix: dynamic edge + smooth consumption)',
      () {
    final nodesMap = {
      'n0': _node('n0', 10, 20),
      'n1': _node('n1', 11, 21),
      'n2': _node('n2', 12, 22),
      'n3': _node('n3', 13, 23),
    };
    final route = _route(['n0', 'n1', 'n2', 'n3']);

    test('out of navigation: emits every waypoint, no head', () {
      final points = buildRoutePoints(
        route: route,
        nodesMap: nodesMap,
        head: LatLng(99, 99),
        startIndex: 0,
        isNavigating: false,
        convert: _identity,
      );
      expect(points.length, 4);
      expect(points.first, LatLng(20, 10)); // n0 (y=20, x=10)
      expect(points.last, LatLng(23, 13));
    });

    test('navigating with head: head is the FIRST point, before waypoints',
        () {
      // Sintoma 1: traço deve nascer no head (raw GPS or smooth pos), not
      // at the nearest node.
      final head = LatLng(20.123, 10.456);
      final points = buildRoutePoints(
        route: route,
        nodesMap: nodesMap,
        head: head,
        startIndex: 1, // user is on segment [n1 → n2], keep n1
        isNavigating: true,
        convert: _identity,
      );
      expect(points.first, head);
      // Polyline: [head, n1, n2, n3]
      expect(points.length, 4);
      expect(points[1], LatLng(21, 11));
      expect(points[2], LatLng(22, 12));
      expect(points[3], LatLng(23, 13));
    });

    test('navigating, startIndex skips consumed waypoints (t > 0.5 case)',
        () {
      // After the user passes the midpoint of segment [n1→n2], the controller
      // returns startIndex = 2 (skip n1) so the head→n2 segment is a single
      // straight line. Regression lock for the "no backwards mini-segment"
      // rule (polylineStartIndex policy).
      final head = LatLng(20.9, 10.9);
      final points = buildRoutePoints(
        route: route,
        nodesMap: nodesMap,
        head: head,
        startIndex: 2,
        isNavigating: true,
        convert: _identity,
      );
      expect(points.first, head);
      expect(points.length, 3);
      expect(points[1], LatLng(22, 12)); // n2
      expect(points[2], LatLng(23, 13)); // n3
    });

    test('navigating without head: skips the head and just emits waypoints',
        () {
      final points = buildRoutePoints(
        route: route,
        nodesMap: nodesMap,
        head: null,
        startIndex: 1,
        isNavigating: true,
        convert: _identity,
      );
      // Polyline: [n1, n2, n3] — no head prepended.
      expect(points.length, 3);
      expect(points.first, LatLng(21, 11));
    });

    test('startIndex is clamped to route length (defensive)', () {
      // If the tracker over-reports the segment index near the end of the
      // route, we must not crash with a RangeError.
      final head = LatLng(99, 99);
      final points = buildRoutePoints(
        route: route,
        nodesMap: nodesMap,
        head: head,
        startIndex: 999,
        isNavigating: true,
        convert: _identity,
      );
      expect(points, [head]); // only the head, no waypoints to emit
    });

    test('waypoint without matching node falls back to wp.x/y', () {
      // If a node-id is missing from nodesMap (e.g. mid-reroute race), the
      // polyline must still render using the waypoint's own coordinates
      // rather than dropping the point.
      final routeWithUnknown = RouteModel(
        path: [
          PathNode(nodeId: 'unknown', x: 5, y: 6, level: 0,
              distanceFromStart: 0, estimatedTime: 0),
          PathNode(nodeId: 'n1', x: 0, y: 0, level: 0,
              distanceFromStart: 0, estimatedTime: 0),
        ],
        totalDistance: 0,
        estimatedTime: 0,
        congestionLevel: 0,
        warnings: const [],
      );
      final points = buildRoutePoints(
        route: routeWithUnknown,
        nodesMap: nodesMap,
        head: null,
        startIndex: 0,
        isNavigating: false,
        convert: _identity,
      );
      expect(points.first, LatLng(6, 5)); // wp.x=5, wp.y=6
      expect(points[1], LatLng(21, 11)); // n1 from map
    });
  });
}
