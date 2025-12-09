import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/node_model.dart';
import '../models/poi_model.dart';
import '../models/gate_model.dart';

/// Service para comunicar com o Map-Service
/// Backend: https://github.com/Estadio-do-Dragao-app/Map-Service
class MapService {
  static const String baseUrl = 'http://10.0.2.2:8000'; // Alterar para produção
  
  /// GET /api/map - Retorna mapa completo (nodes, edges, closures)
  Future<Map<String, dynamic>> getCompleteMap() async {
    final response = await http.get(Uri.parse('$baseUrl/api/map'));
    
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load map: ${response.statusCode}');
    }
  }
  
  /// GET /api/nodes - Todos os nós do grafo
  Future<List<NodeModel>> getAllNodes() async {
    final response = await http.get(Uri.parse('$baseUrl/api/nodes'));
    
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => NodeModel.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load nodes: ${response.statusCode}');
    }
  }
  
  /// GET /api/pois - Todos os POIs (WC, food, exits, etc.)
  Future<List<POIModel>> getAllPOIs() async {
    final response = await http.get(Uri.parse('$baseUrl/api/pois'));
    
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => POIModel.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load POIs: ${response.statusCode}');
    }
  }
  
  /// GET /api/pois - Filtrar POIs por piso
  Future<List<POIModel>> getPOIsByFloor(int level) async {
    final allPOIs = await getAllPOIs();
    return allPOIs.where((poi) => poi.level == level).toList();
  }
  
  /// GET /api/gates - Todos os portões/entradas
  Future<List<GateModel>> getAllGates() async {
    final response = await http.get(Uri.parse('$baseUrl/api/gates'));
    
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => GateModel.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load gates: ${response.statusCode}');
    }
  }
  
  /// GET /api/closures - Corredores fechados (para emergências)
  Future<List<Map<String, dynamic>>> getClosures() async {
    final response = await http.get(Uri.parse('$baseUrl/api/closures'));
    
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    } else {
      throw Exception('Failed to load closures: ${response.statusCode}');
    }
  }
  
  /// GET /health - Verificar se o serviço está online
  Future<bool> isServiceHealthy() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));
      
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
