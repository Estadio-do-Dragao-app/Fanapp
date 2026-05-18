import 'package:geolocator/geolocator.dart';

/// Centralized service to handle location permissions and checks
class PermissionService {
  /// Checks and requests location permission. Returns true if granted.
  static Future<bool> ensureLocationPermission() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('[PermissionService] Location services are disabled.');
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('[PermissionService] Location permissions are denied');
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('[PermissionService] Location permissions are permanently denied');
        return false;
      }

      return true;
    } catch (e) {
      print('[PermissionService] Location service check failed (unsupported platform?): $e');
      return false;
    }
  }
}
