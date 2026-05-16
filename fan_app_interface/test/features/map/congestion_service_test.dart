import 'package:flutter_test/flutter_test.dart';
import 'package:fan_app_interface/features/map/data/services/congestion_service.dart';

void main() {
  group('CellCongestionData', () {
    test('fromJson should parse valid JSON', () {
      final json = {
        'cell_id': 'cell_1',
        'congestion_level': 0.75,
        'people_count': 30,
        'capacity': 40,
        'timestamp': '2026-05-12T21:00:00Z',
        'level': 1,
      };

      final data = CellCongestionData.fromJson(json);

      expect(data.cellId, 'cell_1');
      expect(data.congestionLevel, 0.75);
      expect(data.peopleCount, 30);
      expect(data.capacity, 40);
      expect(data.timestamp, '2026-05-12T21:00:00Z');
      expect(data.level, 1);
    });

    test('fromJson should use default values for missing fields', () {
      final json = <String, dynamic>{};
      final data = CellCongestionData.fromJson(json);

      expect(data.cellId, '');
      expect(data.congestionLevel, 0.0);
      expect(data.peopleCount, 0);
      expect(data.capacity, 50);
      expect(data.timestamp, '');
      expect(data.level, 0);
    });
  });

  group('CongestionService', () {
    test('getStadiumHeatmap should return empty data when no cells stored', () {
      final service = CongestionService();
      final heatmap = service.getStadiumHeatmap();

      expect(heatmap.sections, isEmpty);
      expect(heatmap.totalSections, 0);
      expect(heatmap.averageCongestion, 0);
    });

    // Note: Testing private methods or actual MQTT integration would require mocks
    // which are not currently available in this simple test.
  });
}
