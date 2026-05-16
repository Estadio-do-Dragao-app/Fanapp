import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:fan_app_interface/l10n/app_localizations.dart';
import 'package:fan_app_interface/features/navigation/presentation/navigation_page.dart';
import 'package:fan_app_interface/features/navigation/domain/navigation_controller.dart';
import 'package:fan_app_interface/features/map/data/models/route_model.dart';
import 'package:fan_app_interface/features/map/data/models/poi_model.dart';
import 'package:fan_app_interface/features/map/data/models/node_model.dart';

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
        initialRoute: _makeRoute(),   // Nome correto do parâmetro
        destination: dest,
        allNodes: nodes,
        initialX: 0,
        initialY: 0,
        initialLevel: 0,
      );
    });

    tearDown(() {
      controller.dispose();
    });

    test('initial route is set correctly', () {
      expect(controller.route.waypoints.length, 2);
      expect(controller.route.waypoints.first.nodeId, 'n1');
    });

    test('isNavigating is true after construction', () {
      expect(controller.isNavigating, true);
    });

    test('endNavigation sets isNavigating to false', () async {
      await controller.endNavigation();
      expect(controller.isNavigating, false);
    });

    test('applyNewRoute replaces path with new node ids', () {
      controller.applyNewRoute(['n2', 'n1']);
      expect(controller.route.waypoints.first.nodeId, 'n2');
      expect(controller.route.waypoints.last.nodeId, 'n1');
    });

    test('applyNewRoute with unknown nodes does not crash', () {
      expect(() => controller.applyNewRoute(['unknown_x']), returnsNormally);
    });

    test('updateUserPosition does not throw', () {
      expect(() => controller.updateUserPosition(1.0, 0.5), returnsNormally);
    });

    test('hasArrived is false initially', () {
      expect(controller.hasArrived, false);
    });
  });

  group('NavigationPage Widget Tests', () {
    testWidgets('renders without crash with a valid route', (tester) async {
      final dest = POIModel(id: 'poi1', name: 'Balneário', x: 10, y: 0, level: 0, category: 'wc');
      await tester.pumpWidget(_wrap(
        NavigationPage(
          route: _makeRoute(),
          destination: dest,
          nodes: [
            NodeModel(id: 'n1', x: 0, y: 0, level: 0, type: 'node'),
            NodeModel(id: 'n2', x: 10, y: 0, level: 0, type: 'node'),
          ],
          initialX: 0,
          initialY: 0,
          initialLevel: 0,
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
          nodes: [
            NodeModel(id: 'n1', x: 0, y: 0, level: 0, type: 'node'),
            NodeModel(id: 'n2', x: 10, y: 0, level: 0, type: 'node'),
          ],
          initialX: 0,
          initialY: 0,
          initialLevel: 0,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Balneário Norte'), findsOneWidget);
    });
  });
}