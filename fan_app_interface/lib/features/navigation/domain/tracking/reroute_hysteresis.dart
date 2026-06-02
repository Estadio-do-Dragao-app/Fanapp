/// Histerese temporal para o gatilho de re-routing.
///
/// Princípio: nem todo o desvio momentâneo merece chamada ao servidor.
/// Só dispara quando `perpDist > offRouteMeters` SE SUSTÉM por
/// `sustainedDuration`. Reset assim que o utilizador volta para perto da rota.
///
/// Ruído curto (jitter, GPS drift, salto único): ignorado.
/// Desvio real (atalho confirmado, mudança de caminho): dispara.
class RerouteHysteresis {
  /// Acima deste valor de perpDist (m), conta-se como off-route candidato.
  final double offRouteMeters;

  /// Quanto tempo o off-route precisa de se manter para disparar reroute.
  final Duration sustainedDuration;

  /// Bypass: acima deste valor dispara já (desvio absurdo).
  final double extremeOffRouteMeters;

  /// Cooldown após cada disparo (evita loop).
  final Duration cooldown;

  DateTime? _offRouteSince;
  DateTime? _lastTriggerAt;

  RerouteHysteresis({
    this.offRouteMeters = 20.0,
    this.sustainedDuration = const Duration(seconds: 3),
    this.extremeOffRouteMeters = 50.0,
    this.cooldown = const Duration(seconds: 10),
  });

  /// Estado actual em formato debug.
  Duration get currentSustainedFor =>
      _offRouteSince == null
          ? Duration.zero
          : DateTime.now().difference(_offRouteSince!);

  /// Decide se deve disparar reroute neste instante.
  ///
  /// Devolve true UMA VEZ por episódio sustentado, depois entra em cooldown.
  bool shouldTrigger({
    required double perpDistMeters,
    required DateTime now,
    bool atShortcutValid = false,
  }) {
    // Cooldown ativo?
    if (_lastTriggerAt != null &&
        now.difference(_lastTriggerAt!) < cooldown) {
      return false;
    }

    // Atalho validado pelo heading validator + free-zone reactiva?
    // O atalho pode estar "off route" mas é movimento legítimo.
    if (atShortcutValid) {
      _offRouteSince = null;
      return false;
    }

    // Trigger imediato para desvios extremos.
    if (perpDistMeters > extremeOffRouteMeters) {
      _lastTriggerAt = now;
      _offRouteSince = null;
      return true;
    }

    if (perpDistMeters > offRouteMeters) {
      _offRouteSince ??= now;
      if (now.difference(_offRouteSince!) >= sustainedDuration) {
        _lastTriggerAt = now;
        _offRouteSince = null;
        return true;
      }
    } else {
      // Voltou para dentro do raio — reset.
      _offRouteSince = null;
    }

    return false;
  }

  /// Reset manual (ex.: rota nova aplicada).
  void reset() {
    _offRouteSince = null;
    _lastTriggerAt = DateTime.now();
  }
}
