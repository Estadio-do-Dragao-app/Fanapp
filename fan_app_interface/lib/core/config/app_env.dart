import 'package:flutter/foundation.dart';

/// Centralized Environment Configuration
/// Reads values from --dart-define or defaults to safe fallbacks.
class AppEnv {
  // ==================== ENDPOINTS ====================
  
  /// Base API URL (e.g., http://10.255.32.58)
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.255.32.58',
  );

  /// Map Service URL
  static String get mapServiceUrl => '$apiBaseUrl:8000';
  
  /// Routing Service URL
  static String get routingServiceUrl => '$apiBaseUrl:8002';
  
  /// Wait Time Service URL
  static String get waitTimeServiceUrl => '$apiBaseUrl:8001';

  // ==================== MQTT CONFIG ====================
  
  /// MQTT Broker IP (without http://)
  static String get mqttBroker => apiBaseUrl.replaceAll('http://', '').replaceAll('https://', '');
  
  static const int mqttPort = int.fromEnvironment('MQTT_PORT', defaultValue: 1883);
  static const int mqttWebSocketPort = int.fromEnvironment('MQTT_WS_PORT', defaultValue: 9002);
  
  static const String mqttClientId = String.fromEnvironment('MQTT_CLIENT_ID', defaultValue: 'fanapp_flutter');

  // MQTT Topics
  static const String topicAllEvents = String.fromEnvironment('TOPIC_ALL_EVENTS', defaultValue: 'stadium/events/all');
  static const String topicCongestion = String.fromEnvironment('TOPIC_CONGESTION', defaultValue: 'stadium/services/congestion');
  static const String topicQueues = String.fromEnvironment('TOPIC_QUEUES', defaultValue: 'stadium/services/waittime/#');
  static const String topicMaintenance = String.fromEnvironment('TOPIC_MAINTENANCE', defaultValue: 'stadium/events/maintenance');
  static const String topicSecurity = String.fromEnvironment('TOPIC_SECURITY', defaultValue: 'stadium/events/security');
  static const String topicAlerts = String.fromEnvironment('TOPIC_ALERTS', defaultValue: 'alerts/broadcast');
  static const String topicRouting = String.fromEnvironment('TOPIC_ROUTING', defaultValue: 'stadium/services/routing/#');
  static const String topicGps = String.fromEnvironment('TOPIC_GPS', defaultValue: 'stadium/location/gps');

  // ==================== SECURITY ====================
  
  /// API Key for authenticated requests
  static const String mapApiKey = String.fromEnvironment(
    'MAP_API_KEY',
    defaultValue: '', // Must be provided via --dart-define
  );

  // ==================== MAP CONSTANTS ====================
  
  static const String _mapCenterLatStr = String.fromEnvironment('MAP_CENTER_LAT', defaultValue: '40.6300');
  static double get mapCenterLat => double.tryParse(_mapCenterLatStr) ?? 40.6300;
  
  static const String _mapCenterLngStr = String.fromEnvironment('MAP_CENTER_LNG', defaultValue: '-8.6558');
  static double get mapCenterLng => double.tryParse(_mapCenterLngStr) ?? -8.6558;
  
  // Bounds
  static const String _mapBoundsSwLatStr = String.fromEnvironment('MAP_BOUNDS_SW_LAT', defaultValue: '40.6250');
  static double get mapBoundsSwLat => double.tryParse(_mapBoundsSwLatStr) ?? 40.6250;
  
  static const String _mapBoundsSwLngStr = String.fromEnvironment('MAP_BOUNDS_SW_LNG', defaultValue: '-8.6600');
  static double get mapBoundsSwLng => double.tryParse(_mapBoundsSwLngStr) ?? -8.6600;
  
  static const String _mapBoundsNeLatStr = String.fromEnvironment('MAP_BOUNDS_NE_LAT', defaultValue: '40.6350');
  static double get mapBoundsNeLat => double.tryParse(_mapBoundsNeLatStr) ?? 40.6350;
  
  static const String _mapBoundsNeLngStr = String.fromEnvironment('MAP_BOUNDS_NE_LNG', defaultValue: '-8.6500');
  static double get mapBoundsNeLng => double.tryParse(_mapBoundsNeLngStr) ?? -8.6500;

  // Modes & Toggles
  static const bool isOutdoorMode = bool.fromEnvironment('IS_OUTDOOR_MODE', defaultValue: true);
  static const bool onlyDatabasePOIs = bool.fromEnvironment('ONLY_DATABASE_POIS', defaultValue: true);

  // ==================== TIMEOUTS ====================
  
  static const int httpTimeoutSeconds = int.fromEnvironment('HTTP_TIMEOUT_SECONDS', defaultValue: 30);
  static const int mqttTimeoutSeconds = int.fromEnvironment('MQTT_TIMEOUT_SECONDS', defaultValue: 30);

  // ==================== BUSINESS LOGIC ====================
  
  static const String forcedEmergencyExitNamesRaw = String.fromEnvironment(
    'FORCED_EMERGENCY_EXIT_NAMES', 
    defaultValue: 'nave desportiva da ua|universidade - antiga reitoria b|universidade - antiga reuturia b',
  );
  
  static Set<String> get forcedEmergencyExitNames => 
      forcedEmergencyExitNamesRaw.split('|').map((s) => s.trim().toLowerCase()).toSet();
}
