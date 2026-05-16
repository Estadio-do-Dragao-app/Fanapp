import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:fan_app_interface/features/map/data/services/local_map_cache.dart';
import 'package:fan_app_interface/features/map/data/models/node_model.dart';
import 'package:fan_app_interface/features/map/data/models/edge_model.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_test_');
    Hive.init(tempDir.path);
    await Hive.openBox(LocalMapCache.boxName);
  });

  tearDown(() async {
    await LocalMapCache.clear();
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk();
    await tempDir.delete(recursive: true);
  });

  group('LocalMapCache', () {
    test('saveNodes and getNodes round-trips correctly', () async {
      final nodes = [
        NodeModel(id: 'n1', x: 1.0, y: 2.0, level: 0, type: 'corridor'),
        NodeModel(id: 'n2', x: 3.0, y: 4.0, level: 1, type: 'stairs'),
      ];

      await LocalMapCache.saveNodes(nodes);
      final loaded = LocalMapCache.getNodes();

      expect(loaded.length, 2);
      expect(loaded.first.id, 'n1');
      expect(loaded.last.type, 'stairs');
    });

    test('getNodes returns empty list when cache is empty', () {
      LocalMapCache.clear();
      final loaded = LocalMapCache.getNodes();
      expect(loaded, isEmpty);
    });

    test('saveEdges and getEdges round-trips correctly', () async {
      final edges = [
        EdgeModel(id: 'e1', fromId: 'n1', toId: 'n2', weight: 10.0),
      ];

      await LocalMapCache.saveEdges(edges);
      final loaded = LocalMapCache.getEdges();

      expect(loaded.length, 1);
      expect(loaded.first.id, 'e1');
    });

    test('getEdges returns empty list when cache is empty', () {
      LocalMapCache.clear();
      final loaded = LocalMapCache.getEdges();
      expect(loaded, isEmpty);
    });

    test('hasValidCache returns false initially', () {
      LocalMapCache.clear();
      expect(LocalMapCache.hasValidCache(), isFalse);
    });

    test('hasValidCache returns true after saving nodes', () async {
      await LocalMapCache.saveNodes([]);
      expect(LocalMapCache.hasValidCache(), isTrue);
    });

    test('clear removes all data', () async {
      await LocalMapCache.saveNodes([NodeModel(id: 'n1', x: 0, y: 0, level: 0, type: 'node')]);
      await LocalMapCache.clear();
      expect(LocalMapCache.getNodes(), isEmpty);
      expect(LocalMapCache.hasValidCache(), isFalse);
    });

    test('route cache (LRU) stores and retrieves', () {
      const key = 'test_route_key';
      const data = {'route': 'test'};

      LocalMapCache.saveRouteToCache(key, data);
      final cached = LocalMapCache.getRouteFromCache(key);
      expect(cached, data);
    });

    test('route cache respects max size (20)', () {
      for (int i = 0; i < 25; i++) {
        LocalMapCache.saveRouteToCache('key_$i', i);
      }
      expect(LocalMapCache.getRouteFromCache('key_0'), isNull);
      expect(LocalMapCache.getRouteFromCache('key_24'), 24);
    });

    test('generateRouteKey produces consistent string', () {
      final key = LocalMapCache.generateRouteKey(
        startX: 41.1619,
        startY: -8.5836,
        startLevel: 0,
        destinationType: 'poi',
        destinationId: 'wc_1',
        avoidStairs: true,
      );
      expect(key, contains('41.1619'));
      expect(key, contains('-8.5836'));
      expect(key, contains('poi_wc_1_true'));
    });
  });
}