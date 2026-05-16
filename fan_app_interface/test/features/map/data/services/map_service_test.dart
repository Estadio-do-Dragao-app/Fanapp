import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:fan_app_interface/features/map/data/services/map_service.dart';
import 'package:fan_app_interface/features/map/data/services/local_map_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:io';
import 'package:hive/hive.dart';

class MockHttpClient extends Mock implements http.Client {}

void main() {
  late MapService mapService;
  late MockHttpClient mockHttpClient;

  setUpAll(() async {
    final tempDir = await Directory.systemTemp.createTemp();
    Hive.init(tempDir.path);
    await Hive.openBox(LocalMapCache.boxName);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockHttpClient = MockHttpClient();
    mapService = MapService(client: mockHttpClient);
    
    // Default mock behavior
    registerFallbackValue(Uri());
  });

  tearDown(() async {
    await LocalMapCache.clear();
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk();
  });

  group('MapService', () {
    test('getAllNodes() fetches from API and parses correctly', () async {
      final mockResponse = [
        {
          "id": "node_1",
          "x": 40.0,
          "y": -8.0,
          "level": 0,
          "type": "normal"
        },
        {
          "id": "node_2",
          "x": 40.1,
          "y": -8.1,
          "level": 0,
          "type": "seat" // Should be filtered out
        }
      ];

      when(() => mockHttpClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response(json.encode(mockResponse), 200));

      final nodes = await mapService.getAllNodes();

      expect(nodes.length, 1);
      expect(nodes.first.id, 'node_1');
      expect(nodes.first.type, 'normal');
      verify(() => mockHttpClient.get(any(), headers: any(named: 'headers'))).called(1);
    });

    test('getPOIsByFloor() correctly filters POIs by floor', () async {
      final mockResponse = [
        {
          "id": "poi_1",
          "x": 40.0,
          "y": -8.0,
          "level": 0,
          "type": "restroom",
          "name": "WC Ground",
          "description": ""
        },
        {
          "id": "poi_2",
          "x": 40.1,
          "y": -8.1,
          "level": 1,
          "type": "food",
          "name": "Bar Level 1",
          "description": ""
        }
      ];

      when(() => mockHttpClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response(json.encode(mockResponse), 200));

      final poisLevel0 = await mapService.getPOIsByFloor(0);
      final poisLevel1 = await mapService.getPOIsByFloor(1);

      expect(poisLevel0.length, 1);
      expect(poisLevel0.first.id, 'poi_1');
      expect(poisLevel0.first.level, 0);

      expect(poisLevel1.length, 1);
      expect(poisLevel1.first.id, 'poi_2');
      expect(poisLevel1.first.level, 1);
    });

    test('getSeatById() returns null if not found', () async {
      when(() => mockHttpClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response('Not found', 404));

      final seat = await mapService.getSeatById('invalid_seat');

      expect(seat, isNull);
    });

    test('getSeatById() returns NodeModel if found', () async {
      final mockResponse = {
        "id": "seat_1",
        "x": 40.0,
        "y": -8.0,
        "level": 0,
        "type": "seat"
      };

      when(() => mockHttpClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response(json.encode(mockResponse), 200));

      final seat = await mapService.getSeatById('seat_1');

      expect(seat, isNotNull);
      expect(seat!.id, 'seat_1');
      expect(seat.type, 'seat');
    });
  });
}
