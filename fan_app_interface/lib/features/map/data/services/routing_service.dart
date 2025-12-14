import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/route_model.dart';
import '../models/node_model.dart';
import '../../../../core/config/api_config.dart';

/// Service para comunicar com o Routing-Service
/// Backend: https://github.com/Estadio-do-Dragao-app/Routing-Service
///
/// Nova API usa POST com coordenadas em vez de GET com node IDs
class RoutingService {
  static const String baseUrl = ApiConfig.routingService;

  /// POST /api/route - Calcula rota entre posição inicial e destino
  ///
  /// [startX], [startY], [startLevel] - Coordenadas da posição inicial
  /// [destinationType] - Tipo de destino: "node", "poi", "seat", "gate"
  /// [destinationId] - ID do destino (ex: "POI_1", "N10", "SEAT_123")
  /// [avoidStairs] - Se deve evitar escadas
  Future<RouteModel> getRoute({
    required double startX,
    required double startY,
    int startLevel = 0,
    required String destinationType,
    required String destinationId,
    bool avoidStairs = false,
  }) async {
    final request = RouteRequest(
      start: Coordinates(x: startX, y: startY, level: startLevel),
      destinationType: destinationType,
      destinationId: destinationId,
      avoidStairs: avoidStairs,
    );

    print(
      '[RoutingService] 🚀 POST /api/route: startLevel=$startLevel, dest=$destinationType:$destinationId',
    );
    print('[RoutingService] 📦 Request body: ${json.encode(request.toJson())}');

    final response = await http.post(
      Uri.parse('$baseUrl/api/route'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(request.toJson()),
    );

    if (response.statusCode == 200) {
      return RouteModel.fromJson(json.decode(response.body));
    } else {
      final errorBody = response.body;
      throw Exception(
        'Failed to get route: ${response.statusCode} - $errorBody',
      );
    }
  }

  /// Calcular rota para um POI
  /// Convenience method para navegação a POIs
  Future<RouteModel> getRouteToPOI({
    required double startX,
    required double startY,
    int startLevel = 0,
    required String poiId,
    bool avoidStairs = false,
  }) {
    return getRoute(
      startX: startX,
      startY: startY,
      startLevel: startLevel,
      destinationType: 'poi',
      destinationId: poiId,
      avoidStairs: avoidStairs,
    );
  }

  /// Calcular rota para um nó específico
  /// Convenience method para navegação direta a nós
  Future<RouteModel> getRouteToNode({
    required double startX,
    required double startY,
    int startLevel = 0,
    required String nodeId,
    bool avoidStairs = false,
  }) {
    return getRoute(
      startX: startX,
      startY: startY,
      startLevel: startLevel,
      destinationType: 'node',
      destinationId: nodeId,
      avoidStairs: avoidStairs,
    );
  }

  /// Calcular rota para um lugar (seat)
  /// Convenience method para navegação ao lugar do bilhete
  Future<RouteModel> getRouteToSeat({
    required double startX,
    required double startY,
    int startLevel = 0,
    required String seatId,
    bool avoidStairs = false,
  }) {
    return getRoute(
      startX: startX,
      startY: startY,
      startLevel: startLevel,
      destinationType: 'seat',
      destinationId: seatId,
      avoidStairs: avoidStairs,
    );
  }

  /// Calcular rota para um portão (gate)
  /// Convenience method para navegação a portões
  Future<RouteModel> getRouteToGate({
    required double startX,
    required double startY,
    int startLevel = 0,
    required String gateId,
    bool avoidStairs = false,
  }) {
    return getRoute(
      startX: startX,
      startY: startY,
      startLevel: startLevel,
      destinationType: 'gate',
      destinationId: gateId,
      avoidStairs: avoidStairs,
    );
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

  /// Calcular rota para coordenadas arbitrárias (usando o nó mais próximo)
  /// Útil quando o backend não reconhece o ID do POI
  /// Implementa fallback para tentar múltiplos nós próximos caso o primeiro falhe
  Future<RouteModel> getRouteToCoordinates({
    required double startX,
    required double startY,
    int startLevel = 0,
    required double endX,
    required double endY,
    required int endLevel,
    required List<NodeModel> allNodes,
    bool avoidStairs = false,
  }) async {
    // Encontrar os 10 nós mais próximos do destino para ter alternativa
    // Aumentado para 10 porque algumas áreas têm vários nós desconectados no backend
    final nearestNodes = _findNearestNodes(
      endX,
      endY,
      endLevel,
      allNodes,
      count: 10,
    );

    if (nearestNodes.isEmpty) {
      throw Exception('No navigable node found near destination');
    }

    Exception? lastError;

    // Tentar rotear para cada um dos nós mais próximos
    for (var node in nearestNodes) {
      try {
        // Tentar calcular rota
        return await getRoute(
          startX: startX,
          startY: startY,
          startLevel: startLevel,
          destinationType: 'node',
          destinationId: node.id,
          avoidStairs: avoidStairs,
        );
      } catch (e) {
        print('RoutingService: Fallback triggered. Node ${node.id} failed: $e');
        lastError = e is Exception ? e : Exception(e.toString());
        // Se falhar, continua para o próximo nó
        continue;
      }
    }

    // Se todos falharem, lança o último erro
    throw lastError ??
        Exception('Failed to calculate route to any nearby node');
  }

  /// Encontra os [count] nós mais próximos de um ponto
  List<NodeModel> _findNearestNodes(
    double x,
    double y,
    int level,
    List<NodeModel> nodes, {
    int count = 3,
  }) {
    // Filtrar nós pelo mesmo piso (prioridade)
    final sameLevelNodes = nodes.where((n) => n.level == level).toList();
    final candidateNodes = sameLevelNodes.isNotEmpty ? sameLevelNodes : nodes;

    if (candidateNodes.isEmpty) return [];

    // Calcular distâncias
    final nodesWithDistance = candidateNodes.map((node) {
      final dx = node.x - x;
      final dy = node.y - y;
      final distSq = dx * dx + dy * dy;
      return MapEntry(node, distSq);
    }).toList();

    // Ordenar por distância
    nodesWithDistance.sort((a, b) => a.value.compareTo(b.value));

    // Retornar os [count] primeiros
    return nodesWithDistance.take(count).map((entry) => entry.key).toList();
  }
}
