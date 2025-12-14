import 'dart:async';
import '../../../../core/services/mqtt_service.dart';

/// Service that caches wait times from MQTT updates
/// Use WaittimeCache.getWaitTime(poiId) to get latest value
class WaittimeCache {
  static final WaittimeCache _instance = WaittimeCache._internal();
  factory WaittimeCache() => _instance;
  WaittimeCache._internal();

  final MqttService _mqttService = MqttService();
  StreamSubscription? _subscription;
  bool _isListening = false;

  // Cache: poi_id -> wait_minutes
  final Map<String, double> _cache = {};

  /// Start listening to MQTT wait time updates
  Future<void> start() async {
    if (_isListening) return;

    print('[WaittimeCache] Attempting MQTT connection...');
    final connected = await _mqttService.connect();
    print('[WaittimeCache] MQTT connected: $connected');
    
    if (connected) {
      _subscription = _mqttService.queuesStream.listen(_onWaittimeUpdate);
      _isListening = true;
      print('[WaittimeCache] Started listening to waittime updates');
    } else {
      print('[WaittimeCache] MQTT connection failed - wait times from API only');
    }
  }

  void _onWaittimeUpdate(Map<String, dynamic> data) {
    // Format from WaitTime-Service: {type, poi, minutes, ci95, status, queue_length, ts}
    final poiId = data['poi'] as String?;
    final minutes = data['minutes'];

    if (poiId != null && minutes != null) {
      _cache[poiId] = (minutes is int) ? minutes.toDouble() : minutes as double;
      print('[WaittimeCache] Updated $poiId: ${_cache[poiId]} min');
    }
  }

  /// Get cached wait time for a POI (null if not available)
  double? getWaitTime(String poiId) => _cache[poiId];

  /// Get all cached wait times
  Map<String, double> get allWaitTimes => Map.unmodifiable(_cache);

  /// Stop listening
  void stop() {
    _subscription?.cancel();
    _isListening = false;
  }
}
