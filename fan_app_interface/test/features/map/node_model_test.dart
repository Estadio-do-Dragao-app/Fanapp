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
  });
}
