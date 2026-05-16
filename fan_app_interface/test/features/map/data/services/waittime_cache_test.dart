import 'package:flutter_test/flutter_test.dart';
import 'package:fan_app_interface/features/map/data/services/waittime_cache.dart';

void main() {
  group('WaittimeCache', () {
    late WaittimeCache cache;

    setUp(() {
      cache = WaittimeCache();
      cache.stop(); // prevent background timer from running
    });

    tearDown(() {
      cache.stop();
    });

    test('is a singleton', () {
      final a = WaittimeCache();
      final b = WaittimeCache();
      expect(identical(a, b), isTrue);
    });

    test('getWaittime returns null for unknown POI', () {
      final result = cache.getWaittime('unknown_poi');
      expect(result, isNull);
    });

    test('setWaittime stores a value retrievable by getWaittime', () {
      cache.setWaittime('poi_wc_1', 5);
      expect(cache.getWaittime('poi_wc_1'), 5);
    });

    test('setWaittime overwrites previous value', () {
      cache.setWaittime('poi_bar_1', 10);
      cache.setWaittime('poi_bar_1', 3);
      expect(cache.getWaittime('poi_bar_1'), 3);
    });

    test('clear removes all entries', () {
      cache.setWaittime('poi_a', 2);
      cache.setWaittime('poi_b', 7);
      cache.clear();
      expect(cache.getWaittime('poi_a'), isNull);
      expect(cache.getWaittime('poi_b'), isNull);
    });

    test('stop does not throw', () {
      expect(() => cache.stop(), returnsNormally);
    });
  });
}
