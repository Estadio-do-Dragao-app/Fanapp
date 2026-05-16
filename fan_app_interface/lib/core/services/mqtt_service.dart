import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import '../config/app_env.dart';

/// Service for MQTT communication with the Service-to-Client-Broker
/// Receives real-time data from all backend services
/// NOTE: MQTT only works on mobile (TCP). Web uses HTTP fallback.
class MqttService {
  static MqttService? _instance;
  
  /// Factory constructor supports dependency injection for testing.
  factory MqttService({MqttServerClient? client}) {
    _instance ??= MqttService._internal(client);
    return _instance!;
  }
  
  MqttService._internal(this._client);

  @visibleForTesting
  static void resetForTesting() {
    _instance = null;
  }

  // Broker configuration (Service-to-Client-Broker)
  static String get _broker => AppEnv.mqttBroker;
  static int get _port => AppEnv.mqttPort;
  static String get _clientId => AppEnv.mqttClientId;

  // Topics from Stadium Event Generator / Services
  static String get topicAllEvents => AppEnv.topicAllEvents;
  static String get topicCongestion => AppEnv.topicCongestion;
  static String get topicQueues => AppEnv.topicQueues;
  static String get topicMaintenance => AppEnv.topicMaintenance;
  static String get topicSecurity => AppEnv.topicSecurity;
  static String get topicAlerts => AppEnv.topicAlerts;
  static String get topicRouting => AppEnv.topicRouting;
  static String get topicGps => AppEnv.topicGps;

  MqttServerClient? _client;
  bool _isConnected = false;
  bool _isSubscribed = false; // Guard to prevent multiple subscriptions
  bool _isConnecting = false; // Guard to prevent multiple connection attempts

  // Stream controllers for different data types
  final _congestionController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _queuesController = StreamController<Map<String, dynamic>>.broadcast();
  final _alertsController = StreamController<Map<String, dynamic>>.broadcast();
  final _securityController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _maintenanceController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _allEventsController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _routingController = StreamController<Map<String, dynamic>>.broadcast();

  /// Streams for different event types
  Stream<Map<String, dynamic>> get congestionStream =>
      _congestionController.stream;
  Stream<Map<String, dynamic>> get queuesStream => _queuesController.stream;
  Stream<Map<String, dynamic>> get alertsStream => _alertsController.stream;
  Stream<Map<String, dynamic>> get securityStream => _securityController.stream;
  Stream<Map<String, dynamic>> get maintenanceStream =>
      _maintenanceController.stream;
  Stream<Map<String, dynamic>> get allEventsStream =>
      _allEventsController.stream;
  Stream<Map<String, dynamic>> get routingStream => _routingController.stream;

  /// Publish user location (GPS) to the broker
  /// This is used for anonymous crowd tracking
  void publishLocation(String userId, double lat, double lng) {
    if (_client == null || !_isConnected) return;

    final Map<String, dynamic> message = {
      'user_id': userId,
      'lat': lat,
      'lng': lng,
      'timestamp': DateTime.now().millisecondsSinceEpoch / 1000.0,
    };

    final builder = MqttClientPayloadBuilder();
    builder.addString(json.encode(message));

    _client!.publishMessage(
      topicGps,
      MqttQos.atMostOnce, // Low priority
      builder.payload!,
    );
  }

  /// Check if connected to broker
  bool get isConnected => _isConnected;

  /// Connect to the MQTT broker
  Future<bool> connect() async {
    if (_isConnected) return true;
    if (_isConnecting) return false; // Prevent multiple connection attempts

    // MQTT TCP is not available on Web platform
    if (kIsWeb) {
      debugPrint(
        '[MqttService] MQTT not supported on web platform. Use HTTP fallback.',
      );
      return false;
    }

    _isConnecting = true;
    
    try {
      debugPrint('[MqttService] Connecting via TCP: $_broker:$_port');
      _client ??= MqttServerClient(_broker, _clientId);
      _client!.port = _port;

      _client!.logging(on: false);
      _client!.keepAlivePeriod = 30;
      _client!.autoReconnect = true;
      _client!.onConnected = _onConnected;
      _client!.onDisconnected = _onDisconnected;
      _client!.onAutoReconnect = _onAutoReconnect;
      _client!.onAutoReconnected = _onAutoReconnected;

      final connMessage = MqttConnectMessage()
          .withClientIdentifier(_clientId)
          .startClean()
          .withWillQos(MqttQos.atLeastOnce);
      _client!.connectionMessage = connMessage;

      await _client!.connect();

      if (_client!.connectionStatus!.state == MqttConnectionState.connected) {
        debugPrint('[MqttService] Connected successfully');
        _isConnected = true;
        _isConnecting = false;
        _subscribeToTopics();
        return true;
      } else {
        debugPrint('[MqttService] Connection failed: ${_client!.connectionStatus}');
        _isConnecting = false;
        return false;
      }
    } catch (e) {
      debugPrint('[MqttService] Connection error: $e');
      _isConnecting = false;
      return false;
    }
  }

  /// Disconnect from broker
  void disconnect() {
    if (_client != null && _isConnected) {
      _client!.disconnect();
      _isConnected = false;
      _isSubscribed = false;
      debugPrint('[MqttService] Disconnected');
    }
  }

  /// Subscribe to all relevant topics
  void _subscribeToTopics() {
    if (_client == null || !_isConnected) return;
    if (_isSubscribed) return; // Already subscribed, don't re-subscribe

    // Subscribe to all available topics
    final topics = [
      topicCongestion,
      topicQueues,
      topicAlerts,
      topicSecurity,
      topicMaintenance,
      topicAllEvents,
      topicRouting,
    ];

    for (var topic in topics) {
      _client!.subscribe(topic, MqttQos.atLeastOnce);
      debugPrint('[MqttService] Subscribed to: $topic');
    }

    // Listen for incoming messages
    _client!.updates!.listen(_onMessage);
    _isSubscribed = true;
  }

  /// Handle incoming MQTT messages
  void _onMessage(List<MqttReceivedMessage<MqttMessage>> messages) {
    for (var message in messages) {
      _processMessage(message);
    }
  }

  void _processMessage(MqttReceivedMessage<MqttMessage> message) {
    final topic = message.topic;
    final payload = message.payload as MqttPublishMessage;
    final data = MqttPublishPayload.bytesToStringAsString(payload.payload.message);

    try {
      final dynamic parsedData = json.decode(data);
      if (parsedData is! Map<String, dynamic>) {
        debugPrint('[MqttService] Invalid payload format (not a Map) on $topic');
        return;
      }

      if (_isMessageExpired(parsedData, topic)) return;

      _routeMessage(topic, parsedData);

      debugPrint('[MqttService] Received on $topic: ${parsedData.keys.toList()}');
    } catch (e) {
      debugPrint('[MqttService] Error parsing message on $topic: $e');
    }
  }

  bool _isMessageExpired(Map<String, dynamic> jsonData, String topic) {
    if (!jsonData.containsKey('expiry_time') || jsonData['expiry_time'] == null) {
      return false;
    }
    
    try {
      final expiryTime = DateTime.parse(jsonData['expiry_time'].toString()).toUtc();
      if (DateTime.now().toUtc().isAfter(expiryTime)) {
        debugPrint('[MqttService] Ignored expired message on $topic');
        return true;
      }
    } catch (e) {
      debugPrint('[MqttService] Invalid expiry_time format: $e');
    }
    return false;
  }

  void _routeMessage(String topic, Map<String, dynamic> jsonData) {
    if (topic.startsWith(topicQueues.replaceAll('#', ''))) {
      debugPrint('[MqttService] Emitting to queuesStream: ${jsonData['poi']} = ${jsonData['minutes']} min');
      _queuesController.add(jsonData);
    } else if (topic.startsWith(topicRouting.replaceAll('#', ''))) {
      _routingController.add(jsonData);
    } else if (topic == topicCongestion) {
      debugPrint('[MqttService] Congestion message received: ${jsonData['cell_id']}');
      _congestionController.add(jsonData);
    } else if (topic == topicAlerts) {
      _handleAlertMessage(jsonData);
    } else if (topic == topicSecurity) {
      _securityController.add(jsonData);
    } else if (topic == topicMaintenance) {
      _maintenanceController.add(jsonData);
    } else if (topic == topicAllEvents) {
      _allEventsController.add(jsonData);
    }
  }

  void _handleAlertMessage(Map<String, dynamic> jsonData) {
    _alertsController.add(jsonData);
    
    if (jsonData['priority'] == 'CRITICAL') {
      final ackMessage = {
        'alert_id': jsonData['alert_id'] ?? jsonData['id'],
        'client_id': _clientId,
        'status': 'received',
        'timestamp': DateTime.now().toUtc().toIso8601String()
      };
      final builder = MqttClientPayloadBuilder();
      builder.addString(json.encode(ackMessage));
      _client!.publishMessage(
        'alerts/ack/$_clientId',
        MqttQos.exactlyOnce,
        builder.payload!,
      );
      debugPrint('[MqttService] Sent ACK for alert ${ackMessage['alert_id']}');
    }
  }

  void _onConnected() {
    debugPrint('[MqttService] Connected callback');
    _isConnected = true;
  }

  void _onDisconnected() {
    debugPrint('[MqttService] Disconnected callback');
    _isConnected = false;
  }

  void _onAutoReconnect() {
    debugPrint('[MqttService] Auto-reconnecting...');
    _isConnected = false;
    _isSubscribed = false; // Reset subscription flag so we re-subscribe after reconnect
  }

  void _onAutoReconnected() {
    debugPrint('[MqttService] Auto-reconnected successfully');
    _isConnected = true;
    _subscribeToTopics(); // Re-subscribe to topics after auto-reconnection
  }

  /// Dispose resources
  void dispose() {
    disconnect();
    _congestionController.close();
    _queuesController.close();
    _alertsController.close();
    _securityController.close();
    _maintenanceController.close();
    _allEventsController.close();
    _routingController.close();
  }
}
