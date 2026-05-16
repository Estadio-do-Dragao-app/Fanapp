import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:fan_app_interface/features/map/data/services/local_map_cache.dart';
import 'package:fan_app_interface/features/map/data/models/node_model.dart';
import 'package:fan_app_interface/features/map/data/models/poi_model.dart';

void main() {
  setUpAll(() async {
    final tempDir = await Directory.systemTemp.createTemp('hive_test_');
    Hive.init(tempDir.path);
    await Hive.openBox(LocalMapCache.boxName);
  });

  tearDown(() async {
    await LocalMapCache.clear();
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk();
  });

  group('LocalMapCache - extended coverage', () {
    test('saveNodes and loadNodes round-trips correctly', () async {
      final nodes = [
        NodeModel(id: 'n1', x: 1.0, y: 2.0, level: 0, type: 'corridor'),
        NodeModel(id: 'n2', x: 3.0, y: 4.0, level: 1, type: 'stairs'),
      ];

      await LocalMapCache.saveNodes(nodes);
      final loaded = await LocalMapCache.loadNodes();

      expect(loaded, isNotNull);
      expect(loaded!.length, 2);
      expect(loaded.first.id, 'n1');
      expect(loaded.last.type, 'stairs');
    });

    test('loadNodes returns null when cache is empty', () async {
      final loaded = await LocalMapCache.loadNodes();
      expect(loaded, isNull);
    });

    test('savePOIs and loadPOIs round-trips correctly', () async {
      final pois = [
        POIModel(id: 'p1', name: 'WC', category: 'wc', x: 0, y: 0, level: 0),
      ];

      await LocalMapCache.savePOIs(pois);
      final loaded = await LocalMapCache.loadPOIs();

      expect(loaded, isNotNull);
      expect(loaded!.length, 1);
      expect(loaded.first.id, 'p1');
    });

    test('loadPOIs returns null when cache is empty', () async {
      final loaded = await LocalMapCache.loadPOIs();
      expect(loaded, isNull);
    });

    test('isExpired returns true for old timestamp', () async {
      final expired = await LocalMapCache.isExpired(
        const Duration(milliseconds: 1),
      );
      // With no data saved, it should be considered expired
      expect(expired, isTrue);
    });

    test('isExpired returns false immediately after saving', () async {
      final nodes = [NodeModel(id: 'x', x: 0, y: 0, level: 0, type: 'node')];
      await LocalMapCache.saveNodes(nodes);

      final expired = await LocalMapCache.isExpired(const Duration(hours: 1));
      expect(expired, isFalse);
    });

    test('clear removes saved nodes', () async {
      await LocalMapCache.saveNodes([
        NodeModel(id: 'n_clear', x: 0, y: 0, level: 0, type: 'node'),
      ]);
      await LocalMapCache.clear();
      final loaded = await LocalMapCache.loadNodes();
      expect(loaded, isNull);
    });

    test('saving empty list is handled gracefully', () async {
      await LocalMapCache.saveNodes([]);
      final loaded = await LocalMapCache.loadNodes();
      expect(loaded, isNotNull);
      expect(loaded!, isEmpty);
    });
  });
}
