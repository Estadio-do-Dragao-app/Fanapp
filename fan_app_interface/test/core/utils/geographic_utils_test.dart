import 'package:flutter_test/flutter_test.dart';
import 'package:fan_app_interface/core/utils/geographic_utils.dart';

void main() {
  group('GeographicUtils', () {
    group('calculateDistance', () {
      test('distance between identical points is zero', () {
        final d = GeographicUtils.calculateDistance(41.16, -8.63, 41.16, -8.63);
        expect(d, 0.0);
      });

      test('distance between two known points is approximately correct', () {
        // Porto Estádio do Dragão roughly 1km apart (approximate)
        final d = GeographicUtils.calculateDistance(41.1619, -8.5836, 41.1619, -8.5736);
        expect(d, greaterThan(0));
        expect(d, lessThan(2000)); // sanity bound
      });

      test('distance is symmetric', () {
        final d1 = GeographicUtils.calculateDistance(41.16, -8.63, 41.17, -8.64);
        final d2 = GeographicUtils.calculateDistance(41.17, -8.64, 41.16, -8.63);
        expect((d1 - d2).abs(), lessThan(0.001));
      });

      test('distance is always non-negative', () {
        final d = GeographicUtils.calculateDistance(0, 0, -90, -180);
        expect(d, greaterThanOrEqualTo(0));
      });
    });

    group('pointToSegmentDistance', () {
      test('point on segment returns near-zero distance', () {
        // Midpoint of segment from (0,0) to (0,10) is (0,5)
        final d = GeographicUtils.pointToSegmentDistance(
          0, 5,
          0, 0,
          0, 10,
        );
        expect(d, lessThan(1.0));
      });

      test('point perpendicular to segment returns positive distance', () {
        final d = GeographicUtils.pointToSegmentDistance(
          5, 5,
          0, 0,
          10, 0,
        );
        expect(d, greaterThan(0));
      });

      test('degenerate segment (a == b) returns distance to point', () {
        final d = GeographicUtils.pointToSegmentDistance(
          3, 4,
          0, 0,
          0, 0,
        );
        expect(d, greaterThan(0));
      });
    });

    group('metersToDegrees', () {
      test('converts meters to degrees approximately', () {
        final deg = GeographicUtils.metersToDegrees(111320);
        expect(deg, closeTo(1.0, 0.001));
      });
    });
  });
}