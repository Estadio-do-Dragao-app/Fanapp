import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fan_app_interface/features/map/data/services/saved_places_service.dart';
import 'package:fan_app_interface/features/map/data/models/poi_model.dart';

void main() {
  group('SavedPlacesService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('getSavedPlaces returns empty list when nothing saved', () async {
      final places = await SavedPlacesService.getSavedPlaces();
      expect(places, isEmpty);
    });

    test('savePlace stores a POI and it can be retrieved', () async {
      final poi = POIModel(
        id: 'poi_test_1',
        name: 'Test Restroom',
        category: 'wc',
        x: 10.0,
        y: 20.0,
        level: 0,
      );

      await SavedPlacesService.savePlace(poi);
      final places = await SavedPlacesService.getSavedPlaces();

      expect(places, isNotEmpty);
      expect(places.any((p) => p.id == 'poi_test_1'), isTrue);
    });

    test('removePlace deletes a previously saved POI', () async {
      final poi = POIModel(
        id: 'poi_test_2',
        name: 'Bar Level 1',
        category: 'food',
        x: 30.0,
        y: 40.0,
        level: 1,
      );

      await SavedPlacesService.savePlace(poi);
      await SavedPlacesService.removePlace('poi_test_2');
      final places = await SavedPlacesService.getSavedPlaces();

      expect(places.any((p) => p.id == 'poi_test_2'), isFalse);
    });

    test('isSaved returns false for unsaved POI', () async {
      final result = await SavedPlacesService.isSaved('nonexistent_id');
      expect(result, isFalse);
    });

    test('isSaved returns true for saved POI', () async {
      final poi = POIModel(
        id: 'poi_test_3',
        name: 'Entrance Gate A',
        category: 'entrance',
        x: 5.0,
        y: 5.0,
        level: 0,
      );

      await SavedPlacesService.savePlace(poi);
      final result = await SavedPlacesService.isSaved('poi_test_3');
      expect(result, isTrue);
    });

    test('saving same POI twice does not duplicate', () async {
      final poi = POIModel(
        id: 'poi_dup',
        name: 'Duplicate',
        category: 'info',
        x: 1.0,
        y: 1.0,
        level: 0,
      );

      await SavedPlacesService.savePlace(poi);
      await SavedPlacesService.savePlace(poi);
      final places = await SavedPlacesService.getSavedPlaces();

      expect(places.where((p) => p.id == 'poi_dup').length, 1);
    });

    test('clearAll removes all saved places', () async {
      final poi = POIModel(id: 'clear_me', name: 'To Clear', category: 'wc', x: 0, y: 0, level: 0);
      await SavedPlacesService.savePlace(poi);
      await SavedPlacesService.clearAll();
      final places = await SavedPlacesService.getSavedPlaces();
      expect(places, isEmpty);
    });
  });
}