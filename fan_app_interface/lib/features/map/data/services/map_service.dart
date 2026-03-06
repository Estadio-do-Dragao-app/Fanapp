import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/node_model.dart';
import '../models/edge_model.dart';
import '../models/poi_model.dart';
import '../models/tile_model.dart';
import 'local_map_cache.dart';
import '../../../../core/config/api_config.dart';

/// Service para comunicar com o Map-Service
/// Backend: https://github.com/Estadio-do-Dragao-app/Map-Service
class MapService {
  static const String baseUrl = ApiConfig.mapService;

  /// GET /map - Retorna mapa completo (nodes, edges, closures)
  Future<Map<String, dynamic>> getCompleteMap() async {
    final response = await http
        .get(Uri.parse('$baseUrl/map'))
        .timeout(const Duration(seconds: ApiConfig.httpTimeout));

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
      final response = await http
          .get(Uri.parse('$baseUrl/nodes'))
          .timeout(const Duration(seconds: ApiConfig.httpTimeout));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final nodes = data.map((json) => NodeModel.fromJson(json)).toList();

        // Salva no cache
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

  /// GET /edges - Todas as arestas (com cache)
  Future<List<EdgeModel>> getAllEdges() async {
    // Tenta cache primeiro (só se nodes também existirem para consistência)
    if (LocalMapCache.hasValidCache()) {
      final cachedEdges = LocalMapCache.getEdges();
      if (cachedEdges.isNotEmpty) return cachedEdges;
    }

    try {
      final response = await http
          .get(Uri.parse('$baseUrl/edges'))
          .timeout(const Duration(seconds: ApiConfig.httpTimeout));

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
  /// Filtramos client-side para tipos relevantes
  /// Tipos POI: room, restroom, bar, emergency_exit, first_aid, stairs, elevator, ramp
  Future<List<POIModel>> getAllPOIs() async {
    // Tipos que consideramos POIs (excluindo corridor, normal, door)
    const poiTypes = [
      'room',
      'restroom',
      'bar',
      'emergency_exit',
      'first_aid',
      'stairs',
      'ramp',
      'elevator',
    ];

    final response = await http
        .get(Uri.parse('$baseUrl/nodes'))
        .timeout(const Duration(seconds: ApiConfig.httpTimeout));

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      // Filtrar apenas nós que são POIs
      final pois = data
          .where((node) => poiTypes.contains(node['type']))
          .map((json) => POIModel.fromJson(json))
          .toList();
      print(
        '[MapService] ${pois.length} POIs carregados de ${data.length} nós',
      );
      return pois;
    } else {
      throw Exception('Failed to load POIs: ${response.statusCode}');
    }
  }

  /// GET /nodes - Filtrar POIs por piso
  Future<List<POIModel>> getPOIsByFloor(int level) async {
    final allPOIs = await getAllPOIs();
    return allPOIs.where((poi) => poi.level == level).toList();
  }

  /// GET /rooms - Todas as salas
  Future<List<dynamic>> getAllRooms({int? level}) async {
    try {
      final url = level != null
          ? '$baseUrl/rooms?level=$level'
          : '$baseUrl/rooms';
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: ApiConfig.httpTimeout));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List) {
          return data;
        }
        return [];
      } else {
        return [];
      }
    } catch (e) {
      print('Erro ao carregar rooms: $e');
      return [];
    }
  }

  /// GET /rooms/{room_id} - Buscar uma sala específica por ID
  Future<NodeModel?> getRoomById(String roomId) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/rooms/$roomId'))
          .timeout(const Duration(seconds: ApiConfig.httpTimeout));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return NodeModel.fromJson(data);
      } else {
        print(
          '[MapService] Room $roomId não encontrada: ${response.statusCode}',
        );
        return null;
      }
    } catch (e) {
      print('[MapService] Erro ao buscar room $roomId: $e');
      return null;
    }
  }

  /// GET /closures - Corredores fechados (para emergências)
  Future<List<Map<String, dynamic>>> getClosures() async {
    final response = await http
        .get(Uri.parse('$baseUrl/closures'))
        .timeout(const Duration(seconds: ApiConfig.httpTimeout));

    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    } else {
      throw Exception('Failed to load closures: ${response.statusCode}');
    }
  }

  /// GET /health - Verificar se o serviço está online
  Future<bool> isServiceHealthy() async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/health'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Backward compatibility: delegates to getRoomById
  /// Used by ticket-based navigation (seat → room)
  Future<NodeModel?> getSeatById(String seatId) async {
    return getRoomById(seatId);
  }

  /// GET /maps/grid/tiles - Buscar todos os tiles do grid
  /// Usado para verificar se uma posição é walkable
  Future<List<TileModel>> getAllTiles({int? level}) async {
    try {
      final url = level != null
          ? '$baseUrl/maps/grid/tiles?level=$level'
          : '$baseUrl/maps/grid/tiles';
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: ApiConfig.httpTimeout));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> tiles = data['tiles'] ?? [];
        print('[MapService] ${tiles.length} tiles carregados');
        return tiles.map((json) => TileModel.fromJson(json)).toList();
      } else {
        print('[MapService] Erro ao carregar tiles: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('[MapService] Erro ao carregar tiles: $e');
      return [];
    }
  }
}
