import 'package:flutter_test/flutter_test.dart';
import 'package:fan_app_interface/features/map/data/models/tile_model.dart';

void main() {
  group('TileModel', () {
    group('fromJson', () {
      test('parses valid JSON', () {
        final json = {
          'id': 'T1',
          'grid_x': 3.0,
          'grid_y': 4.0,
          'level': 0,
          'bounds': {
            'min_x': 0.0,
            'max_x': 10.0,
            'min_y': 0.0,
            'max_y': 10.0,
          },
          'walkable': true,
        };
        final tile = TileModel.fromJson(json);
        expect(tile.id, 'T1');
        expect(tile.gridX, 3.0);
        expect(tile.gridY, 4.0);
        expect(tile.level, 0);
        expect(tile.minX, 0.0);
        expect(tile.maxX, 10.0);
        expect(tile.minY, 0.0);
        expect(tile.maxY, 10.0);
        expect(tile.walkable, true);
      });

      test('parses non-walkable tile', () {
        final json = {
          'id': 'T2',
          'grid_x': 1.0,
          'grid_y': 1.0,
          'level': 1,
          'bounds': {'min_x': 0.0, 'max_x': 5.0, 'min_y': 0.0, 'max_y': 5.0},
          'walkable': false,
        };
        final tile = TileModel.fromJson(json);
        expect(tile.walkable, false);
      });

      test('handles integer numeric values', () {
        final json = {
          'id': 'T3',
          'grid_x': 2,
          'grid_y': 3,
          'level': 0,
          'bounds': {'min_x': 0, 'max_x': 10, 'min_y': 0, 'max_y': 10},
          'walkable': true,
        };
        final tile = TileModel.fromJson(json);
        expect(tile.gridX, 2.0);
        expect(tile.gridY, 3.0);
        expect(tile.minX, 0.0);
        expect(tile.maxX, 10.0);
      });
    });

    group('containsPoint', () {
      late TileModel tile;

      setUp(() {
        tile = TileModel(
          id: 'T1',
          gridX: 0,
          gridY: 0,
          level: 0,
          minX: 0.0,
          maxX: 10.0,
          minY: 0.0,
          maxY: 10.0,
          walkable: true,
        );
      });

      test('returns true for point strictly inside', () {
        expect(tile.containsPoint(5.0, 5.0), isTrue);
      });

      test('returns true for point on min boundary', () {
        expect(tile.containsPoint(0.0, 0.0), isTrue);
      });

      test('returns true for point on max boundary', () {
        expect(tile.containsPoint(10.0, 10.0), isTrue);
      });

      test('returns false for point to the left', () {
        expect(tile.containsPoint(-1.0, 5.0), isFalse);
      });

      test('returns false for point to the right', () {
        expect(tile.containsPoint(11.0, 5.0), isFalse);
      });

      test('returns false for point above', () {
        expect(tile.containsPoint(5.0, -1.0), isFalse);
      });

      test('returns false for point below', () {
        expect(tile.containsPoint(5.0, 11.0), isFalse);
      });

      test('returns false for point completely outside', () {
        expect(tile.containsPoint(100.0, 100.0), isFalse);
      });
    });
  });
}
