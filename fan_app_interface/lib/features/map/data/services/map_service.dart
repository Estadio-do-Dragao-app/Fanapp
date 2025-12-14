import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/node_model.dart';
import '../models/edge_model.dart';
import '../models/poi_model.dart';
import '../models/gate_model.dart';
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
        // PERFORMANCE: Filtrar seats - são ~6000+ nodes que não precisamos para navegação
        // Seats são usados apenas para routing (endpoint /route), não para renderização/posição
        final nodes = data
            .map((json) => NodeModel.fromJson(json))
            .where((node) => node.type != 'seat')
            .toList();

        // Meter Seats
        // final nodes = data.map((json) => NodeModel.fromJson(json)).toList();

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
  /// O endpoint /pois do backend é muito restritivo, por isso filtramos client-side
  /// Tipos POI: gate, restroom, food, bar, emergency_exit, first_aid, information, merchandise, stairs, ramp
  Future<List<POIModel>> getAllPOIs() async {
    // Tipos que consideramos POIs (excluindo corridor, normal, seat, row_aisle)
    const poiTypes = [
      'gate',
      'restroom',
      'food',
      'bar',
      'emergency_exit',
      'first_aid',
      'information',
      'merchandise',
      'stairs',
      'ramp',
      'poi', // Tipo genérico
      'entrance',
      'shop',
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

  /// GET /gates - Todos os portões/entradas
  Future<List<GateModel>> getAllGates() async {
    final response = await http
        .get(Uri.parse('$baseUrl/gates'))
        .timeout(const Duration(seconds: ApiConfig.httpTimeout));

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => GateModel.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load gates: ${response.statusCode}');
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

  /// GET /seats - Todos os lugares
  Future<List<dynamic>> getAllSeats() async {
    try {
      // Nota: Endpoint é /seats diretamente, não /api/seats
      final response = await http
          .get(Uri.parse('$baseUrl/seats'))
          .timeout(const Duration(seconds: ApiConfig.httpTimeout));

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
      print('Erro ao carregar seats: $e');
      return [];
    }
  }

  /// GET /seats/{seat_id} - Buscar um seat específico por ID
  /// Usado para obter coordenadas do lugar do utilizador
  Future<NodeModel?> getSeatById(String seatId) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/seats/$seatId'))
          .timeout(const Duration(seconds: ApiConfig.httpTimeout));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return NodeModel.fromJson(data);
      } else {
        print(
          '[MapService] Seat $seatId não encontrado: ${response.statusCode}',
        );
        return null;
      }
    } catch (e) {
      print('[MapService] Erro ao buscar seat $seatId: $e');
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
