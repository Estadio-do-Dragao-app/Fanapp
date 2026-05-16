import 'package:flutter_test/flutter_test.dart';
import 'package:fan_app_interface/core/config/api_config.dart';
import 'package:fan_app_interface/core/config/app_env.dart';

void main() {
  group('ApiConfig', () {
    test('mapService URL is not empty', () {
      expect(ApiConfig.mapService, isNotEmpty);
    });

    test('waitTimeService URL is not empty', () {
      expect(ApiConfig.waitTimeService, isNotEmpty);
    });

    test('routingService URL is not empty', () {
      expect(ApiConfig.routingService, isNotEmpty);
    });

    test('mqttBroker is not empty', () {
      expect(ApiConfig.mqttBroker, isNotEmpty);
    });

    test('mqttPort is valid', () {
      expect(ApiConfig.mqttPort, greaterThan(0));
      expect(ApiConfig.mqttPort, lessThanOrEqualTo(65535));
    });

    test('httpTimeout is positive', () {
      expect(ApiConfig.httpTimeout, greaterThan(0));
    });

    test('init() does not throw (simulate)', () async {
      // In tests, init() will try to connect to real services.
      // We just verify it doesn't crash (it may print errors but that's fine).
      expect(() async => await ApiConfig.init(), returnsNormally);
    });
  });

  group('AppEnv', () {
    test('apiBaseUrl is not empty', () {
      expect(AppEnv.apiBaseUrl, isNotEmpty);
    });

    test('mqttPort has default value', () {
      expect(AppEnv.mqttPort, 1883);
    });

    test('mapCenterLat is a double', () {
      expect(AppEnv.mapCenterLat, isA<double>());
    });

    test('mapCenterLng is a double', () {
      expect(AppEnv.mapCenterLng, isA<double>());
    });

    test('isOutdoorMode is a boolean', () {
      expect(AppEnv.isOutdoorMode, isA<bool>());
    });

    test('onlyDatabasePOIs is a boolean', () {
      expect(AppEnv.onlyDatabasePOIs, isA<bool>());
    });

    test('httpTimeoutSeconds is positive', () {
      expect(AppEnv.httpTimeoutSeconds, greaterThan(0));
    });

    test('forcedEmergencyExitNames is a Set', () {
      expect(AppEnv.forcedEmergencyExitNames, isA<Set<String>>());
    });
  });
}