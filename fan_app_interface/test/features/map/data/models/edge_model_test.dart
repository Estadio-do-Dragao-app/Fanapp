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
      };

      final edge = EdgeModel.fromJson(json);

      expect(edge.id, 'E1');
      expect(edge.fromId, 'N1');
      expect(edge.toId, 'N2');
      expect(edge.weight, 12.5);
    });

    test('fromJson handles alternative field names (from_id, to_id, w)', () {
      final json = {
        'id': 'E2',
        'from_id': 'N3',
        'to_id': 'N4',
        'w': 8.0,
      };

      final edge = EdgeModel.fromJson(json);
      expect(edge.id, 'E2');
      expect(edge.fromId, 'N3');
      expect(edge.toId, 'N4');
      expect(edge.weight, 8.0);
    });

    test('fromJson provides defaults for missing fields', () {
      final json = {
        'id': 'E3',
      };

      final edge = EdgeModel.fromJson(json);
      expect(edge.id, 'E3');
      expect(edge.fromId, 'unknown_from');
      expect(edge.toId, 'unknown_to');
      expect(edge.weight, 1.0);
    });

    test('toJson should return correct Map', () {
      final edge = EdgeModel(
        id: 'E1',
        fromId: 'N1',
        toId: 'N2',
        weight: 10.0,
      );

      final json = edge.toJson();

      expect(json['id'], 'E1');
      expect(json['from'], 'N1');
      expect(json['to'], 'N2');
      expect(json['w'], 10.0);
    });
  });
}