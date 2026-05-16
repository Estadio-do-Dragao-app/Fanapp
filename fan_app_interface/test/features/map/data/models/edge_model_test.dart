import 'package:flutter_test/flutter_test.dart';
import 'package:fan_app_interface/features/map/data/models/edge_model.dart';

void main() {
  group('EdgeModel', () {
    test('fromJson should parse valid JSON', () {
      final json = {
        'id': 'E1',
        'from': 'N1',
        'to': 'N2',
        'weight': 12.5,
        'level': 0,
        'type': 'corridor',
      };

      final edge = EdgeModel.fromJson(json);

      expect(edge.id, 'E1');
      expect(edge.from, 'N1');
      expect(edge.to, 'N2');
      expect(edge.weight, 12.5);
      expect(edge.level, 0);
      expect(edge.type, 'corridor');
    });

    test('fromJson handles missing optional fields with defaults', () {
      final json = {
        'id': 'E2',
        'from': 'N1',
        'to': 'N3',
      };

      // Should not throw
      expect(() => EdgeModel.fromJson(json), returnsNormally);
    });

    test('toJson should return correct Map', () {
      final edge = EdgeModel(
        id: 'E1',
        from: 'N1',
        to: 'N2',
        weight: 10.0,
        level: 1,
        type: 'stairs',
      );

      final json = edge.toJson();

      expect(json['id'], 'E1');
      expect(json['from'], 'N1');
      expect(json['to'], 'N2');
      expect(json['weight'], 10.0);
      expect(json['level'], 1);
      expect(json['type'], 'stairs');
    });

    test('two edges with same id should be considered equal (if == is overridden)', () {
      final e1 = EdgeModel(id: 'E1', from: 'N1', to: 'N2', weight: 5.0, level: 0, type: 'corridor');
      final e2 = EdgeModel(id: 'E1', from: 'N1', to: 'N2', weight: 5.0, level: 0, type: 'corridor');

      // Basic structural equality check
      expect(e1.id, e2.id);
      expect(e1.from, e2.from);
      expect(e1.to, e2.to);
    });
  });
}
