import 'dart:async';
import 'dart:io';
import 'app_env.dart';

/// Configuração de endpoints dos serviços backend
///
/// Lida apenas com a conectividade inicial (fallback para localhost),
/// usando AppEnv para as portas e hosts.
class ApiConfig {
  static String _baseHost = AppEnv.apiBaseUrl;

  static Future<void> init() async {
    const String localHost = '127.0.0.1'; // localhost
    
    print('[ApiConfig] A verificar conectividade com os serviços...');

    // Tentar primeiro o host do ambiente (API_BASE_URL)
    final hostIp = AppEnv.apiBaseUrl.replaceAll('http://', '').replaceAll('https://', '');
    if (await _checkHost(hostIp, 8000)) {
      _baseHost = AppEnv.apiBaseUrl;
      print('[ApiConfig] Conectado à API: $_baseHost');
      return;
    }

    // Se falhar, tentar localhost
    if (await _checkHost(localHost, 8000)) {
      _baseHost = 'http://$localHost';
      print('[ApiConfig] Conectado ao Localhost: $_baseHost');
      return;
    }

    print('[ApiConfig] Aviso: Nenhum serviço backend detetado. A usar default.');
  }

  static Future<bool> _checkHost(String host, int port) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
    try {
      final request = await client.getUrl(Uri.parse('http://$host:$port/health'));
      final response = await request.close();
      return response.statusCode == 200;
    } catch (_) {
      return false;
    } finally {
      client.close();
    }
  }

  // ==================== SERVIÇOS ====================

  static String get mapService => '$_baseHost:8000';
  static String get waitTimeService => '$_baseHost:8001';
  static String get routingService => '$_baseHost:8002';
  
  // ==================== MQTT ====================

  static String get mqttBroker => _baseHost.replaceAll('http://', '').replaceAll('https://', '');
  static int get mqttPort => AppEnv.mqttPort;
  static int get mqttWebSocketPort => AppEnv.mqttWebSocketPort;

  // ==================== TIMEOUTS ====================

  static int get httpTimeout => AppEnv.httpTimeoutSeconds;
  static int get mqttTimeout => AppEnv.mqttTimeoutSeconds;
}
