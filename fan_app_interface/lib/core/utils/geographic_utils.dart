import 'package:latlong2/latlong.dart';

import 'package:geolocator/geolocator.dart';
import '../../features/navigation/data/services/user_position_service.dart';

class GeographicUtils {
  static const Distance _distanceCalculator = Distance();
  // Default starting position (temporary test mode)
  /*
  static const double _defaultStartX = -8.6591;
  static const double _defaultStartY = 40.6342;
  static const int _defaultStartLevel = 0;
  */
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
    double px,
    double py,
    double x1,
    double y1,
    double x2,
    double y2,
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
    double px,
    double py,
    double x1,
    double y1,
    double x2,
    double y2,
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

  /// Gets the real GPS position of the user, falling back to saved position if existent
  static Future<({double x, double y, int level})?>
  getCurrentUserPosition() async {
    
    
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied');
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      );

      return (x: position.longitude, y: position.latitude, level: 0);
    } catch (e) {
      print('[GeographicUtils] GPS not available: $e');
      // GPS is disabled or unavailable - do NOT fallback to saved position
      // This ensures old positions are not used when GPS is intentionally turned off
      return null;
    }
  
    // For now we force a fixed origin so route calculation always starts
    // from the same known point during testing.
    //return (x: _defaultStartX, y: _defaultStartY, level: _defaultStartLevel);
  }
}
