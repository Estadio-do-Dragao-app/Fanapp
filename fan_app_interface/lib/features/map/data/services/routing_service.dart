import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/route_model.dart';

/// Service para comunicar com o Routing-Service
/// Backend: https://github.com/Estadio-do-Dragao-app/Routing-Service
class RoutingService {
  static const String baseUrl =
      'http://localhost:8002'; // Alterar para produção

  /// GET /api/route?from_node=X&to_node=Y - Calcula rota entre dois nós
  Future<RouteModel> getRoute({
    required String fromNode,
    required String toNode,
    bool avoidCrowds = false,
  }) async {
    final uri = Uri.parse('$baseUrl/api/route').replace(
      queryParameters: {
        'from_node': fromNode,
        'to_node': toNode,
        'avoid_crowds': avoidCrowds.toString(),
      },
    );

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      return RouteModel.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to get route: ${response.statusCode}');
    }
  }

  /// GET /api/route/evacuation?from_node=X - Rota de evacuação para saída mais próxima
  Future<RouteModel> getEvacuationRoute({required String fromNode}) async {
    final uri = Uri.parse(
      '$baseUrl/api/route/evacuation',
    ).replace(queryParameters: {'from_node': fromNode});

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      return RouteModel.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to get evacuation route: ${response.statusCode}');
    }
  }

  /// POST /api/route/multi - Rota visitando múltiplos destinos
  Future<RouteModel> getMultiDestinationRoute({
    required String startNode,
    required List<String> destinationNodes,
  }) async {
    final uri = Uri.parse('$baseUrl/api/route/multi').replace(
      queryParameters: {
        'from_node': startNode,
        ...Map.fromIterable(
          destinationNodes,
          key: (e) => 'to_nodes',
          value: (e) => e,
        ),
      },
    );

    final response = await http.post(uri);

    if (response.statusCode == 200) {
      return RouteModel.fromJson(json.decode(response.body));
    } else {
      throw Exception(
        'Failed to get multi-destination route: ${response.statusCode}',
      );
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
}
