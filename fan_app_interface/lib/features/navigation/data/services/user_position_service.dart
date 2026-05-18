import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Serviço para persistir a posição do utilizador entre sessões
class UserPositionService {
  static const String _keyX = 'user_position_x';
  static const String _keyY = 'user_position_y';
  static const String _keyNodeId = 'user_node_id';
  static const String _keyLevel = 'user_position_level';

  // Removes defaults


  static const _storage = FlutterSecureStorage();

  /// Salva a posição atual do utilizador
  static Future<void> savePosition({
    required double x,
    required double y,
    required String nodeId,
    required int level,
  }) async {
    await _storage.write(key: _keyX, value: x.toString());
    await _storage.write(key: _keyY, value: y.toString());
    await _storage.write(key: _keyNodeId, value: nodeId);
    await _storage.write(key: _keyLevel, value: level.toString());
    print(
      '[UserPositionService] Posição salva: x=$x, y=$y, node=$nodeId, level=$level',
    );
  }

  /// Recupera a posição salva do utilizador, ou null se não houver
  static Future<({double x, double y, String nodeId, int level})?>
  getPosition() async {
    final xStr = await _storage.read(key: _keyX);
    final yStr = await _storage.read(key: _keyY);
    final nodeId = await _storage.read(key: _keyNodeId);
    final levelStr = await _storage.read(key: _keyLevel);
    
    if (xStr == null || yStr == null || nodeId == null || levelStr == null) {
      print('[UserPositionService] Nenhuma posição encontrada.');
      return null;
    }
    
    final x = double.tryParse(xStr);
    final y = double.tryParse(yStr);
    final level = int.tryParse(levelStr);
    
    if (x == null || y == null || level == null) return null;

    print(
      '[UserPositionService] Posição recuperada: x=$x, y=$y, node=$nodeId, level=$level',
    );
    return (x: x, y: y, nodeId: nodeId, level: level);
  }

  /// Apaga a posição guardada
  static Future<void> clearPosition() async {
    await _storage.delete(key: _keyX);
    await _storage.delete(key: _keyY);
    await _storage.delete(key: _keyNodeId);
    await _storage.delete(key: _keyLevel);
  }
}
