import 'dart:async';
import '../../../../core/services/mqtt_service.dart';

/// Model for cell congestion data from MQTT
class CellCongestionData {
  final String cellId;
  final double congestionLevel;
  final int peopleCount;
  final int capacity;
  final String timestamp;

  CellCongestionData({
    required this.cellId,
    required this.congestionLevel,
    required this.peopleCount,
    required this.capacity,
    required this.timestamp,
  });

  factory CellCongestionData.fromJson(Map<String, dynamic> json) {
    return CellCongestionData(
      cellId: json['cell_id'] ?? '',
      congestionLevel: (json['congestion_level'] ?? 0.0).toDouble(),
      peopleCount: json['people_count'] ?? 0,
      capacity: json['capacity'] ?? 50,
      timestamp: json['timestamp'] ?? '',
    );
  }
}

/// Response data for stadium heatmap
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
}

/// Service for real-time congestion data via MQTT broker
/// All data comes from Service-to-Client-Broker (port 1884)
class CongestionService {
  final MqttService _mqttService = MqttService();

  // Local store for MQTT updates
  final Map<String, CellCongestionData> _cellData = {};
  StreamSubscription? _mqttSubscription;
  bool _isConnected = false;

  /// Check if connected to MQTT broker
  bool get isConnected => _isConnected;

  /// Initialize connection to MQTT broker
  Future<bool> connect() async {
    if (_isConnected) return true;

    final connected = await _mqttService.connect();
    if (connected) {
      _isConnected = true;
      _mqttSubscription = _mqttService.congestionStream.listen(
        _onCongestionUpdate,
      );
      print('[CongestionService] Connected to MQTT broker');
    }
    return connected;
  }

  /// Handle incoming MQTT congestion updates
  void _onCongestionUpdate(Map<String, dynamic> data) {
    final cellData = CellCongestionData.fromJson(data);
    _cellData[cellData.cellId] = cellData;
  }

  /// Get current heatmap data from MQTT cache
  StadiumHeatmapData getStadiumHeatmap() {
    if (_cellData.isEmpty) {
      return StadiumHeatmapData(
        sections: {},
        totalSections: 0,
        averageCongestion: 0,
      );
    }

    final sections = <String, double>{};
    double total = 0;

    for (var entry in _cellData.entries) {
      sections[entry.key] = entry.value.congestionLevel;
      total += entry.value.congestionLevel;
    }

    final avg = total / _cellData.length;

    String? mostCongested;
    String? leastCongested;
    double maxLevel = 0;
    double minLevel = 1.0;

    for (var entry in _cellData.entries) {
      if (entry.value.congestionLevel > maxLevel) {
        maxLevel = entry.value.congestionLevel;
        mostCongested = entry.key;
      }
      if (entry.value.congestionLevel < minLevel) {
        minLevel = entry.value.congestionLevel;
        leastCongested = entry.key;
      }
    }

    return StadiumHeatmapData(
      sections: sections,
      totalSections: _cellData.length,
      averageCongestion: avg,
      mostCongested: mostCongested,
      leastCongested: leastCongested,
    );
  }

  /// Dispose resources
  void dispose() {
    _mqttSubscription?.cancel();
    _isConnected = false;
  }
}
