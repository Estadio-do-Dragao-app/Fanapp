import 'app_env.dart';

/// Configuração do modo do mapa — Indoor vs Outdoor
///
/// Para trocar de modo, basta alterar o valor no AppEnv via --dart-define.
class MapConfig {
  // ==================== MODO ====================
  static MapMode get mode => AppEnv.isOutdoorMode ? MapMode.outdoor : MapMode.indoor;

  static bool get onlyDatabasePOIs => AppEnv.onlyDatabasePOIs;

  // ==================== FLAGS DERIVADAS ====================

  /// Usar OSM TileLayer como base do mapa
  static bool get useOSMTiles => mode == MapMode.outdoor;

  /// Usar FloorPlanLayer (polígonos desenhados a partir dos edges/nodes)
  static bool get useFloorPlan => mode == MapMode.indoor;

  /// Buscar POIs dinâmicos do OpenStreetMap (endpoint /pois/osm)
  static bool get useOSMPOIs => mode == MapMode.outdoor && !onlyDatabasePOIs;

  /// Raio máximo (metros) para considerar uma posição walkable
  static double get walkableRadius => mode == MapMode.outdoor ? 50.0 : 15.0;

  /// Zoom inicial do mapa
  static double get initialZoom => mode == MapMode.outdoor ? 17.0 : 19.0;

  /// Zoom de navegação
  static double get navigationZoom => mode == MapMode.outdoor ? 20.0 : 21.0;

  /// Zoom mínimo permitido
  static double get minZoom => mode == MapMode.outdoor ? 14.0 : 17.0;

  /// Descrição legível do modo atual
  static String get modeLabel =>
      mode == MapMode.outdoor ? 'Outdoor (OSM)' : 'Indoor (Floor Plan)';
}

/// Modos de mapa disponíveis
enum MapMode {
  /// Mapa outdoor com tiles do OpenStreetMap
  outdoor,

  /// Mapa indoor com floor plan desenhado a partir do grafo
  indoor,
}
