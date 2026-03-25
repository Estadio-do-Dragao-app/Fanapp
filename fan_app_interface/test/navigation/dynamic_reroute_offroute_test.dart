import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:fan_app_interface/features/map/data/models/node_model.dart';
import 'package:fan_app_interface/features/map/data/models/route_model.dart';
import 'package:fan_app_interface/features/map/data/services/routing_service.dart';
import 'package:fan_app_interface/features/navigation/domain/dynamic_route_manager.dart';

class _FakeRoutingService extends RoutingService {
  _FakeRoutingService({required this.routeToReturn});

  final RouteModel routeToReturn;
  int getRouteCalls = 0;

  @override
  Future<RouteModel> getRoute({
    required double startX,
    required double startY,
    int startLevel = 0,
    required String destinationType,
    required String destinationId,
    bool avoidStairs = false,
  }) async {
    getRouteCalls++;
    return routeToReturn;
  }
}

NodeModel _node(String id, double x, double y, {int level = 0}) {
  return NodeModel(id: id, x: x, y: y, level: level, type: 'corridor');
}

PathNode _pathNode(String id, double x, double y, {int level = 0}) {
  return PathNode(
    nodeId: id,
    x: x,
    y: y,
    level: level,
    distanceFromStart: 0,
    estimatedTime: 0,
  );
}

RouteModel _route(List<PathNode> path) {
  return RouteModel(
    path: path,
    totalDistance: 120,
    estimatedTime: 90,
    congestionLevel: 0,
    warnings: const [],
  );
}

void main() {
  test('recalcula rota quando utilizador foge dos pontos', () async {
    final allNodes = <NodeModel>[
      _node('n0', -8.630000, 41.160000),
      _node('n1', -8.629900, 41.160000),
      _node('n2', -8.629800, 41.160000),
      _node('n3', -8.629700, 41.160000),
      _node('dest', -8.629650, 41.160000),
    ];

    final initialRoute = _route([
      _pathNode('n0', -8.630000, 41.160000),
      _pathNode('n1', -8.629900, 41.160000),
      _pathNode('n2', -8.629800, 41.160000),
      _pathNode('n3', -8.629700, 41.160000),
    ]);

    final recalculatedRoute = _route([
      _pathNode('n1', -8.629900, 41.160000),
      _pathNode('dest', -8.629650, 41.160000),
    ]);

    final fakeRouting = _FakeRoutingService(routeToReturn: recalculatedRoute);

    final manager = DynamicRouteManager(
      destinationId: 'dest',
      destinationType: 'node',
      destinationX: -8.629650,
      destinationY: 41.160000,
      destinationLevel: 0,
      allNodes: allNodes,
      initialRoute: initialRoute,
      routingService: fakeRouting,
      currentUserPositionProvider: () async => null,
    );

    final updates = <RouteModel>[];
    manager.onRouteUpdated = updates.add;

    final controller = StreamController<({double x, double y})>();
    manager.startMonitoring(controller.stream);

    // Posição significativamente fora da linha da rota (> 12m).
    controller.add((x: -8.629900, y: 41.160300));
    await Future<void>.delayed(const Duration(milliseconds: 120));

    expect(fakeRouting.getRouteCalls, greaterThan(0));
    expect(updates, hasLength(1));
    expect(updates.first.path.length, 2);
    expect(manager.currentRoute?.path.length, 2);

    await controller.close();
    manager.dispose();
  });
}
