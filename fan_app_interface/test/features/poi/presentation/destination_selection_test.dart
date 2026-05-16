import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:fan_app_interface/l10n/app_localizations.dart';
import 'package:fan_app_interface/features/poi/presentation/destination_selection.dart';
import 'package:fan_app_interface/features/map/data/services/map_service.dart';
import 'package:fan_app_interface/features/map/data/models/poi_model.dart';

class MockMapService extends Mock implements MapService {}

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en'), Locale('pt')],
    home: Scaffold(body: child),
  );
}

void main() {
  late MockMapService mockMapService;

  setUp(() {
    mockMapService = MockMapService();
    when(() => mockMapService.getAllPOIs()).thenAnswer((_) async => []);
  });

  group('DestinationSelection Widget', () {
    testWidgets('renders without error when POI list is empty', (tester) async {
      await tester.pumpWidget(_wrap(
        DestinationSelection(
          mapService: mockMapService,
          onDestinationSelected: (_) {},
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
    });

    testWidgets('shows POI items when service returns results', (tester) async {
      final pois = [
        POIModel(id: 'p1', name: 'WC Piso 0', category: 'wc', x: 0, y: 0, level: 0),
        POIModel(id: 'p2', name: 'Bar Piso 1', category: 'food', x: 1, y: 1, level: 1),
      ];
      when(() => mockMapService.getAllPOIs()).thenAnswer((_) async => pois);

      await tester.pumpWidget(_wrap(
        DestinationSelection(
          mapService: mockMapService,
          onDestinationSelected: (_) {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('WC Piso 0'), findsOneWidget);
      expect(find.text('Bar Piso 1'), findsOneWidget);
    });

    testWidgets('tapping a POI calls onDestinationSelected', (tester) async {
      final pois = [
        POIModel(id: 'p1', name: 'Gate A', category: 'entrance', x: 0, y: 0, level: 0),
      ];
      when(() => mockMapService.getAllPOIs()).thenAnswer((_) async => pois);

      POIModel? selected;
      await tester.pumpWidget(_wrap(
        DestinationSelection(
          mapService: mockMapService,
          onDestinationSelected: (poi) => selected = poi,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Gate A'));
      await tester.pump();

      expect(selected, isNotNull);
      expect(selected!.id, 'p1');
    });

    testWidgets('search field filters POIs by name', (tester) async {
      final pois = [
        POIModel(id: 'p1', name: 'WC Norte', category: 'wc', x: 0, y: 0, level: 0),
        POIModel(id: 'p2', name: 'Bar Sul', category: 'food', x: 1, y: 1, level: 1),
      ];
      when(() => mockMapService.getAllPOIs()).thenAnswer((_) async => pois);

      await tester.pumpWidget(_wrap(
        DestinationSelection(
          mapService: mockMapService,
          onDestinationSelected: (_) {},
        ),
      ));
      await tester.pumpAndSettle();

      // Enter search text
      await tester.enterText(find.byType(TextField).first, 'WC');
      await tester.pump();

      expect(find.text('WC Norte'), findsOneWidget);
      expect(find.text('Bar Sul'), findsNothing);
    });
  });
}
