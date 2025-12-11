/// Modelo de instrução de navegação
/// Representa uma ação que o utilizador deve fazer (virar, continuar reto, etc.)
class NavigationInstruction {
  final String type; // 'left', 'right', 'straight', 'arrive'
  final double distanceToNextTurn; // Distância até próxima curva (metros)
  final String nodeId; // ID do nó onde acontece a instrução
  final String? streetName; // Nome da "rua" ou referência (opcional)

  NavigationInstruction({
    required this.type,
    required this.distanceToNextTurn,
    required this.nodeId,
    this.streetName,
  });

  /// Retorna o ícone apropriado para a instrução
  String get iconPath {
    switch (type) {
      case 'left':
        return 'assets/icons/turn_left.png';
      case 'right':
        return 'assets/icons/turn_right.png';
      case 'straight':
        return 'assets/icons/straight.png';
      case 'arrive':
        return 'assets/icons/arrive.png';
      default:
        return 'assets/icons/straight.png';
    }
  }

  /// Retorna texto descritivo da instrução
  String getDescription(String Function(String) translate) {
    switch (type) {
      case 'left':
        return translate('turn_left');
      case 'right':
        return translate('turn_right');
      case 'straight':
        return translate('continue_straight');
      case 'arrive':
        return translate('arrive_at_destination');
      default:
        return '';
    }
  }

  /// Formata a distância para exibição
  String get formattedDistance {
    if (distanceToNextTurn < 1) {
      return '<1 m';
    } else if (distanceToNextTurn < 10) {
      return '${distanceToNextTurn.toStringAsFixed(0)} m';
    } else {
      return '${distanceToNextTurn.round()} m';
    }
  }
}
