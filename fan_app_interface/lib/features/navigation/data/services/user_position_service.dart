import 'package:shared_preferences/shared_preferences.dart';

/// Serviço para persistir a posição do utilizador entre sessões
class UserPositionService {
  static const String _keyX = 'user_position_x';
  static const String _keyY = 'user_position_y';
  static const String _keyNodeId = 'user_node_id';
  
  // Posição inicial padrão (entrada principal - N1)
  static const double defaultX = 0.0;
  static const double defaultY = 0.0;
  static const String defaultNodeId = 'N1';
  
  /// Salva a posição atual do utilizador
  static Future<void> savePosition({
    required double x,
    required double y,
    required String nodeId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyX, x);
    await prefs.setDouble(_keyY, y);
    await prefs.setString(_keyNodeId, nodeId);
    print('[UserPositionService] 💾 Posição salva: x=$x, y=$y, node=$nodeId');
  }
  
  /// Recupera a posição salva do utilizador
  static Future<({double x, double y, String nodeId})> getPosition() async {
    final prefs = await SharedPreferences.getInstance();
    final x = prefs.getDouble(_keyX) ?? defaultX;
    final y = prefs.getDouble(_keyY) ?? defaultY;
    final nodeId = prefs.getString(_keyNodeId) ?? defaultNodeId;
    print('[UserPositionService] 📍 Posição recuperada: x=$x, y=$y, node=$nodeId');
    return (x: x, y: y, nodeId: nodeId);
  }
  
  /// Reseta a posição para o padrão (entrada principal)
  static Future<void> resetToDefault() async {
    await savePosition(x: defaultX, y: defaultY, nodeId: defaultNodeId);
  }
}
