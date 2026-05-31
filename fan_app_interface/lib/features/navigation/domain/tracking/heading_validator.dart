import '../../../../core/utils/geographic_utils.dart';
import '../geometry/vector_math.dart';

/// Resultado da validação do vetor de marcha (movimento real do utilizador).
class HeadingValidation {
  /// Velocidade aparente em m/s desde o último ponto retido.
  final double speedMps;

  /// Cosseno do ângulo entre vetor de marcha real e vetor desejado
  /// (ex.: user→próximo waypoint). `1.0` se referência não fornecida.
  final double cosToReference;

  /// `true` se velocidade > limiar mínimo (default 1.5 km/h ≈ 0.417 m/s).
  final bool isMovingForward;

  /// `true` se o utilizador está fisicamente quase parado.
  final bool isStill;

  /// `true` se o salto excede o limite de plausibilidade (teleport / ruído extremo).
  final bool isImplausibleJump;

  /// `true` se vetor de marcha está alinhado com a referência (cos > cosThresh).
  final bool isAlignedWithReference;

  const HeadingValidation({
    required this.speedMps,
    required this.cosToReference,
    required this.isMovingForward,
    required this.isStill,
    required this.isImplausibleJump,
    required this.isAlignedWithReference,
  });
}

/// Mantém histórico do ponto anterior e produz vetor de marcha real
/// para alimentar decisões de snap / atalho / reroute.
///
/// Não toca em bússola — heading do magnetómetro permanece independente.
/// Aqui mede-se SÓ o vetor de deslocamento físico (Pos_t − Pos_{t-1}).
class HeadingValidator {
  // Velocidade máxima plausível (m/s). Salto > 3× = teleport / ruído.
  static const double maxPlausibleSpeedMps = 3.5;
  static const double implausibleMultiplier = 3.0;

  // 1.5 km/h
  static const double minMovingSpeedMps = 1.5 / 3.6;

  /// Limiar de cos(θ) para considerar "alinhado" (45°).
  static const double cosAlignmentThreshold = 0.7071; // cos(45°)

  double? _prevX;
  double? _prevY;
  DateTime? _prevTime;

  bool get hasPrev => _prevX != null && _prevY != null && _prevTime != null;

  ({double x, double y})? get lastPoint =>
      hasPrev ? (x: _prevX!, y: _prevY!) : null;

  /// Reinicia histórico (ex: após reroute, ou ao iniciar em ponto cego).
  void reset() {
    _prevX = null;
    _prevY = null;
    _prevTime = null;
  }

  /// Valida o ponto atual face ao histórico.
  ///
  /// `refX/refY` opcional: ponto de referência para teste de alinhamento
  /// (ex.: coordenadas do próximo waypoint ou do nó de atalho).
  ///
  /// IMPORTANTE: este método NÃO atualiza o histórico — chamar [accept]
  /// depois para confirmar o ponto, ou descartar (sem chamar) para o filtrar.
  HeadingValidation evaluate({
    required double curX,
    required double curY,
    required DateTime now,
    double? refX,
    double? refY,
  }) {
    if (!hasPrev) {
      // Arranque em ponto cego: sem referência de movimento.
      return const HeadingValidation(
        speedMps: 0.0,
        cosToReference: 1.0,
        isMovingForward: false,
        isStill: true,
        isImplausibleJump: false,
        isAlignedWithReference: false,
      );
    }

    final dtSec = now.difference(_prevTime!).inMilliseconds / 1000.0;
    final distMeters = GeographicUtils.calculateDistance(
      _prevX!,
      _prevY!,
      curX,
      curY,
    );
    final speed = dtSec > 0 ? distMeters / dtSec : 0.0;

    final implausible =
        speed > maxPlausibleSpeedMps * implausibleMultiplier;
    final still = distMeters < 0.5 || speed < 0.1;
    final moving = speed > minMovingSpeedMps;

    double cosRef = 1.0;
    bool aligned = false;
    if (refX != null && refY != null) {
      final dxMove = curX - _prevX!;
      final dyMove = curY - _prevY!;
      final dxRef = refX - curX;
      final dyRef = refY - curY;
      cosRef = VectorMath.cosineBetween(dxMove, dyMove, dxRef, dyRef);
      aligned = cosRef > cosAlignmentThreshold;
    }

    return HeadingValidation(
      speedMps: speed,
      cosToReference: cosRef,
      isMovingForward: moving,
      isStill: still,
      isImplausibleJump: implausible,
      isAlignedWithReference: aligned,
    );
  }

  /// Confirma o ponto e atualiza histórico.
  void accept(double x, double y, DateTime t) {
    _prevX = x;
    _prevY = y;
    _prevTime = t;
  }
}
