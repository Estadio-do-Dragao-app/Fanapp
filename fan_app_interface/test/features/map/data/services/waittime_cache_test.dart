import 'package:flutter_test/flutter_test.dart';
import 'package:fan_app_interface/features/map/data/services/waittime_cache.dart';

void main() {
  group('WaittimeCache', () {
    late WaittimeCache cache;

    setUp(() {
      cache = WaittimeCache();
      // In tests, we don't actually want to start MQTT/HTTP polling.
      // We'll use the cache directly by accessing its internal state via
      // the public getWaitTime after manually setting via the (private) cache.
      // For testing, we can use reflection or just test that the singleton exists.
    });

    tearDown(() {
      cache.stop();
    });

    test('is a singleton', () {
      final a = WaittimeCache();
      final b = WaittimeCache();
      expect(identical(a, b), isTrue);
    });

    test('getWaitTime returns null for unknown POI', () {
      final result = cache.getWaitTime('unknown_poi');
      expect(result, isNull);
    });

    // Note: setWaitTime is not a public method – cache is filled by MQTT/HTTP.
    // To test storage, we would need to simulate a stream update.
    // For basic coverage, we can verify the cache can be started/stopped without error.
    test('start and stop do not throw', () {
      expect(() => cache.start(), returnsNormally);
      expect(() => cache.stop(), returnsNormally);
    });

    test('dispose does not throw', () {
      expect(() => cache.dispose(), returnsNormally);
    });

    test('allWaitTimes returns an unmodifiable map (initially empty)', () {
      final map = cache.allWaitTimes;
      expect(map, isEmpty);
      expect(() => map['test'] = 5, throwsUnsupportedError);
    });
  });
}