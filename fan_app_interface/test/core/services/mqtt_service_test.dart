import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:fan_app_interface/core/services/mqtt_service.dart';

import 'package:typed_data/typed_data.dart';

// Mock Classes
class MockMqttServerClient extends Mock implements MqttServerClient {}

class MockMqttClientConnectionStatus extends Mock
    implements MqttClientConnectionStatus {}

void main() {
  late MqttService mqttService;
  late MockMqttServerClient mockClient;
  late MockMqttClientConnectionStatus mockStatus;

  setUpAll(() {
    registerFallbackValue(MqttQos.atMostOnce);
    registerFallbackValue(Uint8Buffer());
  });

  setUp(() {
    MqttService.resetForTesting();
    mockClient = MockMqttServerClient();
    mockStatus = MockMqttClientConnectionStatus();
    mqttService = MqttService(client: mockClient);

    when(() => mockClient.connect()).thenAnswer((_) async => mockStatus);
    when(() => mockClient.connect()).thenAnswer((_) async => mockStatus);
    
    // Setup connection status
    when(() => mockClient.connectionStatus).thenReturn(mockStatus);
    when(() => mockStatus.state).thenReturn(MqttConnectionState.connected);
    
    // Setup streams
    when(() => mockClient.updates).thenAnswer((_) => const Stream.empty());
    
    // Subscriptions
    when(() => mockClient.subscribe(any(), any())).thenReturn(null);
  });

  tearDown(() {
    mqttService.dispose();
  });

  group('MqttService', () {
    test('connect() successfully connects and subscribes to topics', () async {
      final connected = await mqttService.connect();
      
      expect(connected, isTrue);
      expect(mqttService.isConnected, isTrue);
      
      // Verify connect was called
      verify(() => mockClient.connect()).called(1);
      
      // Verify subscriptions happened for topics
      verify(() => mockClient.subscribe(any(), MqttQos.atLeastOnce)).called(greaterThanOrEqualTo(5));
    });

    test('connect() handles connection failure gracefully', () async {
      when(() => mockStatus.state).thenReturn(MqttConnectionState.faulted);
      
      final connected = await mqttService.connect();
      
      expect(connected, isFalse);
      expect(mqttService.isConnected, isFalse);
    });
    
    test('connect() catches exceptions thrown by client', () async {
      when(() => mockClient.connect()).thenThrow(Exception('Network Error'));
      
      final connected = await mqttService.connect();
      
      expect(connected, isFalse);
      expect(mqttService.isConnected, isFalse);
    });

    test('publishLocation() publishes when connected', () async {
      // Setup successful connection
      await mqttService.connect();
      
      when(() => mockClient.publishMessage(any(), any(), any())).thenReturn(1);
      
      mqttService.publishLocation('user_123', 40.0, -8.0);
      
      verify(() => mockClient.publishMessage(
        any(), 
        MqttQos.atMostOnce, 
        any()
      )).called(1);
    });
    
    test('publishLocation() ignores when not connected', () async {
      // Do not call connect()
      
      mqttService.publishLocation('user_123', 40.0, -8.0);
      
      // Should not interact with client if not connected
      verifyNever(() => mockClient.publishMessage(any(), any(), any()));
    });
  });
}
