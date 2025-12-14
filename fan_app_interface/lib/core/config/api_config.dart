/// Configuração de endpoints dos serviços backend
///
/// IMPORTANTE: Alterar os valores conforme o ambiente:
/// - Desenvolvimento local: localhost ou 10.0.2.2 (emulador Android)
/// - Dispositivo físico: IP do servidor ou domínio público
/// - Produção: Domínio real (ex: https://api.dragao.pt)
class ApiConfig {
  // ==================== AMBIENTE ====================
  // Descomentar a linha correspondente ao ambiente:

  // Desenvolvimento local (browser/web)
  // static const String _baseHost = 'http://localhost';

  // Emulador Android (aponta para o host via IP especial)
  // static const String _baseHost = 'http://10.0.2.2';

  // Dispositivo físico na mesma rede (usar IP do PC)
  // static const String _baseHost = 'http://192.168.1.XXX';

  // Produção (substituir pelo domínio real)
  // static const String _baseHost = 'http://192.168.68.113';

  // Desenvolvimento local (browser/web)
  // static const String _baseHost = 'http://localhost';
  static const String _baseHost = 'http://172.16.46.17';

  // ==================== SERVIÇOS ====================

  /// Map-Service - Mapa do estádio, POIs, gates
  static const String mapService = '$_baseHost:8000';

  /// WaitTime-Service - Tempos de espera nas filas
  static const String waitTimeService = '$_baseHost:8001';

  /// Routing-Service - Cálculo de rotas
  static const String routingService = '$_baseHost:8002';

  /// Ticket-Service - Gestão de bilhetes
  static const String ticketService = '$_baseHost:8003';

  // ==================== MQTT (para alertas real-time) ====================

  /// Broker MQTT para clientes (host sem http://)
  static String get mqttBroker =>
      _baseHost.replaceAll('http://', '').replaceAll('https://', '');
  static const int mqttPort = 1884;
  static const int mqttWebSocketPort = 9002;

  // ==================== TIMEOUTS ====================

  /// Timeout para requests HTTP (em segundos)
  static const int httpTimeout = 10;

  /// Timeout para conexão MQTT (em segundos)
  static const int mqttTimeout = 30;
}
