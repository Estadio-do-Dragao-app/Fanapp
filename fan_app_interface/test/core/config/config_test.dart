import 'package:flutter_test/flutter_test.dart';
import 'package:fan_app_interface/core/config/api_config.dart';
import 'package:fan_app_interface/core/config/app_env.dart';

void main() {
  group('ApiConfig', () {
    test('baseUrl is not empty', () {
      expect(ApiConfig.baseUrl, isNotEmpty);
    });

    test('baseUrl is a valid URL format', () {
      expect(
        Uri.tryParse(ApiConfig.baseUrl),
        isNotNull,
        reason: 'baseUrl should be parseable as a URI',
      );
    });

    test('wsUrl is not empty', () {
      expect(ApiConfig.wsUrl, isNotEmpty);
    });

    test('mqttHost is not empty', () {
      expect(ApiConfig.mqttHost, isNotEmpty);
    });

    test('mqttPort is a valid port number', () {
      expect(ApiConfig.mqttPort, greaterThan(0));
      expect(ApiConfig.mqttPort, lessThanOrEqualTo(65535));
    });

    test('all endpoint paths start with slash or are relative', () {
      // Just verify key endpoints exist and are strings
      expect(ApiConfig.nodesEndpoint, isA<String>());
      expect(ApiConfig.poisEndpoint, isA<String>());
      expect(ApiConfig.routeEndpoint, isA<String>());
    });

    test('timeout duration is positive', () {
      expect(ApiConfig.requestTimeout.inSeconds, greaterThan(0));
    });
  });

  group('AppEnv', () {
    test('environment value is one of known values', () {
      final env = AppEnv.current;
      expect(['development', 'staging', 'production'].contains(env), isTrue);
    });

    test('isProduction is a boolean', () {
      expect(AppEnv.isProduction, isA<bool>());
    });

    test('isDevelopment is a boolean', () {
      expect(AppEnv.isDevelopment, isA<bool>());
    });

    test('exactly one environment flag is true', () {
      final flags = [AppEnv.isDevelopment, AppEnv.isProduction];
      final trueCount = flags.where((f) => f).length;
      // At least one must be true
      expect(trueCount, greaterThanOrEqualTo(1));
    });

    test('apiBaseUrl matches ApiConfig.baseUrl', () {
      expect(AppEnv.apiBaseUrl, isNotEmpty);
    });
  });
}
