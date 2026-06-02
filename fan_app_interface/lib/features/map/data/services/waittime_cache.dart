import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../../core/services/mqtt_service.dart';
import '../../../../core/config/api_config.dart';
import '../../../../core/config/app_env.dart';
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

  // Cache: poi_id -> queue_length (number of people)
  final Map<String, int> _queueLengthCache = {};

  /// Start listening to MQTT wait time updates or HTTP polling
  void start() {
    debugPrint('[WaittimeCache] start() called. isWeb=$kIsWeb, isListening=$_isListening');
    if (_isListening) {
      debugPrint('[WaittimeCache] Already listening, skipping');
      return;
    }
    
    if (kIsWeb) {
      // Start HTTP Polling for Web platform where MQTT TCP is unsupported
      debugPrint('[WaittimeCache] Web platform detected: Using HTTP polling fallback');
      _fetchWaitTimes(); // Initial fetch
      _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) => _fetchWaitTimes());
    } else {
      // Subscribe to MQTT stream for Mobile platforms
      _subscription = _mqttService.queuesStream.listen(
        _onWaittimeUpdate,
        onError: (e) => debugPrint('[WaittimeCache] Stream error: $e'),
        onDone: () => debugPrint('[WaittimeCache] Stream done'),
      );
    }
    
    _isListening = true;
    debugPrint('[WaittimeCache] Now listening to waittime updates');
  }

  Future<void> _fetchWaitTimes() async {
    try {
      final url = Uri.parse('${ApiConfig.waitTimeService}/api/waittime/all');
      final response = await http.get(
        url,
        headers: {'X-API-Key': AppEnv.mapApiKey},
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        bool changed = false;
        
        for (var item in data) {
          final poiId = item['poi_id'] as String?;
          final minutes = item['wait_minutes'];
          final queueLen = item['queue_length'];

          if (poiId != null && minutes != null) {
            final double val = (minutes is int) ? minutes.toDouble() : minutes as double;
            if (_cache[poiId] != val) {
              _cache[poiId] = val;
              changed = true;
            }
            if (queueLen != null) {
              final int len = (queueLen is int) ? queueLen : (queueLen as num).toInt();
              if (_queueLengthCache[poiId] != len) {
                _queueLengthCache[poiId] = len;
                changed = true;
              }
            }
          }
        }
        
        if (changed) {
          debugPrint('[WaittimeCache] HTTP Polling: Updated data for ${_cache.length} POIs');
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('[WaittimeCache] HTTP Polling error: $e');
    }
  }

  Timer? _notifyTimer;

  void _onWaittimeUpdate(Map<String, dynamic> data) {
    // Format from WaitTime-Service MQTT: {type, poi, minutes, ci95, status, queue_length, ts}
    final poiId = data['poi'] as String?;
    final minutes = data['minutes'];
    final queueLen = data['queue_length'];

    if (poiId != null && minutes != null) {
      _cache[poiId] = (minutes is int) ? minutes.toDouble() : minutes as double;
      
      // Throttle UI updates to once per second
      if (_notifyTimer == null || !_notifyTimer!.isActive) {
        _notifyTimer = Timer(const Duration(seconds: 1), () {
          notifyListeners();
        });
      }
    }
  }

  /// Get cached wait time for a POI (null if not available)
  double? getWaitTime(String poiId) => _cache[poiId];

  /// Get cached queue length (number of people) for a POI (null if not available)
  int? getQueueLength(String poiId) => _queueLengthCache[poiId];

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
    _notifyTimer?.cancel();
    _isListening = false;
  }
}
