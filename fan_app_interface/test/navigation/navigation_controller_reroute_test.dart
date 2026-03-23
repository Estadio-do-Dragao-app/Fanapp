import 'package:flutter_test/flutter_test.dart';
import 'package:fan_app_interface/features/navigation/domain/navigation_controller.dart';
import 'package:fan_app_interface/features/map/data/models/route_model.dart';
import 'package:fan_app_interface/features/map/data/models/poi_model.dart';
import 'package:fan_app_interface/features/map/data/models/node_model.dart';

void main() {
  test('NavigationController properly updates route instance and hash', () {
    final route1 = RouteModel(
      path: [
        PathNode(nodeId: 'n1', x: 0, y: 0, level: 0, distanceFromStart: 0, estimatedTime: 0),
        PathNode(nodeId: 'n2', x: 10, y: 0, level: 0, distanceFromStart: 10, estimatedTime: 10),
      ],
      totalDistance: 10,
      estimatedTime: 10,
      congestionLevel: 0,
      warnings: [],
    );

    final route2 = RouteModel(
      path: [
        PathNode(nodeId: 'n3', x: 10, y: 10, level: 0, distanceFromStart: 0, estimatedTime: 0),
        PathNode(nodeId: 'n4', x: 20, y: 10, level: 0, distanceFromStart: 10, estimatedTime: 10),
      ],
      totalDistance: 10,
      estimatedTime: 10,
      congestionLevel: 0,
      warnings: [],
    );

    final dest = POIModel(id: 'poi1', name: 'POI 1', x: 10, y: 0, level: 0, category: 'poi');
    final controller = NavigationController(
      route: route1,
      destination: dest,
      allNodes: [
        NodeModel(id: 'n1', x: 0, y: 0, level: 0, type: 'node'),
        NodeModel(id: 'n2', x: 10, y: 0, level: 0, type: 'node'),
        NodeModel(id: 'n3', x: 10, y: 10, level: 0, type: 'node'),
        NodeModel(id: 'n4', x: 20, y: 10, level: 0, type: 'node'),
      ],
      initialX: 0,
      initialY: 0,
    );

    print('Initial RouteObjHash: ${controller.route.hashCode}');
    expect(controller.route, route1);

    // Force apply new route
    controller.applyNewRoute(['n3', 'n4']);
    print('After applyNewRoute, RouteObjHash: ${controller.route.hashCode}');

    expect(controller.route.path.first.nodeId, 'n3');
    // If route didn't update, the hash might also not update, but since we are overriding it, let's see why it's kept.
  });
}
