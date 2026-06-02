import '../../../map/data/models/node_model.dart';
import '../../../map/data/models/route_model.dart';
import '../geometry/segment_projector.dart';

/// Resultado do Snap-to-Road para um ponto GPS bruto.
class SnappedPosition {
  /// Coordenadas onde a UI deve desenhar o marcador.
  /// Se `useRawForUi` for true, vêm directas do GPS; caso contrário, são as projetadas.
  final double snappedX;
  final double snappedY;

  /// Coordenadas GPS originais (preservadas para lógica/reroute).
  final double rawX;
  final double rawY;

  /// Índice do segmento ativo (vértice inicial). -1 se sem segmento válido.
  final int segmentIndex;

  /// `t` em [0..1] dentro do segmento ativo.
  final double tOnSegment;

  /// Distância perpendicular em metros à polilinha (cru → projeção).
  final double perpDistMeters;

  /// `true` quando o engine decidiu libertar o snap rígido — UI deve
  /// desenhar o GPS cru (utilizador está em zona livre / muito desviado).
  final bool useRawForUi;

  const SnappedPosition({
    required this.snappedX,
    required this.snappedY,
    required this.rawX,
    required this.rawY,
    required this.segmentIndex,
    required this.tOnSegment,
    required this.perpDistMeters,
    required this.useRawForUi,
  });

  /// Snap = ponto cru. Usado quando rota vazia / inicialização.
  factory SnappedPosition.raw(double x, double y) => SnappedPosition(
        snappedX: x,
        snappedY: y,
        rawX: x,
        rawY: y,
        segmentIndex: -1,
        tOnSegment: 0.0,
        perpDistMeters: double.infinity,
        useRawForUi: true,
      );
}

/// Snap-to-Road reativo. Decide entre prender o marcador à rota ou libertar
/// para GPS cru com base na distância perpendicular.
///
/// **Sem free zones declaradas** — o snap "abre" reativamente quando o
/// utilizador se afasta muito da rota (limiar `releaseDistanceMeters`).
class SnapEngine {
  /// Acima desta perp dist (m), o snap é libertado e a UI usa GPS cru.
  final double releaseDistanceMeters;

  /// Quão à frente (em segmentos) procurar a partir do índice corrente.
  final int maxLookAhead;

  const SnapEngine({
    this.releaseDistanceMeters = 20.0,
    this.maxLookAhead = 8,
  });

  /// Calcula snap do ponto `(rawX,rawY)` contra `route`.
  ///
  /// `nodesMap`: lookup de coordenadas autoritativas via Map-Service.
  /// `currentSegmentIndex`: índice do segmento "atual" — não andamos atrás dele.
  SnappedPosition snap({
    required double rawX,
    required double rawY,
    required RouteModel route,
    required Map<String, NodeModel> nodesMap,
    required int currentSegmentIndex,
  }) {
    if (route.waypoints.length < 2) {
      return SnappedPosition.raw(rawX, rawY);
    }

    final vertices = <({double x, double y})>[];
    for (final wp in route.waypoints) {
      final node = nodesMap[wp.nodeId];
      vertices.add((x: node?.x ?? wp.x, y: node?.y ?? wp.y));
    }

    final match = PolylineMatcher.matchOnPolyline(
      px: rawX,
      py: rawY,
      vertices: vertices,
      fromIndex: currentSegmentIndex,
      maxLookAhead: maxLookAhead,
    );

    if (match == null) return SnappedPosition.raw(rawX, rawY);

    final p = match.projection;
    final releaseSnap = p.perpDistMeters > releaseDistanceMeters;

    return SnappedPosition(
      snappedX: releaseSnap ? rawX : p.projX,
      snappedY: releaseSnap ? rawY : p.projY,
      rawX: rawX,
      rawY: rawY,
      segmentIndex: match.segmentIndex,
      tOnSegment: p.clampedT,
      perpDistMeters: p.perpDistMeters,
      useRawForUi: releaseSnap,
    );
  }
}
