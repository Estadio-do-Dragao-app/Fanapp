import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../../core/services/mqtt_service.dart';
import '../../../../core/config/api_config.dart';

/// Service that caches wait times from MQTT updates or HTTP polling
/// Use WaittimeCache.getWaitTime(poiId) to get latest value
class WaittimeCache extends ChangeNotifier {
  static final WaittimeCache _instance = WaittimeCache._internal();
  factory WaittimeCache() => _instance;
  WaittimeCache._internal();

  final MqttService _mqttService = MqttService();
  StreamSubscription? _subscription;
  Timer? _pollTimer;
  bool _isListening = false;

  // Cache: poi_id -> wait_minutes
  final Map<String, double> _cache = {};

  /// Start listening to MQTT wait time updates or HTTP polling
  void start() {
    print('[WaittimeCache] start() called. isWeb=$kIsWeb, isListening=$_isListening');
    if (_isListening) {
      print('[WaittimeCache] Already listening, skipping');
      return;
    }
    
    if (kIsWeb) {
      // Start HTTP Polling for Web platform where MQTT TCP is unsupported
      print('[WaittimeCache] 🌐 Web platform detected: Using HTTP polling fallback');
      _fetchWaitTimes(); // Initial fetch
      _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) => _fetchWaitTimes());
    } else {
      // Subscribe to MQTT stream for Mobile platforms
      _subscription = _mqttService.queuesStream.listen(
        _onWaittimeUpdate,
        onError: (e) => print('[WaittimeCache] Stream error: $e'),
        onDone: () => print('[WaittimeCache] Stream done'),
      );
    }
    
    _isListening = true;
    print('[WaittimeCache] ✅ Now listening to waittime updates');
  }

  Future<void> _fetchWaitTimes() async {
    try {
      final url = Uri.parse('${ApiConfig.waitTimeService}/api/waittime/all');
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        bool changed = false;
        
        for (var item in data) {
          final poiId = item['poi_id'] as String?;
          final minutes = item['wait_minutes'];
          
          if (poiId != null && minutes != null) {
            final double val = (minutes is int) ? minutes.toDouble() : minutes as double;
            if (_cache[poiId] != val) {
              _cache[poiId] = val;
              changed = true;
            }
          }
        }
        
        if (changed) {
          print('[WaittimeCache] HTTP Polling: Updated data for ${_cache.length} POIs');
          notifyListeners();
        }
      }
    } catch (e) {
      print('[WaittimeCache] HTTP Polling error: $e');
    }
  }

  void _onWaittimeUpdate(Map<String, dynamic> data) {
    // Format from WaitTime-Service MQTT: {type, poi, minutes, ci95, status, queue_length, ts}
    final poiId = data['poi'] as String?;
    final minutes = data['minutes'];

    if (poiId != null && minutes != null) {
      _cache[poiId] = (minutes is int) ? minutes.toDouble() : minutes as double;
      print('[WaittimeCache] MQTT Updated $poiId: ${_cache[poiId]} min');
      notifyListeners();
    }
  }

  /// Get cached wait time for a POI (null if not available)
  double? getWaitTime(String poiId) => _cache[poiId];

  /// Get all cached wait times
  Map<String, double> get allWaitTimes => Map.unmodifiable(_cache);

  /// Stop listening
  @override
  void dispose() {
    _subscription?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  void stop() {
    _subscription?.cancel();
    _pollTimer?.cancel();
    _isListening = false;
  }
}
