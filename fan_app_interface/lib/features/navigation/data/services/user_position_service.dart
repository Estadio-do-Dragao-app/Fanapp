import 'package:shared_preferences/shared_preferences.dart';

/// Serviço para persistir a posição do utilizador entre sessões
class UserPositionService {
  static const String _keyX = 'user_position_x';
  static const String _keyY = 'user_position_y';
  static const String _keyNodeId = 'user_node_id';
  static const String _keyLevel = 'user_position_level';

  // Removes defaults


  /// Salva a posição atual do utilizador
  static Future<void> savePosition({
    required double x,
    required double y,
    required String nodeId,
    required int level,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyX, x);
    await prefs.setDouble(_keyY, y);
    await prefs.setString(_keyNodeId, nodeId);
    await prefs.setInt(_keyLevel, level);
    print(
      '[UserPositionService] Posição salva: x=$x, y=$y, node=$nodeId, level=$level',
    );
  }

  /// Recupera a posição salva do utilizador, ou null se não houver
  static Future<({double x, double y, String nodeId, int level})?>
  getPosition() async {
    final prefs = await SharedPreferences.getInstance();
    final x = prefs.getDouble(_keyX);
    final y = prefs.getDouble(_keyY);
    final nodeId = prefs.getString(_keyNodeId);
    final level = prefs.getInt(_keyLevel);
    
    if (x == null || y == null || nodeId == null || level == null) {
      print('[UserPositionService] Nenhuma posição encontrada.');
      return null;
    }
    
    print(
      '[UserPositionService] Posição recuperada: x=$x, y=$y, node=$nodeId, level=$level',
    );
    return (x: x, y: y, nodeId: nodeId, level: level);
  }

  /// Apaga a posição guardada
  static Future<void> clearPosition() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyX);
    await prefs.remove(_keyY);
    await prefs.remove(_keyNodeId);
    await prefs.remove(_keyLevel);
  }
}
