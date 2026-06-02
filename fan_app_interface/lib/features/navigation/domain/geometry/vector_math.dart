import 'dart:math';

/// Pure 2D vector primitives.
///
/// Trabalha no plano (x = longitude, y = latitude) sem conversão de unidades.
/// Métricas em metros (distâncias, velocidades) vêm de Haversine via
/// `GeographicUtils.calculateDistance`. Aqui ficam só: dot, cross, norma,
/// cosseno e ângulo — operações em que a unidade do plano é irrelevante.
class VectorMath {
  /// Produto escalar 2D.
  static double dot(double ax, double ay, double bx, double by) =>
      ax * bx + ay * by;

  /// Produto vetorial (componente z) — sinal indica rotação.
  /// `>0` esquerda, `<0` direita.
  static double cross(double ax, double ay, double bx, double by) =>
      ax * by - ay * bx;

  /// Norma euclidiana (mesma unidade dos inputs).
  static double norm(double x, double y) => sqrt(x * x + y * y);

  /// Cosseno do ângulo entre dois vetores. `1.0` para vetor degenerado.
  /// Invariante à unidade — só direção.
  static double cosineBetween(double ax, double ay, double bx, double by) {
    final na = norm(ax, ay);
    final nb = norm(bx, by);
    if (na < 1e-12 || nb < 1e-12) return 1.0;
    return (dot(ax, ay, bx, by) / (na * nb)).clamp(-1.0, 1.0);
  }

  /// Ângulo absoluto em radianos entre dois vetores (0..π).
  static double angleBetween(double ax, double ay, double bx, double by) =>
      acos(cosineBetween(ax, ay, bx, by));
}
