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

// Coordenadas muito próximas (distância < 50m) para evitar recálculo automático
// 1 grau ≈ 111 km, então 0.0001 grau ≈ 11 metros
const double _lat1 = 0.0;
const double _lng1 = 0.0;
const double _lat2 = 0.0001;
const double _lng2 = 0.0;

RouteModel _makeRoute() {
  return RouteModel(
    path: [
      PathNode(nodeId: 'n1', x: _lng1, y: _lat1, level: 0, distanceFromStart: 0, estimatedTime: 0),
      PathNode(nodeId: 'n2', x: _lng2, y: _lat2, level: 0, distanceFromStart: 11, estimatedTime: 8),
    ],
    totalDistance: 11,
    estimatedTime: 8,
    congestionLevel: 0,
    warnings: [],
  );
}

void main() {
  group('NavigationController unit tests', () {
    late NavigationController controller;
    final nodes = [
      NodeModel(id: 'n1', x: _lng1, y: _lat1, level: 0, type: 'node'),
      NodeModel(id: 'n2', x: _lng2, y: _lat2, level: 0, type: 'node'),
    ];

    setUp(() {
      final dest = POIModel(id: 'poi1', name: 'WC', x: _lng2, y: _lat2, level: 0, category: 'wc');
      controller = NavigationController(
        route: _makeRoute(),
        destination: dest,
        allNodes: nodes,
        initialX: _lng1,
        initialY: _lat1,
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
      expect(() => controller.updateUserPosition(_lng1 + 0.00001, _lat1), returnsNormally);
    });

    test('hasArrived is false initially', () {
      expect(controller.hasArrived, false);
    });
  });

  group('NavigationPage Widget Tests', () {
    testWidgets('renders without crash with a valid route', (tester) async {
      final dest = POIModel(id: 'poi1', name: 'Balneário', x: _lng2, y: _lat2, level: 0, category: 'wc');
      await tester.pumpWidget(_wrap(
        NavigationPage(
          route: _makeRoute(),
          destination: dest,
          nodes: [
            NodeModel(id: 'n1', x: _lng1, y: _lat1, level: 0, type: 'node'),
            NodeModel(id: 'n2', x: _lng2, y: _lat2, level: 0, type: 'node'),
          ],
          initialX: _lng1,
          initialY: _lat1,
          initialLevel: 0,
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows destination name on screen', (tester) async {
      final dest = POIModel(id: 'poi1', name: 'Balneário Norte', x: _lng2, y: _lat2, level: 0, category: 'wc');
      await tester.pumpWidget(_wrap(
        NavigationPage(
          route: _makeRoute(),
          destination: dest,
          nodes: [
            NodeModel(id: 'n1', x: _lng1, y: _lat1, level: 0, type: 'node'),
            NodeModel(id: 'n2', x: _lng2, y: _lat2, level: 0, type: 'node'),
          ],
          initialX: _lng1,
          initialY: _lat1,
          initialLevel: 0,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Balneário Norte'), findsOneWidget);
    });
  });
}