import 'package:hive_flutter/hive_flutter.dart';
import '../models/node_model.dart';
import '../models/edge_model.dart';
import 'dart:convert';
import 'dart:collection';

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
    _routeCache.clear();
  }

  /// Verifica se existe cache válido
  static bool hasValidCache() {
    return _box.containsKey(keyNodes) && _box.containsKey(keyEdges);
  }

  // ==================== LRU CACHE PARA ROTAS (MEMÓRIA) ====================
  
  static final LinkedHashMap<String, dynamic> _routeCache = LinkedHashMap<String, dynamic>();
  static const int _maxRouteCacheSize = 20;

  /// Gera a chave do cache baseada nos parâmetros da rota
  static String generateRouteKey({
    required double startX,
    required double startY,
    required int startLevel,
    required String destinationType,
    required String destinationId,
    required bool avoidStairs,
  }) {
    // Arredondamos as coordenadas para evitar misses por pequenas diferenças no GPS (ex: 5 metros)
    // Uma diferença de 0.0001 em latitude/longitude é ~11 metros.
    final sx = startX.toStringAsFixed(4);
    final sy = startY.toStringAsFixed(4);
    return '${sx}_${sy}_${startLevel}_${destinationType}_${destinationId}_$avoidStairs';
  }

  static void saveRouteToCache(String key, dynamic routeData) {
    if (_routeCache.containsKey(key)) {
      _routeCache.remove(key);
    }
    _routeCache[key] = routeData;

    if (_routeCache.length > _maxRouteCacheSize) {
      _routeCache.remove(_routeCache.keys.first);
    }
  }

  static dynamic getRouteFromCache(String key) {
    if (_routeCache.containsKey(key)) {
      final routeData = _routeCache.remove(key);
      _routeCache[key] = routeData; // Mais recente
      return routeData;
    }
    return null;
  }
}
