import 'dart:async';
import 'package:flutter/material.dart';
import 'core/services/mqtt_service.dart';
import 'features/map/data/services/congestion_service.dart';
import 'features/privacy/presentation/consent_modal.dart';
import 'features/map/data/services/waittime_cache.dart';

class HomeViewModel extends ChangeNotifier {
  final CongestionService _congestionService = CongestionService();

  bool showHeatmap = false;
  bool isHeatmapAvailable = true;
  bool avoidStairs = false;
  bool isFilterExpanded = false;
  bool isPOIPanelOpen = false;

  Timer? _healthCheckTimer;
  StreamSubscription? _alertSubscription;

  void Function()? onEmergencyAlert;

  HomeViewModel() {
    _checkCongestionHealth();
    WaittimeCache().start();
    _startHealthCheckTimer();
  }

  void initConsent(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final consented = await ConsentModal.hasConsented();
      if (!consented && context.mounted) {
        ConsentModal.show(context, onAccepted: () {
          _initMqttAndAlerts();
        });
      } else if (consented) {
        _initMqttAndAlerts();
      }
    });
  }

  Future<void> _initMqttAndAlerts() async {
    await MqttService().connect();
    _alertSubscription = MqttService().alertsStream.listen((data) {
      if (data['priority'] == 'CRITICAL') {
        debugPrint('[HomeViewModel] CRITICAL Emergency alert validated: ${data['id'] ?? data['alert_id']}');
        onEmergencyAlert?.call();
      } else {
        debugPrint('[HomeViewModel] Ignored non-critical alert in Home: $data');
      }
    });
  }

  void _startHealthCheckTimer() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!showHeatmap) {
        _checkCongestionHealth();
      }
    });
  }

  Future<void> _checkCongestionHealth() async {
    final isConnected = await _congestionService.connect();
    updateHealthStatus(isConnected);
  }

  void updateHealthStatus(bool isHealthy) {
    if (isHeatmapAvailable != isHealthy) {
      isHeatmapAvailable = isHealthy;
      if (!isHealthy && showHeatmap) {
        showHeatmap = false;
      }
      notifyListeners();
    }
  }

  void setHeatmap(bool value) {
    showHeatmap = value;
    notifyListeners();
    if (value) {
      _checkCongestionHealth();
    }
  }

  void setAvoidStairs(bool value) {
    avoidStairs = value;
    notifyListeners();
  }

  void setFilterExpanded(bool value) {
    isFilterExpanded = value;
    notifyListeners();
  }

  void setPOIPanelOpen(bool value) {
    isPOIPanelOpen = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _healthCheckTimer?.cancel();
    _alertSubscription?.cancel();
    super.dispose();
  }
}
