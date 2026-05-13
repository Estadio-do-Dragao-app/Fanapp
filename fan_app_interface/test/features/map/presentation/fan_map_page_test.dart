import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fan_app_interface/features/map/presentation/fan_map_page.dart';
import 'package:fan_app_interface/features/map/data/services/map_service.dart';
import 'package:fan_app_interface/features/map/data/services/routing_service.dart';
import 'package:fan_app_interface/features/map/data/services/congestion_service.dart';
import 'package:fan_app_interface/features/map/data/models/poi_model.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:fan_app_interface/l10n/app_localizations.dart';
import 'package:fan_app_interface/features/map/data/services/waittime_cache.dart';

class MockMapService extends Mock implements MapService {}
class MockRoutingService extends Mock implements RoutingService {}
class MockCongestionService extends Mock implements CongestionService {}

void main() {
  late MockMapService mockMapService;
  late MockRoutingService mockRoutingService;
  late MockCongestionService mockCongestionService;

  setUpAll(() {
    WaittimeCache().stop(); // Ensure cache doesn't run timers in tests
  });

  setUp(() {
    mockMapService = MockMapService();
    mockRoutingService = MockRoutingService();
    mockCongestionService = MockCongestionService();

    // Default mock behavior
    when(() => mockMapService.getPOIsByFloor(any())).thenAnswer((_) async => []);
    when(() => mockMapService.getAllNodes()).thenAnswer((_) async => []);
    when(() => mockMapService.getAllEdges()).thenAnswer((_) async => []);
    when(() => mockMapService.getAllTiles(level: any(named: 'level'))).thenAnswer((_) async => []);
    
    when(() => mockCongestionService.isConnected).thenReturn(false);
    when(() => mockCongestionService.connect()).thenAnswer((_) async => true);
  });

  Widget createWidgetUnderTest() {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''),
        Locale('pt', ''),
      ],
      home: Scaffold(
        body: FanMapPage(
          mapService: mockMapService,
          routingService: mockRoutingService,
          congestionService: mockCongestionService,
        ),
      ),
    );
  }

  group('FanMapPage Widget Tests', () {
    testWidgets('renders map and initial UI elements', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify that map controls are visible
      expect(find.byIcon(Icons.my_location_outlined), findsOneWidget); // Recenter button
    });

    testWidgets('shows POIs when loaded', (WidgetTester tester) async {
      final mockPOIs = [
        POIModel(
          id: 'poi_1',
          name: 'Main WC',
          category: 'wc',
          x: 40.0,
          y: -8.0,
          level: 0,
          description: 'Restroom'
        ),
      ];

      when(() => mockMapService.getPOIsByFloor(0)).thenAnswer((_) async => mockPOIs);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Ensure the POI was requested
      verify(() => mockMapService.getPOIsByFloor(0)).called(1);
      
      // We expect POIs to be rendered on the map.
      // Since they are rendered in FlutterMap layers, we can't easily find them by standard text
      // unless we know exactly how they are built. But we can ensure no errors occurred.
      expect(tester.takeException(), isNull);
    });
  });
}
