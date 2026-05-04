import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../config/api_config.dart';

/// Service for MQTT communication with the Service-to-Client-Broker
/// Receives real-time data from all backend services
/// NOTE: MQTT only works on mobile (TCP). Web uses HTTP fallback.
class MqttService {
  static final MqttService _instance = MqttService._internal();
  factory MqttService() => _instance;
  MqttService._internal();

  // Broker configuration (Service-to-Client-Broker)
  static String get _broker => ApiConfig.mqttBroker;
  static const int _port = ApiConfig.mqttPort;
  static const String _clientId = 'fanapp_flutter';

  // Topics from Stadium Event Generator / Services
  static const String topicAllEvents = 'stadium/events/all';
  static const String topicCongestion = 'stadium/services/congestion';
  static const String topicQueues = 'stadium/services/waittime/#';
  static const String topicMaintenance = 'stadium/events/maintenance';
  static const String topicSecurity = 'stadium/events/security';
  static const String topicAlerts = 'alerts/broadcast';
  static const String topicRouting = 'stadium/services/routing/#';
  static const String topicGps = 'stadium/location/gps';

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
  final _waittimeController =
      StreamController<Map<String, dynamic>>.broadcast();

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
  Stream<Map<String, dynamic>> get waittimeStream => _waittimeController.stream;

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
      print(
        '[MqttService] MQTT not supported on web platform. Use HTTP fallback.',
      );
      return false;
    }

    _isConnecting = true;
    
    try {
      print('[MqttService] Connecting via TCP: $_broker:$_port');
      _client = MqttServerClient(_broker, _clientId);
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
        print('[MqttService] Connected successfully');
        _isConnected = true;
        _isConnecting = false;
        _subscribeToTopics();
        return true;
      } else {
        print('[MqttService] Connection failed: ${_client!.connectionStatus}');
        _isConnecting = false;
        return false;
      }
    } catch (e) {
      print('[MqttService] Connection error: $e');
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
      print('[MqttService] Disconnected');
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
      topicMaintenance,
      topicAllEvents,
      topicRouting,
    ];

    for (var topic in topics) {
      _client!.subscribe(topic, MqttQos.atLeastOnce);
      print('[MqttService] Subscribed to: $topic');
    }

    // Listen for incoming messages
    _client!.updates!.listen(_onMessage);
    _isSubscribed = true;
  }

  /// Handle incoming MQTT messages
  void _onMessage(List<MqttReceivedMessage<MqttMessage>> messages) {
    for (var message in messages) {
      final topic = message.topic;
      final payload = message.payload as MqttPublishMessage;
      final data = MqttPublishPayload.bytesToStringAsString(
        payload.payload.message,
      );

      try {
        final jsonData = json.decode(data) as Map<String, dynamic>;

        // Check for expiry_time
        if (jsonData.containsKey('expiry_time') && jsonData['expiry_time'] != null) {
          try {
            final expiryTime = DateTime.parse(jsonData['expiry_time']).toUtc();
            if (DateTime.now().toUtc().isAfter(expiryTime)) {
              print('[MqttService] 🕰️ Ignored expired message on $topic');
              continue;
            }
          } catch (e) {
            print('[MqttService] Invalid expiry_time format: $e');
          }
        }

        // Route message to appropriate stream
        // Handle wildcard topics first (waittime/queues)
        if (topic.startsWith('stadium/services/waittime/')) {
          print('[MqttService] 📤 Emitting to queuesStream: ${jsonData['poi']} = ${jsonData['minutes']} min');
          _queuesController.add(jsonData);
        } else if (topic.startsWith('stadium/services/routing/')) {
          _routingController.add(jsonData);
        }
        // Then handle exact matches

        switch (topic) {
          case topicCongestion:
            print('[MqttService] 🔥 Congestion message received: ${jsonData['cell_id']}');
            _congestionController.add(jsonData);
            break;
          case topicAlerts:
            _alertsController.add(jsonData);
            
            // Send ACK if priority is CRITICAL
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
                MqttQos.exactlyOnce, // QoS 2
                builder.payload!,
              );
              print('[MqttService] ✅ Sent ACK for alert ${ackMessage['alert_id']}');
            }
            break;
          case topicSecurity:
            _securityController.add(jsonData);
            break;
          case topicMaintenance:
            _maintenanceController.add(jsonData);
            break;
          case topicAllEvents:
            _allEventsController.add(jsonData);
            break;
          case topicGps:
            // High frequency data - ignored by client to avoid lag
            break;
        }

        print('[MqttService] Received on $topic: ${jsonData.keys.toList()}');
      } catch (e) {
        print('[MqttService] Error parsing message on $topic: $e');
      }
    }
  }

  void _onConnected() {
    print('[MqttService] Connected callback');
    _isConnected = true;
  }

  void _onDisconnected() {
    print('[MqttService] Disconnected callback');
    _isConnected = false;
  }

  void _onAutoReconnect() {
    print('[MqttService] Auto-reconnecting...');
    _isConnected = false;
    _isSubscribed = false; // Reset subscription flag so we re-subscribe after reconnect
  }

  void _onAutoReconnected() {
    print('[MqttService] Auto-reconnected successfully');
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
