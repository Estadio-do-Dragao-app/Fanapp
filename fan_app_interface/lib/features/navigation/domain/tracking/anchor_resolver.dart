import '../../../map/data/models/node_model.dart';
import '../../../map/data/models/route_model.dart';
import '../geometry/segment_projector.dart';
import '../geometry/vector_math.dart';

/// Resultado da ancoragem inicial / pós-reroute.
class AnchorChoice {
  /// Índice do segmento ativo (vértice inicial). 0 se não houver escolha melhor.
  final int segmentIndex;

  /// `t` em [0..1] dentro do segmento ativo.
  final double tOnSegment;

  /// Razão da escolha (debug).
  final String reason;

  const AnchorChoice({
    required this.segmentIndex,
    required this.tOnSegment,
    required this.reason,
  });
}

/// Ancoragem inteligente: escolhe o segmento da rota onde o utilizador
/// deve aparecer após início ou recálculo, evitando "nós fantasma" que
/// obriguem o utilizador a recuar.
///
/// Regras:
/// 1. Procura segmento com menor perpDist dentro da janela inicial.
/// 2. Se houver vetor de marcha conhecido (prevPos), só aceita segmento
///    cujo vetor (proj→fim) esteja alinhado com o movimento (cos > cosThresh).
/// 3. Se proj cair antes do início do segmento (rawT < 0), recua para
///    `t = 0` desse segmento (sem saltar para trás na polilinha).
class AnchorResolver {
  final double cosForwardThreshold;
  final int searchWindow;

  const AnchorResolver({
    this.cosForwardThreshold = 0.0, // ≥ 90° significa não-retrocesso
    this.searchWindow = 6,
  });

  AnchorChoice resolve({
    required double userX,
    required double userY,
    required RouteModel route,
    required Map<String, NodeModel> nodesMap,
    double? prevX,
    double? prevY,
  }) {
    if (route.waypoints.length < 2) {
      return const AnchorChoice(
        segmentIndex: 0,
        tOnSegment: 0.0,
        reason: 'route-too-short',
      );
    }

    final vertices = <({double x, double y})>[];
    for (final wp in route.waypoints) {
      final node = nodesMap[wp.nodeId];
      vertices.add((x: node?.x ?? wp.x, y: node?.y ?? wp.y));
    }

    final limit = vertices.length - 1;
    final end = searchWindow.clamp(1, limit);

    int bestIdx = 0;
    double bestT = 0.0;
    double bestPerp = double.infinity;
    String bestReason = 'fallback-first';

    for (int i = 0; i < end; i++) {
      final a = vertices[i];
      final b = vertices[i + 1];
      final proj = SegmentProjector.projectOntoSegment(
        userX, userY, a.x, a.y, b.x, b.y,
      );

      // Coerência de marcha: vetor (user→fim-do-segmento) vs (prev→user)
      bool forwardOk = true;
      double cos = 1.0;
      if (prevX != null && prevY != null) {
        final dxMove = userX - prevX;
        final dyMove = userY - prevY;
        final dxAhead = b.x - userX;
        final dyAhead = b.y - userY;
        cos = VectorMath.cosineBetween(dxMove, dyMove, dxAhead, dyAhead);
        forwardOk = cos > cosForwardThreshold;
      }

      if (proj.perpDistMeters < bestPerp && forwardOk) {
        bestPerp = proj.perpDistMeters;
        bestIdx = i;
        bestT = proj.clampedT;
        bestReason = 'best-perp=${proj.perpDistMeters.toStringAsFixed(1)}m '
            'cos=${cos.toStringAsFixed(2)}';
      }
    }

    return AnchorChoice(
      segmentIndex: bestIdx,
      tOnSegment: bestT,
      reason: bestReason,
    );
  }
}
