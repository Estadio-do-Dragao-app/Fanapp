import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/node_model.dart';
import '../models/edge_model.dart';
import '../models/poi_model.dart';
import '../models/gate_model.dart';
import '../models/tile_model.dart';
import 'local_map_cache.dart';
import '../../../../core/config/api_config.dart';
import '../../../../core/config/map_config.dart';
import '../../../../core/config/app_env.dart';

class MapService {
  final http.Client _client;

  MapService({http.Client? client}) : _client = client ?? http.Client();

  static String get baseUrl => ApiConfig.mapService;

  Future<http.Response> _performGet(String url, {Map<String, String>? headers}) async {
    final stopwatch = Stopwatch()..start();
    try {
      final response = await _client
          .get(Uri.parse(url), headers: headers)
          .timeout(Duration(seconds: ApiConfig.httpTimeout));
      stopwatch.stop();
      debugPrint('[PerformanceInterceptor] GET $url completed in ${stopwatch.elapsedMilliseconds}ms');
      return response;
    } catch (e) {
      stopwatch.stop();
      debugPrint('[PerformanceInterceptor] GET $url failed after ${stopwatch.elapsedMilliseconds}ms: $e');
      rethrow;
    }
  }

  POIModel _applyForcedEmergencyExit(POIModel poi) {
    final normalizedName = poi.name.trim().toLowerCase();
    if (!AppEnv.forcedEmergencyExitNames.contains(normalizedName)) {
      return poi;
    }

    if (poi.category.toLowerCase() == 'emergency_exit') {
      return poi;
    }

    return POIModel(
      id: poi.id,
      name: poi.name,
      category: 'emergency_exit',
      description: poi.description,
      x: poi.x,
      y: poi.y,
      level: poi.level,
    );
  }

  /// GET /map - Retorna mapa completo (nodes, edges, closures)
  Future<Map<String, dynamic>> getCompleteMap() async {
    final response = await _performGet('$baseUrl/map', headers: {'X-API-Key': AppEnv.mapApiKey});

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load map: ${response.statusCode}');
    }
  }

  /// GET /nodes - Todos os nós do grafo (com cache)
  Future<List<NodeModel>> getAllNodes() async {
    // Tenta cache primeiro
    if (LocalMapCache.hasValidCache()) {
      final cachedNodes = LocalMapCache.getNodes();
      if (cachedNodes.isNotEmpty) return cachedNodes;
    }

    try {
      final response = await _performGet('$baseUrl/nodes');

      if (response.statusCode == 200) {

        // PERFORMANCE: Use compute to parse 6000+ nodes off the main thread
        final nodes = await compute(_parseNodesList, response.body);

        // Salva no cache (sem seats para performance)
        await LocalMapCache.saveNodes(nodes);

        return nodes;
      } else {
        throw Exception('Failed to load nodes: ${response.statusCode}');
      }
    } catch (e) {
      // Se falhar API, tenta retornar o que tiver no cache mesmo que antigo
      final cachedNodes = LocalMapCache.getNodes();
      if (cachedNodes.isNotEmpty) return cachedNodes;
      rethrow;
    }
  }

  static List<NodeModel> _parseNodesList(String responseBody) {
    final List<dynamic> data = json.decode(responseBody);
    return data
        .map((json) => NodeModel.fromJson(json))
        .where((node) => node.type != 'seat')
        .toList();
  }

  /// GET /edges - Todas as arestas (com cache)
  Future<List<EdgeModel>> getAllEdges() async {
    // Tenta cache primeiro (só se nodes também existirem para consistência)
    if (LocalMapCache.hasValidCache()) {
      final cachedEdges = LocalMapCache.getEdges();
      if (cachedEdges.isNotEmpty) return cachedEdges;
    }

    try {
      final response = await _performGet('$baseUrl/edges');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final edges = data.map((json) => EdgeModel.fromJson(json)).toList();

        // Salva no cache
        await LocalMapCache.saveEdges(edges);

        return edges;
      } else {
        throw Exception('Failed to load edges: ${response.statusCode}');
      }
    } catch (e) {
      final cachedEdges = LocalMapCache.getEdges();
      if (cachedEdges.isNotEmpty) return cachedEdges;
      rethrow;
    }
  }

  /// GET /nodes - Buscar todos os POIs a partir dos nós
  /// O endpoint /pois do backend é muito restritivo, por isso filtramos client-side
  /// Tipos POI: restroom, food, bar, emergency_exit, first_aid, information
  Future<List<POIModel>> getAllPOIs() async {
    // Tipos que consideramos POIs (excluindo corridor, normal, seat, row_aisle)
    const poiTypes = [
      'restroom',
      'food',
      'bar',
      'emergency_exit',
      'first_aid',
      'information',
      'poi', // generic type
      'entrance',
      'wc',
      'library',
      'parking',
      'cafe',
      'restaurant',
      'cgd',
      'departments',
      'department',
      'departamento',
    ];

    final response = await _performGet('$baseUrl/nodes');

    List<POIModel> staticPois = [];
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      staticPois = data
          .where((node) => poiTypes.contains(node['type']))
          .map((json) => POIModel.fromJson(json))
          .toList();
      debugPrint(
        '[MapService] ${staticPois.length} POIs estáticos carregados de ${data.length} nós',
      );
    }

    // Merge com POIs dinâmicos do OSM (apenas em modo outdoor)
    if (MapConfig.useOSMPOIs) {
      try {
        final osmPois = await getOSMPOIs();
        final existingNames = staticPois
            .map((p) => p.name.toLowerCase())
            .toSet();
        final newOsmPois = osmPois
            .where((p) => !existingNames.contains(p.name.toLowerCase()))
            .toList();
        staticPois.addAll(newOsmPois);
        debugPrint(
          '[MapService] +${newOsmPois.length} POIs do OSM (${osmPois.length} total, ${osmPois.length - newOsmPois.length} duplicados)',
        );
      } catch (e) {
        debugPrint(
          '[MapService] Falha ao buscar POIs OSM: $e (usando apenas estáticos)',
        );
      }
    }

    return staticPois
        .map(_applyForcedEmergencyExit)
        .where(
          (poi) =>
              poi.category.toLowerCase() != 'stairs' &&
              poi.category.toLowerCase() != 'ramp',
        )
        .toList();
  }

  /// GET /pois/osm - Buscar POIs dinâmicos do OpenStreetMap
  Future<List<POIModel>> getOSMPOIs() async {
    final response = await _performGet('$baseUrl/pois/osm');

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List<dynamic> pois = data['pois'] ?? [];
      return pois.map((json) => POIModel.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load OSM POIs: ${response.statusCode}');
    }
  }

  /// GET /nodes - Filtrar POIs por piso
  Future<List<POIModel>> getPOIsByFloor(int level) async {
    final allPOIs = await getAllPOIs();
    return allPOIs.where((poi) => poi.level == level).toList();
  }

  /// GET /gates - Todos os portões/entradas
  Future<List<GateModel>> getAllGates() async {
    final response = await _performGet('$baseUrl/gates');

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => GateModel.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load gates: ${response.statusCode}');
    }
  }

  /// GET /closures - Corredores fechados (para emergências)
  Future<List<Map<String, dynamic>>> getClosures() async {
    final response = await _performGet('$baseUrl/closures');

    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    } else {
      throw Exception('Failed to load closures: ${response.statusCode}');
    }
  }

  /// GET /health - Verificar se o serviço está online
  Future<bool> isServiceHealthy() async {
    try {
      final response = await _performGet('$baseUrl/health', headers: {'Content-Type': 'application/json'});
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// GET /seats - Todos os lugares
  Future<List<dynamic>> getAllSeats() async {
    try {
      // Nota: Endpoint é /seats diretamente, não /api/seats
      final response = await _performGet('$baseUrl/seats');

      if (response.statusCode == 200) {
        // Formato esperado: {"seats": [...]} ou [...]
        // Verificando resposta:
        final data = json.decode(response.body);
        if (data is Map && data.containsKey('seats')) {
          return data['seats'];
        } else if (data is List) {
          return data;
        }
        return [];
      } else {
        return [];
      }
    } catch (e) {
      debugPrint('Erro ao carregar seats: $e');
      return [];
    }
  }

  /// GET /seats/{seat_id} - Buscar um seat específico por ID
  /// Usado para obter coordenadas do lugar do utilizador
  Future<NodeModel?> getSeatById(String seatId) async {
    try {
      final response = await _performGet('$baseUrl/seats/$seatId');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return NodeModel.fromJson(data);
      } else {
        debugPrint(
          '[MapService] Seat $seatId não encontrado: ${response.statusCode}',
        );
        return null;
      }
    } catch (e) {
      debugPrint('[MapService] Erro ao buscar seat $seatId: $e');
      return null;
    }
  }

  /// GET /maps/grid/tiles - Buscar todos os tiles do grid
  /// Usado para verificar se uma posição é walkable
  Future<List<TileModel>> getAllTiles({int? level}) async {
    try {
      final url = level != null
          ? '$baseUrl/maps/grid/tiles?level=$level'
          : '$baseUrl/maps/grid/tiles';
      final response = await _performGet(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> tiles = data['tiles'] ?? [];
        debugPrint('[MapService] ${tiles.length} tiles carregados');
        return tiles.map((json) => TileModel.fromJson(json)).toList();
      } else {
        debugPrint('[MapService] Erro ao carregar tiles: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('[MapService] Erro ao carregar tiles: $e');
      return [];
    }
  }
}
