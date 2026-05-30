import 'package:flutter_test/flutter_test.dart';
import 'package:fan_app_interface/features/navigation/domain/navigation_controller.dart';

void main() {
  group('computePolylineStartIndex (Task 2 / Risco B regression lock)', () {
    test('t ≤ 0.5 keeps the current waypoint (no backwards mini-segment)', () {
      // Head is still before the midpoint of [wp[2]→wp[3]], so the head→wp[2]
      // segment is forward-going and we keep wp[2] as a vertex.
      expect(
        computePolylineStartIndex(
          currentWaypointIndex: 2,
          tOnCurrentSegment: 0.0,
          freeRoamActive: false,
          waypointCount: 10,
        ),
        2,
      );
      expect(
        computePolylineStartIndex(
          currentWaypointIndex: 2,
          tOnCurrentSegment: 0.5,
          freeRoamActive: false,
          waypointCount: 10,
        ),
        2,
      );
    });

    test('t > 0.5 skips the current waypoint (avoid backwards kink)', () {
      // Past the midpoint of the current segment → head is closer to wp[3]
      // than wp[2], so prepending head + keeping wp[2] would draw a small
      // backwards-then-forward zig-zag.
      expect(
        computePolylineStartIndex(
          currentWaypointIndex: 2,
          tOnCurrentSegment: 0.51,
          freeRoamActive: false,
          waypointCount: 10,
        ),
        3,
      );
    });

    test('free-roam always skips, regardless of t', () {
      // In free-roam the user is off the route geometry. Drawing head→wp[idx]
      // would draw a sideways stub. Always advance past the current waypoint.
      expect(
        computePolylineStartIndex(
          currentWaypointIndex: 4,
          tOnCurrentSegment: 0.1,
          freeRoamActive: true,
          waypointCount: 10,
        ),
        5,
      );
    });

    test('result is clamped to waypointCount (no RangeError at end of route)',
        () {
      // If the tracker over-reports the index near the end of the route, the
      // clamp prevents downstream code from doing waypoints[idx] OOB.
      expect(
        computePolylineStartIndex(
          currentWaypointIndex: 9,
          tOnCurrentSegment: 0.9, // skip → 10
          freeRoamActive: false,
          waypointCount: 10,
        ),
        10,
      );
      expect(
        computePolylineStartIndex(
          currentWaypointIndex: 99,
          tOnCurrentSegment: 0.9,
          freeRoamActive: false,
          waypointCount: 5,
        ),
        5,
      );
    });

    test('empty route is handled without crashing', () {
      expect(
        computePolylineStartIndex(
          currentWaypointIndex: 0,
          tOnCurrentSegment: 0.0,
          freeRoamActive: false,
          waypointCount: 0,
        ),
        0,
      );
    });
  });
}
