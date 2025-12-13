import 'dart:async';
import 'dart:convert';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

/// Service for MQTT communication with the Service-to-Client-Broker
/// Receives real-time data from all backend services
class MqttService {
  static final MqttService _instance = MqttService._internal();
  factory MqttService() => _instance;
  MqttService._internal();

  // Broker configuration (Service-to-Client-Broker)
  static const String _broker = 'localhost';
  static const int _port =
      1884; // MQTT port for client-mosquitto (service-to-client-broker)
  static const String _clientId = 'fanapp_flutter';

  // Topics from Stadium Event Generator / Services
  static const String topicAllEvents = 'stadium/events/all';
  static const String topicCongestion = 'stadium/services/congestion';
  static const String topicQueues = 'stadium/events/queues';
  static const String topicMaintenance = 'stadium/events/maintenance';
  static const String topicSecurity = 'stadium/events/security';
  static const String topicAlerts = 'stadium/events/alerts';

  MqttServerClient? _client;
  bool _isConnected = false;

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

  /// Check if connected to broker
  bool get isConnected => _isConnected;

  /// Connect to the MQTT broker
  Future<bool> connect() async {
    if (_isConnected) return true;

    try {
      _client = MqttServerClient(_broker, _clientId);
      _client!.port = _port;
      _client!.logging(on: false);
      _client!.keepAlivePeriod = 30;
      _client!.autoReconnect = true;
      _client!.onConnected = _onConnected;
      _client!.onDisconnected = _onDisconnected;
      _client!.onAutoReconnect = _onAutoReconnect;

      final connMessage = MqttConnectMessage()
          .withClientIdentifier(_clientId)
          .startClean()
          .withWillQos(MqttQos.atLeastOnce);
      _client!.connectionMessage = connMessage;

      print('[MqttService] Connecting to $_broker:$_port...');
      await _client!.connect();

      if (_client!.connectionStatus!.state == MqttConnectionState.connected) {
        print('[MqttService] Connected successfully');
        _isConnected = true;
        _subscribeToTopics();
        return true;
      } else {
        print('[MqttService] Connection failed: ${_client!.connectionStatus}');
        return false;
      }
    } catch (e) {
      print('[MqttService] Connection error: $e');
      return false;
    }
  }

  /// Disconnect from broker
  void disconnect() {
    if (_client != null && _isConnected) {
      _client!.disconnect();
      _isConnected = false;
      print('[MqttService] Disconnected');
    }
  }

  /// Subscribe to all relevant topics
  void _subscribeToTopics() {
    if (_client == null || !_isConnected) return;

    // Subscribe to all available topics
    final topics = [
      topicCongestion,
      topicQueues,
      topicAlerts,
      topicSecurity,
      topicMaintenance,
      topicAllEvents,
    ];

    for (var topic in topics) {
      _client!.subscribe(topic, MqttQos.atLeastOnce);
      print('[MqttService] Subscribed to: $topic');
    }

    // Listen for incoming messages
    _client!.updates!.listen(_onMessage);
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

        // Route message to appropriate stream
        switch (topic) {
          case topicCongestion:
            _congestionController.add(jsonData);
            break;
          case topicQueues:
            _queuesController.add(jsonData);
            break;
          case topicAlerts:
            _alertsController.add(jsonData);
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
  }
}
