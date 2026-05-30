import 'package:flutter_test/flutter_test.dart';
import 'package:fan_app_interface/features/map/data/models/route_model.dart';
import 'package:fan_app_interface/features/navigation/presentation/navigation_page.dart';

PathNode _n(String id) => PathNode(
      nodeId: id,
      x: 0,
      y: 0,
      level: 0,
      distanceFromStart: 0,
      estimatedTime: 0,
    );

RouteModel _route(List<String> ids) => RouteModel(
      path: ids.map(_n).toList(),
      totalDistance: 0,
      estimatedTime: 0,
      congestionLevel: 0,
      warnings: const [],
    );

void main() {
  group('routeSignature (Fix 1 regression lock)', () {
    test('same node sequence produces the same signature', () {
      // The whole point of Fix 1: GPS-tick notifyListeners() with the same
      // underlying route must NOT trigger a Stack rebuild. The page decides
      // that by comparing signatures — so identical paths must collide.
      final a = _route(['n1', 'n2', 'n3']);
      final b = _route(['n1', 'n2', 'n3']);
      expect(routeSignature(a), routeSignature(b));
    });

    test('different node sequences produce different signatures', () {
      // After a reroute the signature MUST change so the Stack rebuilds and
      // _activeRoute / preview clearing kick in.
      expect(
        routeSignature(_route(['n1', 'n2', 'n3'])),
        isNot(routeSignature(_route(['n1', 'n2', 'n4']))),
      );
    });

    test('different length routes produce different signatures', () {
      expect(
        routeSignature(_route(['n1', 'n2'])),
        isNot(routeSignature(_route(['n1', 'n2', 'n3']))),
      );
    });

    test('signature includes length prefix so prefix-only paths still differ',
        () {
      // Defensive: two routes whose node-id concatenation accidentally
      // matches but lengths differ must not collide. The "${length}|" prefix
      // guarantees this.
      final shorter = _route(['n1>n2', 'n3']); // contrived: ids with '>'
      final longer = _route(['n1', 'n2', 'n3']);
      expect(routeSignature(shorter), isNot(routeSignature(longer)));
    });

    test('empty route is handled without crashing', () {
      expect(() => routeSignature(_route(const [])), returnsNormally);
      expect(routeSignature(_route(const [])), '0|');
    });
  });
}
