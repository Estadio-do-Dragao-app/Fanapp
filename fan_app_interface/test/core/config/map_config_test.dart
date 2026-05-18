import 'package:flutter_test/flutter_test.dart';
import 'package:fan_app_interface/core/config/map_config.dart';
import 'package:fan_app_interface/core/config/app_env.dart';

void main() {
  group('MapMode', () {
    test('has outdoor and indoor values', () {
      expect(MapMode.values, containsAll([MapMode.outdoor, MapMode.indoor]));
    });

    test('outdoor and indoor are different', () {
      expect(MapMode.outdoor, isNot(equals(MapMode.indoor)));
    });
  });

  group('MapConfig', () {
    test('mode returns MapMode based on AppEnv.isOutdoorMode', () {
      final expected = AppEnv.isOutdoorMode ? MapMode.outdoor : MapMode.indoor;
      expect(MapConfig.mode, equals(expected));
    });

    test('onlyDatabasePOIs delegates to AppEnv', () {
      expect(MapConfig.onlyDatabasePOIs, equals(AppEnv.onlyDatabasePOIs));
    });

    test('useOSMTiles is true only in outdoor mode', () {
      expect(MapConfig.useOSMTiles, equals(MapConfig.mode == MapMode.outdoor));
    });

    test('useFloorPlan is true only in indoor mode', () {
      expect(MapConfig.useFloorPlan, equals(MapConfig.mode == MapMode.indoor));
    });

    test('useOSMTiles and useFloorPlan are mutually exclusive', () {
      expect(MapConfig.useOSMTiles && MapConfig.useFloorPlan, isFalse);
    });

    test('walkableRadius is a positive number', () {
      expect(MapConfig.walkableRadius, greaterThan(0));
    });

    test('walkableRadius differs by mode', () {
      if (MapConfig.mode == MapMode.outdoor) {
        expect(MapConfig.walkableRadius, equals(50.0));
      } else {
        expect(MapConfig.walkableRadius, equals(15.0));
      }
    });

    test('initialZoom is a positive number', () {
      expect(MapConfig.initialZoom, greaterThan(0));
    });

    test('initialZoom differs by mode', () {
      if (MapConfig.mode == MapMode.outdoor) {
        expect(MapConfig.initialZoom, equals(17.0));
      } else {
        expect(MapConfig.initialZoom, equals(19.0));
      }
    });

    test('navigationZoom is greater than or equal to initialZoom', () {
      expect(MapConfig.navigationZoom, greaterThanOrEqualTo(MapConfig.initialZoom));
    });

    test('navigationZoom differs by mode', () {
      if (MapConfig.mode == MapMode.outdoor) {
        expect(MapConfig.navigationZoom, equals(20.0));
      } else {
        expect(MapConfig.navigationZoom, equals(21.0));
      }
    });

    test('minZoom is less than initialZoom', () {
      expect(MapConfig.minZoom, lessThan(MapConfig.initialZoom));
    });

    test('minZoom differs by mode', () {
      if (MapConfig.mode == MapMode.outdoor) {
        expect(MapConfig.minZoom, equals(14.0));
      } else {
        expect(MapConfig.minZoom, equals(17.0));
      }
    });

    test('modeLabel is non-empty string', () {
      expect(MapConfig.modeLabel, isNotEmpty);
    });

    test('modeLabel contains mode description', () {
      if (MapConfig.mode == MapMode.outdoor) {
        expect(MapConfig.modeLabel, contains('Outdoor'));
      } else {
        expect(MapConfig.modeLabel, contains('Indoor'));
      }
    });

    test('useOSMPOIs requires outdoor mode and non-database POIs', () {
      if (MapConfig.mode == MapMode.indoor || MapConfig.onlyDatabasePOIs) {
        expect(MapConfig.useOSMPOIs, isFalse);
      }
    });
  });
}
