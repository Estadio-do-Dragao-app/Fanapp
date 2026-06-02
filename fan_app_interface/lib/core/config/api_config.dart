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
    if (await _checkHost(hostIp, 443, isHttps: true)) {
      _baseHost = AppEnv.apiBaseUrl;
      print('[ApiConfig] Conectado à API: $_baseHost');
      return;
    }

    // Se falhar, tentar localhost
    if (await _checkHost(localHost, 443, isHttps: true)) {
      _baseHost = 'https://$localHost';
      print('[ApiConfig] Conectado ao Localhost: $_baseHost');
      return;
    }

    print('[ApiConfig] Aviso: Nenhum serviço backend detetado. A usar default.');
  }

  static Future<bool> _checkHost(String host, int port, {bool isHttps = false}) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
    try {
      final scheme = isHttps ? 'https' : 'http';
      final uriStr = host.contains(':') ? '$scheme://$host/health' : '$scheme://$host:$port/health';
      final request = await client.getUrl(Uri.parse(uriStr));
      final response = await request.close();
      return response.statusCode == 200;
    } catch (_) {
      return false;
    } finally {
      client.close();
    }
  }

  // ==================== SERVIÇOS ====================

  static String get baseHost => _baseHost;

  static String get mapService => '$_baseHost/maps';
  static String get waitTimeService => '$_baseHost/waittime';
  static String get routingService => '$_baseHost/routing';
  
  // ==================== MQTT ====================

  static String get mqttBroker => _baseHost.replaceAll('http://', '').replaceAll('https://', '').split(':').first;
  static int get mqttPort => AppEnv.mqttPort;
  static int get mqttWebSocketPort => AppEnv.mqttWebSocketPort;

  // ==================== TIMEOUTS ====================

  static int get httpTimeout => AppEnv.httpTimeoutSeconds;
  static int get mqttTimeout => AppEnv.mqttTimeoutSeconds;
}
