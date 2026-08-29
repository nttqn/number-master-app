import 'dart:math';

import '../../models/gate_operation.dart';

/// Difficulty knobs derived purely from the level number. Every value here
/// is a pure function of [level] so a level's difficulty is fully
/// reproducible from its number alone.
class DifficultyParams {
  DifficultyParams._({
    required this.level,
    required this.rowCount,
    required this.rowSpacing,
    required this.gateValueRange,
    required this.opWeights,
    required this.hazardDensity,
    required this.looseNumberDensity,
    required this.trackSpeed,
    required this.wallSequenceLength,
  });

  factory DifficultyParams.forLevel(int level) {
    final rowCount = min(12 + level * 2, 40);
    final gateLow = 1 + level;
    final gateHigh = 3 + level * 2;

    final multiplyW = ((level - 3) * 0.08).clamp(0.0, 0.35);
    final divideW = ((level - 7) * 0.06).clamp(0.0, 0.25);
    const subtractW = 0.25;
    final addW = max(0.15, 1.0 - multiplyW - divideW - subtractW);

    return DifficultyParams._(
      level: level,
      rowCount: rowCount,
      rowSpacing: 10.0,
      gateValueRange: (gateLow, gateHigh),
      opWeights: {
        GateOperation.add: addW,
        GateOperation.subtract: subtractW,
        GateOperation.multiply: multiplyW,
        GateOperation.divide: divideW,
      },
      hazardDensity: (0.10 + level * 0.02).clamp(0.10, 0.40),
      looseNumberDensity: (0.15 + level * 0.015).clamp(0.15, 0.35),
      trackSpeed: 6.0 + min(level * 0.3, 6.0),
      wallSequenceLength: min(3 + level ~/ 3, 8),
    );
  }

  /// A conservative preset used as a safety-net fallback if the generator
  /// can't find a feasible layout within its reroll budget — deliberately
  /// easy so a level always stays beatable.
  factory DifficultyParams.conservativeFallback(int level) {
    return DifficultyParams._(
      level: level,
      rowCount: 10,
      rowSpacing: 10.0,
      gateValueRange: (1, 3),
      opWeights: const {
        GateOperation.add: 0.7,
        GateOperation.subtract: 0.3,
        GateOperation.multiply: 0.0,
        GateOperation.divide: 0.0,
      },
      hazardDensity: 0.1,
      looseNumberDensity: 0.15,
      trackSpeed: 6.0,
      wallSequenceLength: 2,
    );
  }

  final int level;
  final int rowCount;
  final double rowSpacing;
  final (int, int) gateValueRange;
  final Map<GateOperation, double> opWeights;
  final double hazardDensity;
  final double looseNumberDensity;
  final double trackSpeed;
  final int wallSequenceLength;
}
