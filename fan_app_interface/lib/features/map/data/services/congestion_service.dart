import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../core/services/mqtt_service.dart';

/// Model for cell congestion data from MQTT
class CellCongestionData {
  final String cellId;
  final double congestionLevel;
  final int peopleCount;
  final int capacity;
  final String timestamp;
  final int level;

  CellCongestionData({
    required this.cellId,
    required this.congestionLevel,
    required this.peopleCount,
    required this.capacity,
    required this.timestamp,
    this.level = 0,
  });

  factory CellCongestionData.fromJson(Map<String, dynamic> json) {
    return CellCongestionData(
      cellId: json['cell_id'] ?? '',
      congestionLevel: (json['congestion_level'] ?? 0.0).toDouble(),
      peopleCount: json['people_count'] ?? 0,
      capacity: json['capacity'] ?? 50,
      timestamp: json['timestamp'] ?? '',
      level: json['level'] ?? 0,
    );
  }
}

/// Response data for stadium heatmap
class StadiumHeatmapData {
  // Alterado para guardar o objeto completo, para termos acesso ao nível
  final Map<String, CellCongestionData> sections;
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
  static CongestionService? _instance;
  
  factory CongestionService({MqttService? mqttService}) {
    _instance ??= CongestionService._internal(mqttService ?? MqttService());
    return _instance!;
  }
  
  CongestionService._internal(this._mqttService);

  @visibleForTesting
  static void resetForTesting() {
    _instance = null;
  }

  final MqttService _mqttService;

  // Local store for MQTT updates
  final Map<String, CellCongestionData> _cellData = {};
  final Map<String, DateTime> _lastUpdate = {}; // Track expiration
  StreamSubscription? _mqttSubscription;
  bool _isConnected = false;

  /// Check if connected to MQTT broker
  bool get isConnected => _isConnected;

  /// Stream of heatmap data for UI
  Stream<StadiumHeatmapData> get heatmapStream =>
      _mqttService.congestionStream.map((_) => getStadiumHeatmap());

  /// Initialize connection to MQTT broker
  Future<bool> connect() async {
    if (_isConnected) return true;

    final connected = await _mqttService.connect();
    if (connected) {
      _isConnected = true;
      _mqttSubscription = _mqttService.congestionStream.listen(
        _onCongestionUpdate,
      );
      debugPrint('[CongestionService] Connected to MQTT broker');
    }
    return connected;
  }

  /// Handle incoming MQTT congestion updates
  void _onCongestionUpdate(Map<String, dynamic> data) {
    final cellData = CellCongestionData.fromJson(data);
    _cellData[cellData.cellId] = cellData;
    _lastUpdate[cellData.cellId] = DateTime.now();
    
    debugPrint(
      '[CongestionService] Stored cell ${cellData.cellId} with level ${cellData.congestionLevel}. Total cells: ${_cellData.length}',
    );
  }

  /// Get current heatmap data from MQTT cache
  StadiumHeatmapData getStadiumHeatmap() {
    // Expire old data (TTL: 30 seconds)
    final now = DateTime.now();
    _cellData.removeWhere((key, _) {
      final last = _lastUpdate[key];
      if (last == null) return true;
      return now.difference(last).inSeconds > 15;
    });
    _lastUpdate.removeWhere((key, last) => now.difference(last).inSeconds > 15);

    if (_cellData.isEmpty) {
      return StadiumHeatmapData(
        sections: {},
        totalSections: 0,
        averageCongestion: 0,
      );
    }

    // Agora retornamos o objeto completo
    final sections = <String, CellCongestionData>{};
    double total = 0;

    for (var entry in _cellData.entries) {
      sections[entry.key] = entry.value;
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
