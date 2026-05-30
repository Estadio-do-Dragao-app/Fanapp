import '../../../../core/utils/geographic_utils.dart';
import 'vector_math.dart';

/// Resultado de projeção ortogonal de um ponto sobre um segmento.
class SegmentProjection {
  /// Coordenadas projetadas (mesma unidade do segmento — graus lng/lat).
  final double projX;
  final double projY;

  /// `t` ao longo do segmento `[0..1]` ANTES de clamp. Pode ser negativo
  /// (atrás de A) ou > 1 (à frente de B). Permite detectar progresso real.
  final double rawT;

  /// `t` com clamp em `[0..1]` — ponto efetivamente projetado dentro do segmento.
  final double clampedT;

  /// Distância perpendicular em METROS (Haversine entre ponto cru e proj).
  final double perpDistMeters;

  /// True se a projeção caiu fora do segmento (foi clampada).
  bool get isClamped => rawT < 0 || rawT > 1;

  const SegmentProjection({
    required this.projX,
    required this.projY,
    required this.rawT,
    required this.clampedT,
    required this.perpDistMeters,
  });
}

/// Projeção ortogonal de pontos em segmentos / polilinhas.
///
/// Inputs em coordenadas geográficas (x=lng, y=lat). A projeção é calculada
/// no plano (suficiente para escalas urbanas/eventos). A distância
/// perpendicular devolvida está em metros via Haversine.
class SegmentProjector {
  /// Projeta `(px,py)` em `[(ax,ay) → (bx,by)]`.
  ///
  /// Segmento degenerado (A≈B) → projeção = A, perp = dist(p,A).
  static SegmentProjection projectOntoSegment(
    double px,
    double py,
    double ax,
    double ay,
    double bx,
    double by,
  ) {
    final dx = bx - ax;
    final dy = by - ay;
    final lenSq = dx * dx + dy * dy;

    if (lenSq < 1e-18) {
      // Segmento degenerado
      final perp = GeographicUtils.calculateDistance(px, py, ax, ay);
      return SegmentProjection(
        projX: ax,
        projY: ay,
        rawT: 0.0,
        clampedT: 0.0,
        perpDistMeters: perp,
      );
    }

    final rawT = VectorMath.dot(px - ax, py - ay, dx, dy) / lenSq;
    final clampedT = rawT.clamp(0.0, 1.0);
    final projX = ax + clampedT * dx;
    final projY = ay + clampedT * dy;
    final perp = GeographicUtils.calculateDistance(px, py, projX, projY);

    return SegmentProjection(
      projX: projX,
      projY: projY,
      rawT: rawT,
      clampedT: clampedT,
      perpDistMeters: perp,
    );
  }
}

/// Match resultante de projetar um ponto numa polilinha.
class PolylineMatch {
  /// Índice do PRIMEIRO vértice do segmento ativo. O segmento ativo é
  /// `[vertices[segmentIndex] → vertices[segmentIndex+1]]`.
  final int segmentIndex;

  /// Projeção sobre esse segmento.
  final SegmentProjection projection;

  const PolylineMatch({
    required this.segmentIndex,
    required this.projection,
  });
}

/// Procura o segmento da polilinha (lista de vértices) cuja projeção
/// ortogonal tem menor distância perpendicular, dentro de uma janela
/// `[fromIndex .. fromIndex+maxLookAhead]` para evitar saltos para trás.
class PolylineMatcher {
  /// `vertices`: pontos `(x,y)` consecutivos.
  /// `fromIndex`: segmento mínimo a considerar (índice do vértice inicial).
  /// `maxLookAhead`: nº máx. de segmentos à frente a inspecionar.
  static PolylineMatch? matchOnPolyline({
    required double px,
    required double py,
    required List<({double x, double y})> vertices,
    int fromIndex = 0,
    int maxLookAhead = 8,
  }) {
    if (vertices.length < 2) return null;

    final start = fromIndex.clamp(0, vertices.length - 2);
    final end = (start + maxLookAhead).clamp(start + 1, vertices.length - 1);

    PolylineMatch? best;
    double bestPerp = double.infinity;

    for (int i = start; i < end; i++) {
      final a = vertices[i];
      final b = vertices[i + 1];
      final proj = SegmentProjector.projectOntoSegment(
        px,
        py,
        a.x,
        a.y,
        b.x,
        b.y,
      );

      // Critério: menor perpDist. Empate quebrado por t mais à frente.
      if (proj.perpDistMeters < bestPerp - 1e-6) {
        bestPerp = proj.perpDistMeters;
        best = PolylineMatch(segmentIndex: i, projection: proj);
      }
    }
    return best;
  }
}
