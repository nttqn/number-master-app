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
    required this.multiplyDivideValueRange,
    required this.opWeights,
    required this.hazardDensity,
    required this.looseNumberDensity,
    required this.trackSpeed,
    required this.wallSequenceLength,
  });

  factory DifficultyParams.forLevel(int level) {
    final rowCount = min(14 + level * 2, 44);
    final gateLow = 2 + level;
    final gateHigh = 5 + level * 2;

    // Multiply/divide gates compound: with up to ~40 rows and several
    // lanes each, even a modest per-gate chance of "multiply" adds up to
    // many multiply hits in a single run, and multiplying by a
    // level-scaled value (the same range add/subtract use) each time
    // explodes exponentially — a real run reached level.number in the
    // billions at level 11. Keep multiply/divide rare (small, slow-growing
    // cap) and give their VALUES their own small, slow-growing range
    // instead of sharing add/subtract's — a x2..x6 gate still meaningfully
    // rewards good play without compounding into nonsense.
    final multiplyW = ((level - 5) * 0.02).clamp(0.0, 0.12);
    final divideW = ((level - 8) * 0.015).clamp(0.0, 0.1);
    const subtractW = 0.25;
    final addW = max(0.4, 1.0 - multiplyW - divideW - subtractW);
    final multiplyDivideHigh = min(3 + level ~/ 8, 6);

    return DifficultyParams._(
      level: level,
      rowCount: rowCount,
      rowSpacing: 10.0,
      gateValueRange: (gateLow, gateHigh),
      multiplyDivideValueRange: (2, multiplyDivideHigh),
      opWeights: {
        GateOperation.add: addW,
        GateOperation.subtract: subtractW,
        GateOperation.multiply: multiplyW,
        GateOperation.divide: divideW,
      },
      hazardDensity: (0.18 + level * 0.025).clamp(0.18, 0.5),
      looseNumberDensity: (0.20 + level * 0.02).clamp(0.20, 0.4),
      trackSpeed: 7.0 + min(level * 0.35, 7.0),
      wallSequenceLength: min(3 + level ~/ 3, 9),
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
      multiplyDivideValueRange: (2, 2),
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
  final (int, int) multiplyDivideValueRange;
  final Map<GateOperation, double> opWeights;
  final double hazardDensity;
  final double looseNumberDensity;
  final double trackSpeed;
  final int wallSequenceLength;
}
