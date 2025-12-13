import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/poi_model.dart';

/// Serviço para gerir lugares guardados/favoritos
/// Persiste localmente usando SharedPreferences
class SavedPlacesService {
  static const String _savedPlacesKey = 'saved_places';

  /// Guarda um lugar nos favoritos
  static Future<void> savePlace(POIModel poi) async {
    final places = await getSavedPlaces();
    // Evitar duplicados
    if (!places.any((p) => p.id == poi.id)) {
      places.add(poi);
      await _savePlaces(places);
      print('[SavedPlacesService] 💾 Lugar guardado: ${poi.name}');
    }
  }

  /// Remove um lugar dos favoritos
  static Future<void> removePlace(String id) async {
    final places = await getSavedPlaces();
    places.removeWhere((p) => p.id == id);
    await _savePlaces(places);
    print('[SavedPlacesService] 🗑️ Lugar removido: $id');
  }

  /// Obtém todos os lugares guardados
  static Future<List<POIModel>> getSavedPlaces() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_savedPlacesKey);

    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> jsonList = json.decode(jsonString);
      return jsonList.map((j) => POIModel.fromJson(j)).toList();
    } catch (e) {
      print('[SavedPlacesService] ⚠️ Erro ao carregar lugares: $e');
      return [];
    }
  }

  /// Verifica se um lugar está guardado
  static Future<bool> isSaved(String id) async {
    final places = await getSavedPlaces();
    return places.any((p) => p.id == id);
  }

  /// Limpa todos os lugares guardados
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_savedPlacesKey);
    print('[SavedPlacesService] 🗑️ Todos os lugares removidos');
  }

  /// Persiste a lista de lugares
  static Future<void> _savePlaces(List<POIModel> places) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = places.map((p) => p.toJson()).toList();
    await prefs.setString(_savedPlacesKey, json.encode(jsonList));
  }
}
