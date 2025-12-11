import 'dart:convert';
import 'package:http/http.dart' as http;

/// Model for section congestion data
class SectionCongestion {
  final String sectionId;
  final double congestionLevel;

  SectionCongestion({required this.sectionId, required this.congestionLevel});
}

/// Response from the stadium heatmap endpoint
class StadiumHeatmapData {
  final Map<String, double> sections;
  final int totalSections;
  final double averageCongestion;
  final String? mostCongested;
  final String? leastCongested;

  StadiumHeatmapData({
    required this.sections,
    required this.totalSections,
    required this.averageCongestion,
    this.mostCongested,
    this.leastCongested,
  });

  factory StadiumHeatmapData.fromJson(Map<String, dynamic> json) {
    final sectionsMap = <String, double>{};
    if (json['sections'] != null) {
      (json['sections'] as Map<String, dynamic>).forEach((key, value) {
        sectionsMap[key] = (value as num).toDouble();
      });
    }

    return StadiumHeatmapData(
      sections: sectionsMap,
      totalSections: json['total_sections'] ?? 0,
      averageCongestion: (json['average_congestion'] ?? 0.0).toDouble(),
      mostCongested: json['most_congested'],
      leastCongested: json['least_congested'],
    );
  }
}

/// Service to communicate with the Congestion-Service API
class CongestionService {
  // URL base do Congestion-Service (alterar para produção)
  static const String baseUrl = 'http://localhost:8003';

  /// GET /heatmap/stadium/sections - Get heatmap data for entire stadium
  Future<StadiumHeatmapData> getStadiumHeatmap() async {
    final response = await http
        .get(
          Uri.parse('$baseUrl/heatmap/stadium/sections'),
          headers: {'Content-Type': 'application/json'},
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return StadiumHeatmapData.fromJson(json.decode(response.body));
    } else if (response.statusCode == 404) {
      // No data available - return empty
      return StadiumHeatmapData(
        sections: {},
        totalSections: 0,
        averageCongestion: 0,
      );
    } else {
      throw CongestionServiceException(
        'Failed to get heatmap: ${response.statusCode}',
      );
    }
  }

  /// GET /health - Check if service is online
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

/// Exception for congestion service errors
class CongestionServiceException implements Exception {
  final String message;
  CongestionServiceException(this.message);

  @override
  String toString() => message;
}
