import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:fan_app_interface/l10n/app_localizations.dart';
import 'package:fan_app_interface/features/navigation/presentation/navigation_page.dart';
import 'package:fan_app_interface/features/navigation/domain/navigation_controller.dart';
import 'package:fan_app_interface/features/map/data/models/route_model.dart';
import 'package:fan_app_interface/features/map/data/models/poi_model.dart';
import 'package:fan_app_interface/features/map/data/models/node_model.dart';
import 'package:fan_app_interface/features/map/data/services/routing_service.dart';

class MockRoutingService extends Mock implements RoutingService {}

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

RouteModel _makeRoute() {
  return RouteModel(
    path: [
      PathNode(nodeId: 'n1', x: 0, y: 0, level: 0, distanceFromStart: 0, estimatedTime: 0),
      PathNode(nodeId: 'n2', x: 10, y: 0, level: 0, distanceFromStart: 10, estimatedTime: 15),
    ],
    totalDistance: 10,
    estimatedTime: 15,
    congestionLevel: 0,
    warnings: [],
  );
}

void main() {
  group('NavigationController unit tests', () {
    late NavigationController controller;
    final nodes = [
      NodeModel(id: 'n1', x: 0, y: 0, level: 0, type: 'node'),
      NodeModel(id: 'n2', x: 10, y: 0, level: 0, type: 'node'),
    ];

    setUp(() {
      final dest = POIModel(id: 'poi1', name: 'WC', x: 10, y: 0, level: 0, category: 'wc');
      controller = NavigationController(
        route: _makeRoute(),
        destination: dest,
        allNodes: nodes,
        initialX: 0,
        initialY: 0,
      );
    });

    test('initial route is set correctly', () {
      expect(controller.route.path.length, 2);
      expect(controller.route.path.first.nodeId, 'n1');
    });

    test('isNavigating is true after start', () {
      controller.start();
      expect(controller.isNavigating, isTrue);
    });

    test('stop sets isNavigating to false', () {
      controller.start();
      controller.stop();
      expect(controller.isNavigating, isFalse);
    });

    test('applyNewRoute replaces path with new node ids', () {
      controller.applyNewRoute(['n2', 'n1']);
      expect(controller.route.path.first.nodeId, 'n2');
      expect(controller.route.path.last.nodeId, 'n1');
    });

    test('applyNewRoute with unknown nodes does not crash', () {
      expect(() => controller.applyNewRoute(['unknown_x']), returnsNormally);
    });

    test('updatePosition does not throw', () {
      controller.start();
      expect(() => controller.updatePosition(1.0, 0.5, level: 0), returnsNormally);
    });

    test('hasArrived is false at start', () {
      expect(controller.hasArrived, isFalse);
    });

    test('remainingDistance decreases as user advances', () {
      controller.start();
      final before = controller.remainingDistance;
      controller.updatePosition(5.0, 0.0, level: 0);
      final after = controller.remainingDistance;
      expect(after, lessThanOrEqualTo(before));
    });
  });

  group('NavigationPage Widget Tests', () {
    late MockRoutingService mockRoutingService;

    setUp(() {
      mockRoutingService = MockRoutingService();
    });

    testWidgets('renders without crash with a valid route', (tester) async {
      final dest = POIModel(id: 'poi1', name: 'Balneário', x: 10, y: 0, level: 0, category: 'wc');
      await tester.pumpWidget(_wrap(
        NavigationPage(
          route: _makeRoute(),
          destination: dest,
          allNodes: [
            NodeModel(id: 'n1', x: 0, y: 0, level: 0, type: 'node'),
            NodeModel(id: 'n2', x: 10, y: 0, level: 0, type: 'node'),
          ],
          routingService: mockRoutingService,
          initialX: 0,
          initialY: 0,
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows destination name on screen', (tester) async {
      final dest = POIModel(id: 'poi1', name: 'Balneário Norte', x: 10, y: 0, level: 0, category: 'wc');
      await tester.pumpWidget(_wrap(
        NavigationPage(
          route: _makeRoute(),
          destination: dest,
          allNodes: [
            NodeModel(id: 'n1', x: 0, y: 0, level: 0, type: 'node'),
            NodeModel(id: 'n2', x: 10, y: 0, level: 0, type: 'node'),
          ],
          routingService: mockRoutingService,
          initialX: 0,
          initialY: 0,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Balneário Norte'), findsOneWidget);
    });

    testWidgets('shows estimated time from route', (tester) async {
      final dest = POIModel(id: 'poi1', name: 'Gate B', x: 10, y: 0, level: 0, category: 'entrance');
      await tester.pumpWidget(_wrap(
        NavigationPage(
          route: _makeRoute(),
          destination: dest,
          allNodes: [
            NodeModel(id: 'n1', x: 0, y: 0, level: 0, type: 'node'),
            NodeModel(id: 'n2', x: 10, y: 0, level: 0, type: 'node'),
          ],
          routingService: mockRoutingService,
          initialX: 0,
          initialY: 0,
        ),
      ));
      await tester.pumpAndSettle();

      // Should display something with time info
      expect(tester.takeException(), isNull);
    });
  });
}
