import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import 'mqtt_service.dart';

/// Service for anonymous GPS tracking
class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  static const String _keyUserId = 'anonymous_user_id';
  String? _userId;
  Timer? _timer;
  bool _isTracking = false;
  bool _isUpdating = false;

  /// Initializes the service and creates an in-memory anonymous ID for this session
  Future<void> init() async {
    // Generate a new anonymous ID for each app session without persisting it
    _userId = const Uuid().v4();
    print('[LocationService] Generated new session anonymous ID: $_userId');
  }

  /// Starts periodic GPS tracking and publishing to MQTT
  Future<void> startTracking() async {
    if (_isTracking) return;

    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('[LocationService] Location services are disabled.');
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print('[LocationService] Location permissions are denied');
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      print('[LocationService] Location permissions are permanently denied.');
      return;
    }

    _isTracking = true;
    print('[LocationService] Tracking started');

    // Initial position
    _updateAndPublish();

    // Periodic updates every 10 seconds
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _updateAndPublish();
    });
  }

  /// Stops tracking
  void stopTracking() {
    _timer?.cancel();
    _isTracking = false;
    print('[LocationService] Tracking stopped');
  }

  /// Gets current position and publishes to MQTT anonymously
  Future<void> _updateAndPublish() async {
    if (!_isTracking || _userId == null) return;
    if (_isUpdating) return;

    _isUpdating = true;
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );

      print('[LocationService] Position updated');
      
      // Publish to MQTT
      MqttService().publishLocation(
        _userId!,
        position.latitude,
        position.longitude,
      );
    } catch (e) {
      print('[LocationService] Error getting position: $e');
    } finally {
      _isUpdating = false;
    }
  }

  bool get isTracking => _isTracking;
}
