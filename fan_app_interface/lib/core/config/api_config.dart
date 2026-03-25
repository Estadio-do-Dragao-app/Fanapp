import 'dart:async';
import 'dart:io';

/// Configuração de endpoints dos serviços backend
///
/// IMPORTANTE: Alterar os valores conforme o ambiente:
/// - Desenvolvimento local: localhost ou 10.0.2.2 (emulador Android)
/// - Dispositivo físico: IP do servidor ou domínio público
/// - Produção: Domínio real (ex: https://api.dragao.pt)
class ApiConfig {
  // ==================== AMBIENTE ====================
  // Descomentar a linha correspondente ao ambiente:

  // ==================== AMBIENTE DINÂMICO ====================
  
  // Host base (determinado no arranque pelo método init)
  static String _baseHost = 'http://10.255.32.58'; // Default para a VM

  /// Inicializa a configuração testando a conectividade com a VM e Localhost.
  /// Tenta primeiro a VM, se falhar (timeout), tenta localhost.
  static Future<void> init() async {
    const String vmHost = '10.255.32.58';
    const String localHost = '127.0.0.1'; // localhost
    
    print('[ApiConfig] A verificar conectividade com os serviços...');

    // Tentar primeiro a VM (porta 8000 do Map Service para teste)
    if (await _checkHost(vmHost, 8000)) {
      _baseHost = 'http://$vmHost';
      print('[ApiConfig] Conectado à VM: $_baseHost');
      return;
    }

    // Se falhar a VM, tentar localhost
    if (await _checkHost(localHost, 8000)) {
      _baseHost = 'http://$localHost';
      print('[ApiConfig] Conectado ao Localhost: $_baseHost');
      return;
    }

    print('[ApiConfig] Aviso: Nenhum serviço backend detetado. A usar default (VM).');
  }

  /// Verifica se um host/porto está acessível via endpoint de saúde
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

  /// Map-Service - Mapa do estádio, POIs, gates
  static String get mapService => '$_baseHost:8000';

  /// WaitTime-Service - Tempos de espera nas filas
  static String get waitTimeService => '$_baseHost:8001';

  /// Routing-Service - Cálculo de rotas
  static String get routingService => '$_baseHost:8002';

  /// Ticket-Service - Gestão de bilhetes
  static String get ticketService => '$_baseHost:8003';

  // ==================== MQTT (para alertas real-time) ====================

  /// Broker MQTT para clientes (host sem http://)
  static String get mqttBroker =>
      _baseHost.replaceAll('http://', '').replaceAll('https://', '');
  static const int mqttPort = 1883;
  static const int mqttWebSocketPort = 9002;

  // ==================== TIMEOUTS ====================

  /// Timeout para requests HTTP (em segundos)
  static const int httpTimeout = 30;

  /// Timeout para conexão MQTT (em segundos)
  static const int mqttTimeout = 30;
}
