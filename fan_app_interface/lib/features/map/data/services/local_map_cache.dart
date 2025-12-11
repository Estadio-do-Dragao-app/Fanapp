import 'package:hive_flutter/hive_flutter.dart';
import '../models/node_model.dart';
import '../models/edge_model.dart';
import 'dart:convert';

/// Serviço responsável pelo cache local do mapa usando Hive
class LocalMapCache {
  static const String boxName = 'map_cache';

  // Cache keys
  static const String keyNodes = 'nodes';
  static const String keyEdges = 'edges';
  static const String keyPOIs = 'pois';
  static const String keyCacheTime = 'last_update';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(boxName);
  }

  static Box get _box => Hive.box(boxName);

  /// Salva nós no cache
  static Future<void> saveNodes(List<NodeModel> nodes) async {
    final jsonList = nodes.map((n) => n.toJson()).toList();
    await _box.put(keyNodes, jsonEncode(jsonList));
    await _box.put(keyCacheTime, DateTime.now().toIso8601String());
  }

  /// Obtém nós do cache
  static List<NodeModel> getNodes() {
    final jsonString = _box.get(keyNodes);
    if (jsonString == null) return [];

    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.map((j) => NodeModel.fromJson(j)).toList();
    } catch (e) {
      print('Erro ao ler nodes do cache: $e');
      return [];
    }
  }

  /// Salva arestas no cache
  static Future<void> saveEdges(List<EdgeModel> edges) async {
    final jsonList = edges.map((e) => e.toJson()).toList();
    await _box.put(keyEdges, jsonEncode(jsonList));
  }

  /// Obtém arestas do cache
  static List<EdgeModel> getEdges() {
    final jsonString = _box.get(keyEdges);
    if (jsonString == null) return [];

    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.map((j) => EdgeModel.fromJson(j)).toList();
    } catch (e) {
      print('Erro ao ler edges do cache: $e');
      return [];
    }
  }

  /// Limpa o cache
  static Future<void> clear() async {
    await _box.clear();
  }

  /// Verifica se existe cache válido
  static bool hasValidCache() {
    return _box.containsKey(keyNodes) && _box.containsKey(keyEdges);
  }
}
