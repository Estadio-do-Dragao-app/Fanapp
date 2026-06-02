import 'package:flutter_test/flutter_test.dart';

import 'package:fan_app_interface/features/map/data/models/node_model.dart';
import 'package:fan_app_interface/features/map/data/models/route_model.dart';
import 'package:fan_app_interface/features/navigation/domain/route_tracker.dart';
import 'package:fan_app_interface/features/navigation/domain/geometry/vector_math.dart';
import 'package:fan_app_interface/features/navigation/domain/geometry/segment_projector.dart';
import 'package:fan_app_interface/features/navigation/domain/tracking/snap_engine.dart';
import 'package:fan_app_interface/features/navigation/domain/tracking/heading_validator.dart';
import 'package:fan_app_interface/features/navigation/domain/tracking/anchor_resolver.dart';
import 'package:fan_app_interface/features/navigation/domain/tracking/reroute_hysteresis.dart';
import 'package:fan_app_interface/features/navigation/domain/tracking/z_axis_guard.dart';

// ─── Helpers ────────────────────────────────────────────────────────────────
NodeModel _node(String id, double x, double y,
        {int level = 0, String type = 'corridor'}) =>
    NodeModel(id: id, x: x, y: y, level: level, type: type);

PathNode _pn(String id, double x, double y, {int level = 0}) => PathNode(
      nodeId: id,
      x: x,
      y: y,
      level: level,
      distanceFromStart: 0,
      estimatedTime: 0,
    );

RouteModel _route(List<PathNode> p) => RouteModel(
      path: p,
      totalDistance: 100,
      estimatedTime: 70,
      congestionLevel: 0,
      warnings: const [],
    );

// Rota linear E→W ao longo de Lat=41.16, ~10m entre nós (~0.000120° lng).
const double _y0 = 41.160000;
const double _x0 = -8.630000;
const double _stepX = 0.000120;

List<NodeModel> _linearNodes(int count, {String type = 'corridor'}) =>
    List.generate(
      count,
      (i) => _node('n$i', _x0 + _stepX * i, _y0, type: type),
    );

RouteModel _linearRoute(int count) => _route(
      List.generate(count, (i) => _pn('n$i', _x0 + _stepX * i, _y0)),
    );

void main() {
  // ─── VectorMath ──────────────────────────────────────────────────────────
  group('VectorMath', () {
    test('dot/cross/norm básicos', () {
      expect(VectorMath.dot(1, 0, 0, 1), 0.0);
      expect(VectorMath.dot(2, 3, 4, 5), 23.0);
      expect(VectorMath.cross(1, 0, 0, 1), 1.0); // esquerda
      expect(VectorMath.cross(0, 1, 1, 0), -1.0); // direita
      expect(VectorMath.norm(3, 4), 5.0);
    });

    test('cosseno entre vetores', () {
      expect(VectorMath.cosineBetween(1, 0, 1, 0), closeTo(1.0, 1e-9));
      expect(VectorMath.cosineBetween(1, 0, -1, 0), closeTo(-1.0, 1e-9));
      expect(VectorMath.cosineBetween(1, 0, 0, 1), closeTo(0.0, 1e-9));
      // Vetor degenerado → 1.0
      expect(VectorMath.cosineBetween(0, 0, 1, 0), 1.0);
    });
  });

  // ─── SegmentProjector ─────────────────────────────────────────────────────
  group('SegmentProjector', () {
    test('projeta no meio do segmento', () {
      final p = SegmentProjector.projectOntoSegment(
          _x0 + 0.000060, _y0 + 0.000001, _x0, _y0, _x0 + _stepX, _y0);
      expect(p.rawT, closeTo(0.5, 0.01));
      expect(p.isClamped, isFalse);
      expect(p.perpDistMeters, lessThan(0.5));
    });

    test('clampa rawT > 1', () {
      final p = SegmentProjector.projectOntoSegment(
          _x0 + 2 * _stepX, _y0, _x0, _y0, _x0 + _stepX, _y0);
      expect(p.rawT, greaterThan(1.0));
      expect(p.clampedT, 1.0);
    });

    test('segmento degenerado retorna distância ao ponto A', () {
      final p = SegmentProjector.projectOntoSegment(
          _x0 + _stepX, _y0, _x0, _y0, _x0, _y0);
      expect(p.projX, _x0);
      expect(p.projY, _y0);
      expect(p.perpDistMeters, greaterThan(5.0));
    });
  });

  // ─── SnapEngine ──────────────────────────────────────────────────────────
  group('SnapEngine', () {
    final nodes = _linearNodes(4);
    final route = _linearRoute(4);
    final nodesMap = {for (final n in nodes) n.id: n};
    const eng = SnapEngine();

    test('Snap-to-Road: ruído lateral pequeno → marker fixo na linha', () {
      // ~5m a norte da linha
      final snap = eng.snap(
        rawX: _x0 + _stepX * 1.5,
        rawY: _y0 + 0.00004,
        route: route,
        nodesMap: nodesMap,
        currentSegmentIndex: 0,
      );
      expect(snap.useRawForUi, isFalse);
      expect(snap.snappedY, closeTo(_y0, 1e-9)); // colapsado para a linha
    });

    test('Desvio >20m → liberta snap, UI usa raw', () {
      final snap = eng.snap(
        rawX: _x0 + _stepX * 1.5,
        rawY: _y0 + 0.00030, // ~33m
        route: route,
        nodesMap: nodesMap,
        currentSegmentIndex: 0,
      );
      expect(snap.useRawForUi, isTrue);
      expect(snap.snappedY, snap.rawY);
    });
  });

  // ─── HeadingValidator ────────────────────────────────────────────────────
  group('HeadingValidator', () {
    test('arranque em ponto cego: sem prev → still=true, no jump', () {
      final hv = HeadingValidator();
      final r =
          hv.evaluate(curX: _x0, curY: _y0, now: DateTime(2026, 1, 1));
      expect(r.isStill, isTrue);
      expect(r.isMovingForward, isFalse);
      expect(r.isImplausibleJump, isFalse);
    });

    test('teleport 100m em 500ms → implausível', () {
      final hv = HeadingValidator();
      final t0 = DateTime(2026, 1, 1, 12, 0, 0);
      hv.accept(_x0, _y0, t0);
      // ~100m a Norte em 0.5s → 200 m/s
      final r = hv.evaluate(
        curX: _x0,
        curY: _y0 + 0.0009,
        now: t0.add(const Duration(milliseconds: 500)),
      );
      expect(r.isImplausibleJump, isTrue);
    });

    test('alinhamento referência: 0° → aligned', () {
      final hv = HeadingValidator();
      final t0 = DateTime(2026, 1, 1, 12, 0, 0);
      hv.accept(_x0, _y0, t0);
      final r = hv.evaluate(
        curX: _x0 + _stepX * 0.5,
        curY: _y0,
        now: t0.add(const Duration(seconds: 5)),
        refX: _x0 + _stepX,
        refY: _y0,
      );
      expect(r.isAlignedWithReference, isTrue);
      expect(r.cosToReference, greaterThan(0.99));
      expect(r.isMovingForward, isTrue);
    });

    test('U-turn 180° → cos negativo, rejeita atalho', () {
      final hv = HeadingValidator();
      final t0 = DateTime(2026, 1, 1);
      hv.accept(_x0 + _stepX, _y0, t0);
      final r = hv.evaluate(
        curX: _x0 + _stepX * 0.5,
        curY: _y0,
        now: t0.add(const Duration(seconds: 5)),
        refX: _x0 + _stepX * 2, // queremos ir para a direita, mas vamos para esquerda
        refY: _y0,
      );
      expect(r.cosToReference, lessThan(0));
      expect(r.isAlignedWithReference, isFalse);
    });
  });

  // ─── AnchorResolver ──────────────────────────────────────────────────────
  group('AnchorResolver', () {
    final nodes = _linearNodes(5);
    final route = _linearRoute(5);
    final nodesMap = {for (final n in nodes) n.id: n};

    test('não força recuo: user já à frente, prev confirma direção', () {
      const r = AnchorResolver();
      final ch = r.resolve(
        userX: _x0 + _stepX * 2.5,
        userY: _y0,
        route: route,
        nodesMap: nodesMap,
        prevX: _x0 + _stepX * 2.3,
        prevY: _y0,
      );
      // Não pode escolher segmento 0 (atrás do user); deve ser segmento 2.
      expect(ch.segmentIndex, greaterThanOrEqualTo(2));
    });
  });

  // ─── RerouteHysteresis ────────────────────────────────────────────────────
  group('RerouteHysteresis', () {
    test('off-route curto (1s) → não dispara', () {
      final h = RerouteHysteresis();
      final t0 = DateTime(2026, 1, 1);
      expect(
          h.shouldTrigger(perpDistMeters: 25.0, now: t0), isFalse);
      expect(
          h.shouldTrigger(
              perpDistMeters: 25.0,
              now: t0.add(const Duration(seconds: 1))),
          isFalse);
    });

    test('off-route sustentado 3s → dispara', () {
      final h = RerouteHysteresis();
      final t0 = DateTime(2026, 1, 1);
      h.shouldTrigger(perpDistMeters: 25.0, now: t0);
      final fired = h.shouldTrigger(
          perpDistMeters: 25.0,
          now: t0.add(const Duration(seconds: 4)));
      expect(fired, isTrue);
    });

    test('atalho válido suprime', () {
      final h = RerouteHysteresis();
      final t0 = DateTime(2026, 1, 1);
      final fired = h.shouldTrigger(
        perpDistMeters: 25.0,
        now: t0.add(const Duration(seconds: 5)),
        atShortcutValid: true,
      );
      expect(fired, isFalse);
    });

    test('desvio extremo dispara já', () {
      final h = RerouteHysteresis();
      final t0 = DateTime(2026, 1, 1);
      expect(h.shouldTrigger(perpDistMeters: 80.0, now: t0), isTrue);
    });
  });

  // ─── ZAxisGuard ───────────────────────────────────────────────────────────
  group('ZAxisGuard', () {
    test('mudança de piso sem stairs/ramp na rota → rejeita', () {
      final route = _route([
        _pn('n0', _x0, _y0),
        _pn('n1', _x0 + _stepX, _y0),
        _pn('n2', _x0 + _stepX * 2, _y0, level: 1),
      ]);
      final nodesMap = {
        'n0': _node('n0', _x0, _y0),
        'n1': _node('n1', _x0 + _stepX, _y0),
        'n2': _node('n2', _x0 + _stepX * 2, _y0, level: 1),
      };
      final g = ZAxisGuard(initialLevel: 0);
      final d = g.evaluateLevelChange(
        candidateLevel: 1,
        route: route,
        currentSegmentIndex: 0,
        nodesMap: nodesMap,
      );
      expect(d.accepted, isFalse);
      expect(d.acceptedLevel, 0);
    });

    test('stairs na rota → aceita transição', () {
      final route = _route([
        _pn('n0', _x0, _y0),
        _pn('s1', _x0 + _stepX, _y0),
        _pn('n2', _x0 + _stepX * 2, _y0, level: 1),
      ]);
      final nodesMap = {
        'n0': _node('n0', _x0, _y0),
        's1': _node('s1', _x0 + _stepX, _y0, type: 'stairs'),
        'n2': _node('n2', _x0 + _stepX * 2, _y0, level: 1),
      };
      final g = ZAxisGuard(initialLevel: 0);
      final d = g.evaluateLevelChange(
        candidateLevel: 1,
        route: route,
        currentSegmentIndex: 0,
        nodesMap: nodesMap,
      );
      expect(d.accepted, isTrue);
      expect(d.acceptedLevel, 1);
    });
  });

  // ─── End-to-end RouteTracker: dot usa GPS cru ─────────────────────────────
  group('RouteTracker integration', () {
    final nodes = _linearNodes(5);
    final route = _linearRoute(5);

    test('currentX/Y reflete GPS cru (sem simulação on-edge)', () {
      final t = RouteTracker(route: route, allNodes: nodes);
      t.seedUserPositionForNewRoute(_x0, _y0,
          level: 0, waypointIndex: 0);

      final rawX = _x0 + _stepX * 0.4;
      final rawY = _y0 + 0.00004;
      t.updateUserPosition(rawX, rawY, level: 0);
      expect(t.currentX, rawX);
      expect(t.currentY, rawY);
      expect(t.rawX, rawX);
      expect(t.rawY, rawY);
    });

    test('perp dist refletida em perpDistMeters', () {
      final t = RouteTracker(route: route, allNodes: nodes);
      t.seedUserPositionForNewRoute(_x0, _y0,
          level: 0, waypointIndex: 0);
      t.updateUserPosition(_x0 + _stepX * 0.5, _y0 + 0.00004, level: 0);
      // ~4m de perp ≈ pequeno (<10m); useRawForUi não existe mais.
      expect(t.perpDistMeters, lessThan(10.0));
    });
  });

  // ─── STRESS / Cenários extremos ───────────────────────────────────────────
  group('Stress scenarios', () {
    final nodes = _linearNodes(6);
    final route = _linearRoute(6);

    test('1) GPS teleport 1 frame → filtrado, sem progressão', () {
      final t = RouteTracker(route: route, allNodes: nodes);
      t.seedUserPositionForNewRoute(_x0, _y0,
          level: 0, waypointIndex: 1);
      final t0 = DateTime(2026, 1, 1);
      t.updateUserPosition(_x0 + _stepX, _y0,
          level: 0, now: t0);
      final idxBefore = t.currentWaypointIndex;
      // Salto absurdo
      t.updateUserPosition(
        _x0 + _stepX + 0.001,
        _y0 + 0.001,
        level: 0,
        now: t0.add(const Duration(milliseconds: 500)),
      );
      expect(t.currentWaypointIndex, idxBefore); // sem avanço
    });

    test('2) U-turn: cos negativo, heading não-alinhado', () {
      final hv = HeadingValidator();
      final t0 = DateTime(2026, 1, 1);
      hv.accept(_x0 + _stepX * 2, _y0, t0);
      final r = hv.evaluate(
        curX: _x0 + _stepX * 1.5, // recuando
        curY: _y0,
        now: t0.add(const Duration(seconds: 4)),
        refX: _x0 + _stepX * 3,
        refY: _y0,
      );
      expect(r.isAlignedWithReference, isFalse);
    });

    test('3) Z-drop: mudança de piso sem nó stairs → rejeitada', () {
      // Rota toda no piso 0, mas GPS sugere piso 1.
      final nodesL0 = _linearNodes(5);
      final routeL0 = _linearRoute(5);
      final t = RouteTracker(route: routeL0, allNodes: nodesL0);
      t.seedUserPositionForNewRoute(_x0, _y0,
          level: 0, waypointIndex: 0);
      // Atualizar com candidateLevel=1, mas sem stairs/ramp na rota.
      t.updateUserPosition(_x0 + _stepX * 0.5, _y0, level: 1);
      expect(t.currentLevel, 0); // rejeitado
    });

    test('4) Jitter alta frequência: hysteresis suprime reroute', () {
      final h = RerouteHysteresis();
      final t0 = DateTime(2026, 1, 1);
      // Ziguezague 8 amostras, cada uma com perp pequena (<20m).
      bool any = false;
      for (int i = 0; i < 8; i++) {
        final perp = (i.isEven ? 5.0 : 8.0); // sempre <20m
        if (h.shouldTrigger(
            perpDistMeters: perp,
            now: t0.add(Duration(milliseconds: 500 * i)))) {
          any = true;
        }
      }
      expect(any, isFalse);
    });

    test('5) Arranque em ponto cego: prev=null, velocidade=0 → still', () {
      final hv = HeadingValidator();
      final r = hv.evaluate(
        curX: _x0,
        curY: _y0,
        now: DateTime(2026, 1, 1),
      );
      expect(r.isStill, isTrue);
      expect(r.isMovingForward, isFalse);
      expect(r.cosToReference, 1.0); // sem referência
    });
  });

  // ─── PathFollower removido: dot agora usa GPS cru ─────────────────────────
  // Bloco mantido como no-op para preservar histórico de testes.
  group('PathFollower (removed)', () {
    test('placeholder', () {
      expect(true, isTrue);
    });
  });

}
