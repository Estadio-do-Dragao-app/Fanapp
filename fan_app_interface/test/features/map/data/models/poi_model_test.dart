import 'package:flutter_test/flutter_test.dart';
import 'package:fan_app_interface/features/map/data/models/poi_model.dart';

void main() {
  group('POIModel', () {
    group('fromJson', () {
      test('parses valid JSON', () {
        final json = {
          'id': 'poi-1',
          'name': 'Bathroom',
          'type': 'restroom',
          'description': 'Ground floor WC',
          'x': 10.5,
          'y': 20.3,
          'level': 0,
        };
        final poi = POIModel.fromJson(json);
        expect(poi.id, 'poi-1');
        expect(poi.name, 'Bathroom');
        expect(poi.category, 'restroom');
        expect(poi.description, 'Ground floor WC');
        expect(poi.x, 10.5);
        expect(poi.y, 20.3);
        expect(poi.level, 0);
      });

      test('uses "type" field for category', () {
        final json = {'id': '1', 'type': 'food', 'x': 0.0, 'y': 0.0, 'level': 0};
        final poi = POIModel.fromJson(json);
        expect(poi.category, 'food');
      });

      test('handles missing id with default', () {
        final json = {'x': 0.0, 'y': 0.0, 'level': 0};
        final poi = POIModel.fromJson(json);
        expect(poi.id, 'unknown_poi');
      });

      test('handles missing name with default', () {
        final json = {'id': '1', 'x': 0.0, 'y': 0.0, 'level': 0};
        final poi = POIModel.fromJson(json);
        expect(poi.name, 'Unnamed');
      });

      test('handles missing type with default', () {
        final json = {'id': '1', 'x': 0.0, 'y': 0.0, 'level': 0};
        final poi = POIModel.fromJson(json);
        expect(poi.category, 'unknown');
      });

      test('handles missing description with empty string', () {
        final json = {'id': '1', 'x': 0.0, 'y': 0.0, 'level': 0};
        final poi = POIModel.fromJson(json);
        expect(poi.description, '');
      });

      test('handles missing x/y with 0.0', () {
        final json = {'id': '1', 'level': 0};
        final poi = POIModel.fromJson(json);
        expect(poi.x, 0.0);
        expect(poi.y, 0.0);
      });

      test('handles missing level with 0', () {
        final json = {'id': '1'};
        final poi = POIModel.fromJson(json);
        expect(poi.level, 0);
      });

      test('handles integer id field', () {
        final json = {'id': 42, 'x': 0.0, 'y': 0.0, 'level': 0};
        final poi = POIModel.fromJson(json);
        expect(poi.id, '42');
      });
    });

    group('toJson', () {
      test('serializes all fields correctly', () {
        final poi = POIModel(
          id: 'poi-2',
          name: 'Coffee Shop',
          category: 'cafe',
          description: 'Level 1 café',
          x: 5.0,
          y: 8.0,
          level: 1,
        );
        final json = poi.toJson();
        expect(json['id'], 'poi-2');
        expect(json['name'], 'Coffee Shop');
        expect(json['type'], 'cafe'); // category maps back to 'type' in API
        expect(json['description'], 'Level 1 café');
        expect(json['x'], 5.0);
        expect(json['y'], 8.0);
        expect(json['level'], 1);
      });

      test('category field is serialized as "type"', () {
        final poi = POIModel(id: '1', name: 'A', category: 'bar', x: 0, y: 0, level: 0);
        final json = poi.toJson();
        expect(json.containsKey('type'), isTrue);
        expect(json.containsKey('category'), isFalse);
      });
    });

    test('default description is empty string', () {
      final poi = POIModel(id: '1', name: 'X', category: 'info', x: 0, y: 0, level: 0);
      expect(poi.description, '');
    });
  });
}
