import 'dart:math' as math;
import 'package:latlong2/latlong.dart';

class GeographicUtils {
  static const Distance _distanceCalculator = Distance();

  /// Calculates the distance in meters between two points (x=Lng, y=Lat)
  static double calculateDistance(double x1, double y1, double x2, double y2) {
    return _distanceCalculator.as(
      LengthUnit.Meter,
      LatLng(y1, x1),
      LatLng(y2, x2),
    );
  }

  /// Calculates the distance from a point to a segment (all in GPS coordinates)
  /// Returns distance in METERS
  static double pointToSegmentDistance(
    double px, double py,
    double x1, double y1,
    double x2, double y2,
  ) {
    // For path tracking, we use a hybrid approach:
    // 1. Project the point onto the segment in the coordinate plane (degrees)
    // 2. Calculate the Haversine distance from the point to that projection
    
    final segLenSq = (x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1);
    
    if (segLenSq < 1e-12) {
      return calculateDistance(px, py, x1, y1);
    }

    double t = ((px - x1) * (x2 - x1) + (py - y1) * (y2 - y1)) / segLenSq;
    t = t.clamp(0.0, 1.0);

    final projX = x1 + t * (x2 - x1);
    final projY = y1 + t * (y2 - y1);

    return calculateDistance(px, py, projX, projY);
  }

  /// Calculates progress (0.0 to 1.0) along a segment
  static double progressAlongSegment(
    double px, double py,
    double x1, double y1,
    double x2, double y2,
  ) {
    final segLenSq = (x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1);
    if (segLenSq < 1e-12) return 1.0;

    final t = ((px - x1) * (x2 - x1) + (py - y1) * (y2 - y1)) / segLenSq;
    return t;
  }

  /// Converts meters to degrees (approximation for Latitude/Longitude)
  /// 1 degree is roughly 111,320 meters
  static double metersToDegrees(double meters) {
    return meters / 111320.0;
  }
}
