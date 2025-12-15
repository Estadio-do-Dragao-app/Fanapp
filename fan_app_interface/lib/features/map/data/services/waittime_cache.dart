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
  /// Does not initiate connection - just subscribes to stream
  void start() {
    print('[WaittimeCache] start() called. isListening=$_isListening');
    if (_isListening) {
      print('[WaittimeCache] Already listening, skipping');
      return;
    }
    
    // Subscribe to stream - MqttService handles connection elsewhere
    _subscription = _mqttService.queuesStream.listen(
      _onWaittimeUpdate,
      onError: (e) => print('[WaittimeCache] Stream error: $e'),
      onDone: () => print('[WaittimeCache] Stream done'),
    );
    _isListening = true;
    print('[WaittimeCache] ✅ Now listening to waittime stream');
  }

  void _onWaittimeUpdate(Map<String, dynamic> data) {
    // Format from WaitTime-Service: {type, poi, minutes, ci95, status, queue_length, ts}
    final poiId = data['poi'] as String?;
    final minutes = data['minutes'];

    if (poiId != null && minutes != null) {
      _cache[poiId] = (minutes is int) ? minutes.toDouble() : minutes as double;
      print('[WaittimeCache] Updated $poiId: ${_cache[poiId]} min (total: ${_cache.length} POIs)');
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
