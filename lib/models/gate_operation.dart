enum GateOperation {
  add,
  subtract,
  multiply,
  divide;

  /// True for gates painted blue (grow you) vs red (shrink you) in the
  /// original game's color language.
  bool get isBeneficialColor => this == add || this == multiply;

  String label(int value) {
    switch (this) {
      case GateOperation.add:
        return '+$value';
      case GateOperation.subtract:
        return '-$value';
      case GateOperation.multiply:
        return 'x$value';
      case GateOperation.divide:
        return '/$value';
    }
  }

  /// Applies this operation to [current], always clamped to a minimum of 1
  /// so the player's number never hits zero/negative and gets stuck unable
  /// to ever clear a wall again.
  int apply(int current, int value) {
    final int result;
    switch (this) {
      case GateOperation.add:
        result = current + value;
        break;
      case GateOperation.subtract:
        result = current - value;
        break;
      case GateOperation.multiply:
        result = current * value;
        break;
      case GateOperation.divide:
        result = value == 0 ? current : (current / value).round();
        break;
    }
    return result < 1 ? 1 : result;
  }
}
