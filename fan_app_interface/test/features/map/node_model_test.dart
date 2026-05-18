import 'package:flutter_test/flutter_test.dart';
import 'package:fan_app_interface/features/map/data/models/node_model.dart';

void main() {
  group('NodeModel', () {
    test('fromJson should parse valid JSON', () {
      final json = {
        'id': 'N1',
        'x': 100.0,
        'y': 200.0,
        'level': 0,
        'type': 'normal',
      };

      final node = NodeModel.fromJson(json);

      expect(node.id, 'N1');
      expect(node.x, 100.0);
      expect(node.y, 200.0);
      expect(node.level, 0);
      expect(node.type, 'normal');
    });

    test('toJson should return valid Map', () {
      final node = NodeModel(
        id: 'N1',
        x: 100.0,
        y: 200.0,
        level: 0,
        type: 'normal',
      );

      final json = node.toJson();

      expect(json['id'], 'N1');
      expect(json['x'], 100.0);
      expect(json['y'], 200.0);
      expect(json['level'], 0);
      expect(json['type'], 'normal');
    });

    test('fromJson provides defaults for missing fields', () {
      final node = NodeModel.fromJson({});
      expect(node.id, 'unknown_node');
      expect(node.x, 0.0);
      expect(node.y, 0.0);
      expect(node.level, 0);
      expect(node.type, 'normal');
    });

    test('fromJson handles integer id', () {
      final node = NodeModel.fromJson({'id': 42, 'x': 1.0, 'y': 2.0, 'level': 0, 'type': 'stairs'});
      expect(node.id, '42');
      expect(node.type, 'stairs');
    });

    test('fromJson handles null values with defaults', () {
      final node = NodeModel.fromJson({'id': null, 'x': null, 'y': null, 'level': null, 'type': null});
      expect(node.id, 'unknown_node');
      expect(node.x, 0.0);
      expect(node.y, 0.0);
      expect(node.level, 0);
      expect(node.type, 'normal');
    });
  });
}
