import '../../../map/data/models/node_model.dart';
import '../../../map/data/models/route_model.dart';

/// Guard de transição vertical baseado em GRAFO, não em altitude GPS.
///
/// Premissa: o grafo só conecta níveis diferentes via nós tipo `stairs`
/// ou `ramp`. Se o GPS sugere que o utilizador "saltou" para outro piso
/// sem ter visitado um nó de transição na rota recente, o guard rejeita
/// e mantém o piso anterior.
///
/// Não precisa de Z explícito do POI nem altitude GPS (ruidosa).
class ZAxisGuard {
  /// Tipos de nó válidos como transição vertical.
  static const Set<String> transitionTypes = {'stairs', 'ramp', 'elevator'};

  int _currentLevel;
  String? lastVisitedTransitionId;
  DateTime? lastVisitedTransitionAt;

  ZAxisGuard({int initialLevel = 0}) : _currentLevel = initialLevel;

  int get currentLevel => _currentLevel;

  /// Reset (ex.: nova rota aplicada).
  void reset({int level = 0}) {
    _currentLevel = level;
    lastVisitedTransitionId = null;
    lastVisitedTransitionAt = null;
  }

  /// Sinaliza que o utilizador acabou de visitar/passar por este nó.
  /// Atualiza memória interna de última transição válida.
  void notifyVisited(NodeModel node) {
    if (transitionTypes.contains(node.type)) {
      lastVisitedTransitionId = node.id;
      lastVisitedTransitionAt = DateTime.now();
      _currentLevel = node.level;
    }
  }

  /// Avalia uma mudança candidata para `candidateLevel`.
  ///
  /// Devolve `accepted=true` se houve transição legítima no histórico
  /// recente da rota (entre o segmento atual e os próximos). Caso
  /// contrário rejeita e mantém o piso anterior.
  ZAxisDecision evaluateLevelChange({
    required int candidateLevel,
    required RouteModel route,
    required int currentSegmentIndex,
    required Map<String, NodeModel> nodesMap,
    int lookBackWindow = 4,
    int lookAheadWindow = 2,
  }) {
    if (candidateLevel == _currentLevel) {
      return ZAxisDecision(
        accepted: true,
        acceptedLevel: candidateLevel,
        reason: 'same-level',
      );
    }

    final from = (currentSegmentIndex - lookBackWindow)
        .clamp(0, route.waypoints.length - 1);
    final to = (currentSegmentIndex + lookAheadWindow)
        .clamp(0, route.waypoints.length - 1);

    for (int i = from; i <= to; i++) {
      final wp = route.waypoints[i];
      final node = nodesMap[wp.nodeId];
      if (node != null && transitionTypes.contains(node.type)) {
        // Há transição válida na vizinhança da rota → aceitar.
        _currentLevel = candidateLevel;
        lastVisitedTransitionId = node.id;
        return ZAxisDecision(
          accepted: true,
          acceptedLevel: candidateLevel,
          reason: 'transition-found:${node.id}(${node.type})',
        );
      }
    }

    // Sem transição na vizinhança → manter piso anterior, sinalizar fantasma.
    return ZAxisDecision(
      accepted: false,
      acceptedLevel: _currentLevel,
      reason: 'no-transition-in-window',
    );
  }
}

class ZAxisDecision {
  final bool accepted;
  final int acceptedLevel;
  final String reason;
  const ZAxisDecision({
    required this.accepted,
    required this.acceptedLevel,
    required this.reason,
  });
}
