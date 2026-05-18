import 'package:flutter_test/flutter_test.dart';
import 'package:fan_app_interface/core/config/app_env.dart';

void main() {
  group('AppEnv extended getters', () {
    group('service URLs', () {
      test('mapServiceUrl includes apiBaseUrl', () {
        expect(AppEnv.mapServiceUrl, contains(AppEnv.apiBaseUrl));
        expect(AppEnv.mapServiceUrl, contains(':8000'));
      });

      test('routingServiceUrl includes apiBaseUrl', () {
        expect(AppEnv.routingServiceUrl, contains(AppEnv.apiBaseUrl));
        expect(AppEnv.routingServiceUrl, contains(':8002'));
      });

      test('waitTimeServiceUrl includes apiBaseUrl', () {
        expect(AppEnv.waitTimeServiceUrl, contains(AppEnv.apiBaseUrl));
        expect(AppEnv.waitTimeServiceUrl, contains(':8001'));
      });
    });

    group('MQTT config', () {
      test('mqttBroker strips http:// prefix', () {
        expect(AppEnv.mqttBroker, isNot(contains('http://')));
        expect(AppEnv.mqttBroker, isNot(contains('https://')));
      });

      test('mqttBroker is not empty', () {
        expect(AppEnv.mqttBroker, isNotEmpty);
      });

      test('mqttWebSocketPort has default value 9002', () {
        expect(AppEnv.mqttWebSocketPort, 9002);
      });

      test('mqttClientId has default value', () {
        expect(AppEnv.mqttClientId, isNotEmpty);
      });

      test('mqttTimeoutSeconds is positive', () {
        expect(AppEnv.mqttTimeoutSeconds, greaterThan(0));
      });
    });

    group('MQTT topics', () {
      test('topicAllEvents is non-empty', () {
        expect(AppEnv.topicAllEvents, isNotEmpty);
      });

      test('topicCongestion is non-empty', () {
        expect(AppEnv.topicCongestion, isNotEmpty);
      });

      test('topicQueues is non-empty', () {
        expect(AppEnv.topicQueues, isNotEmpty);
      });

      test('topicMaintenance is non-empty', () {
        expect(AppEnv.topicMaintenance, isNotEmpty);
      });

      test('topicSecurity is non-empty', () {
        expect(AppEnv.topicSecurity, isNotEmpty);
      });

      test('topicAlerts is non-empty', () {
        expect(AppEnv.topicAlerts, isNotEmpty);
      });

      test('topicRouting is non-empty', () {
        expect(AppEnv.topicRouting, isNotEmpty);
      });

      test('topicGps is non-empty', () {
        expect(AppEnv.topicGps, isNotEmpty);
      });
    });

    group('map bounds', () {
      test('mapBoundsSwLat is a valid latitude', () {
        expect(AppEnv.mapBoundsSwLat, isA<double>());
        expect(AppEnv.mapBoundsSwLat, lessThan(AppEnv.mapBoundsNeLat));
      });

      test('mapBoundsSwLng is a valid longitude', () {
        expect(AppEnv.mapBoundsSwLng, isA<double>());
        expect(AppEnv.mapBoundsSwLng, lessThan(AppEnv.mapBoundsNeLng));
      });

      test('mapBoundsNeLat is a valid latitude', () {
        expect(AppEnv.mapBoundsNeLat, isA<double>());
      });

      test('mapBoundsNeLng is a valid longitude', () {
        expect(AppEnv.mapBoundsNeLng, isA<double>());
      });

      test('map center is within bounds', () {
        expect(AppEnv.mapCenterLat, greaterThanOrEqualTo(AppEnv.mapBoundsSwLat));
        expect(AppEnv.mapCenterLat, lessThanOrEqualTo(AppEnv.mapBoundsNeLat));
      });
    });

    group('security', () {
      test('mapApiKey is a string (may be empty in tests)', () {
        expect(AppEnv.mapApiKey, isA<String>());
      });
    });

    group('forcedEmergencyExitNames', () {
      test('is non-empty set of strings', () {
        final names = AppEnv.forcedEmergencyExitNames;
        expect(names, isA<Set<String>>());
        expect(names, isNotEmpty);
      });

      test('all names are lowercase', () {
        for (final name in AppEnv.forcedEmergencyExitNames) {
          expect(name, equals(name.toLowerCase()));
        }
      });

      test('names are trimmed', () {
        for (final name in AppEnv.forcedEmergencyExitNames) {
          expect(name, equals(name.trim()));
        }
      });
    });
  });
}
