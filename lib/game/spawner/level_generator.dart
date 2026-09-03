import 'dart:math';

import '../../models/gate_operation.dart';
import '../../models/lane.dart';
import 'difficulty_params.dart';
import 'spawn_row.dart';

/// Procedurally builds a level's spawn rows and end-of-level wall sequence.
///
/// Two invariants are enforced *during* generation rather than checked
/// after the fact:
///  - Fairness: every row leaves at least one lane a player could take
///    without dying (empty, a gate, or a loose number smaller than the
///    worst-case number they could have at that point).
///  - Wall feasibility: the wall sequence's total cost never exceeds what a
///    worst-case (no-skill) playthrough of the generated rows would leave
///    the player holding, so every generated level is always beatable.
///
/// `generate` is deterministic for a given (level, seed) pair — replaying
/// the same level produces the same layout unless a different seed is
/// supplied.
class LevelGenerator {
  static const int _maxAttempts = 5;

  static GeneratedLevel generate(int level, {int? seed}) {
    final baseSeed = seed ?? level;
    for (int attempt = 0; attempt < _maxAttempts; attempt++) {
      final params = DifficultyParams.forLevel(level);
      final rnd = Random(baseSeed * 97 + attempt);
      final result = _tryGenerate(level, params, rnd);
      if (result != null) return result;
    }
    // Safety net: retry with the easier conservative preset — this should
    // basically always succeed since it dials density/values down.
    for (int attempt = 0; attempt < _maxAttempts; attempt++) {
      final params = DifficultyParams.conservativeFallback(level);
      final rnd = Random(baseSeed * 131 + attempt);
      final result = _tryGenerate(level, params, rnd);
      if (result != null) return result;
    }
    // Absolute last resort: never silently accept an unverified layout —
    // deterministically sanitize a conservative layout instead, so a
    // level is *always* beatable even if every randomized attempt above
    // failed its own fairness/feasibility check.
    final params = DifficultyParams.conservativeFallback(level);
    final rnd = Random(baseSeed);
    return _sanitizedGenerate(level, params, rnd);
  }

  static GeneratedLevel? _tryGenerate(int level, DifficultyParams params, Random rnd) {
    final rowsResult = _generateRows(params, rnd);
    if (!rowsResult.allFair) return null;

    final rows = rowsResult.rows;
    final worstCase = _simulateWorstCase(rows);
    final bestCase = _simulateBestCase(rows);
    final runLength = rows.isEmpty ? 0.0 : rows.last.distance + params.rowSpacing;

    final wallResult = _generateWalls(params, rnd, worstCase, bestCase, runLength);
    if (!wallResult.feasible) return null;

    return GeneratedLevel(
      level: level,
      rows: rows,
      walls: wallResult.walls,
      trackSpeed: params.trackSpeed,
      runLength: runLength,
    );
  }

  /// Builds rows normally, force-fixes any row that still isn't fair
  /// (nulls out a lane), then sizes the wall sequence directly off the
  /// resulting worst-case number — clamping each wall to what's actually
  /// left and stopping rather than ever emitting an unbeatable wall.
  static GeneratedLevel _sanitizedGenerate(int level, DifficultyParams params, Random rnd) {
    final rowsResult = _generateRows(params, rnd);
    final rows = rowsResult.rows;

    double worst = 1;
    for (int i = 0; i < rows.length; i++) {
      var lanes = rows[i].lanes;
      if (!_rowIsFair(lanes, worst)) {
        lanes = List<LaneContent?>.from(lanes);
        lanes[0] = null;
        rows[i] = SpawnRow(distance: rows[i].distance, lanes: lanes);
      }
      worst = _worstCaseStepForRow(worst, rows[i].lanes);
    }

    final runLength = rows.isEmpty ? 0.0 : rows.last.distance + params.rowSpacing;
    final walls = <WallSpec>[];
    double runningWorst = worst;
    for (int i = 0; i < params.wallSequenceLength; i++) {
      if (runningWorst < 1) break;
      final value = runningWorst.floor();
      walls.add(WallSpec(distance: runLength + (i + 1) * 12.0, value: value));
      runningWorst -= value;
    }
    if (walls.isEmpty) {
      walls.add(WallSpec(distance: runLength + 12.0, value: 1));
    }

    return GeneratedLevel(
      level: level,
      rows: rows,
      walls: walls,
      trackSpeed: params.trackSpeed,
      runLength: runLength,
    );
  }

  // ---- Row generation -----------------------------------------------

  static _RowsResult _generateRows(DifficultyParams p, Random rnd) {
    final rows = <SpawnRow>[];
    double worstSoFar = 1;
    bool allFair = true;

    for (int i = 0; i < p.rowCount; i++) {
      final distance = (i + 1) * p.rowSpacing;
      final lanes = _generateRowLanes(p, rnd, worstSoFar);
      if (!_rowIsFair(lanes, worstSoFar)) allFair = false;
      rows.add(SpawnRow(distance: distance, lanes: lanes));
      worstSoFar = _worstCaseStepForRow(worstSoFar, lanes);
    }
    return _RowsResult(rows, allFair);
  }

  static bool _rowIsFair(List<LaneContent?> lanes, double worstBefore) {
    return lanes.any((c) => _isSurvivable(c, worstBefore));
  }

  static bool _isSurvivable(LaneContent? c, double worstBefore) {
    if (c == null) return true;
    if (c is GateContent) return true;
    if (c is LooseNumberContent) return c.value < worstBefore;
    return false; // HazardContent
  }

  static List<LaneContent?> _generateRowLanes(
    DifficultyParams p,
    Random rnd,
    double currentWorst,
  ) {
    final lanes = List<LaneContent?>.filled(kLaneCount, null);
    final roll = rnd.nextDouble();
    final hazardCut = p.hazardDensity;
    final numberCut = hazardCut + p.looseNumberDensity;
    final gateCut = numberCut + 0.55;

    if (roll < hazardCut) {
      _fillHazardRow(lanes, p, rnd);
    } else if (roll < numberCut) {
      _fillNumberRow(lanes, rnd, currentWorst);
    } else if (roll < gateCut) {
      _fillGateRow(lanes, p, rnd);
    }
    // else: fully empty breather row.

    return lanes;
  }

  static void _fillHazardRow(List<LaneContent?> lanes, DifficultyParams p, Random rnd) {
    final hazardLaneCount = 1 + rnd.nextInt(kLaneCount - 1); // never all lanes (fairness)
    final order = List.generate(kLaneCount, (i) => i)..shuffle(rnd);
    for (int i = 0; i < hazardLaneCount; i++) {
      lanes[order[i]] = const HazardContent();
    }
    for (int i = hazardLaneCount; i < kLaneCount; i++) {
      lanes[order[i]] = rnd.nextBool() ? _randomGate(p, rnd) : null;
    }
  }

  static void _fillNumberRow(List<LaneContent?> lanes, Random rnd, double currentWorst) {
    final order = List.generate(kLaneCount, (i) => i)..shuffle(rnd);
    final numberLaneCount = 1 + rnd.nextInt(kLaneCount);
    final canPlaceSafeNumber = currentWorst > 1; // a value must be strictly
    // smaller than currentWorst to be absorbable — at currentWorst<=1
    // (e.g. the very start of a run, where the player holds 1) no such
    // value exists, so every "safe" number placement below falls back to
    // an empty lane instead of secretly being just as fatal as the ones
    // deliberately marked fatal.
    bool placedFatal = false;

    for (int i = 0; i < numberLaneCount; i++) {
      final lane = order[i];
      final wantFatal = !placedFatal && rnd.nextDouble() < 0.3 && currentWorst > 2;
      if (wantFatal) {
        final value = currentWorst.round() + 1 + rnd.nextInt(3);
        lanes[lane] = LooseNumberContent(value);
        placedFatal = true;
      } else if (canPlaceSafeNumber) {
        final maxSafe = max(1, (currentWorst - 1).floor());
        final value = 1 + rnd.nextInt(maxSafe);
        lanes[lane] = LooseNumberContent(value);
      } else {
        lanes[lane] = null;
      }
    }

    if (placedFatal && !lanes.any((c) => _isSurvivable(c, currentWorst))) {
      // Force whichever lane is still untouched (or the last one placed
      // with a non-fatal number) to be a guaranteed-empty escape lane.
      final untouched = order.firstWhere(
        (l) => lanes[l] == null,
        orElse: () => order.last,
      );
      lanes[untouched] = null;
    }
  }

  static void _fillGateRow(List<LaneContent?> lanes, DifficultyParams p, Random rnd) {
    final order = List.generate(kLaneCount, (i) => i)..shuffle(rnd);
    final gateLaneCount = 2 + rnd.nextInt(kLaneCount - 1); // 2..kLaneCount lanes get a gate
    for (int i = 0; i < gateLaneCount; i++) {
      lanes[order[i]] = _randomGate(p, rnd);
    }
  }

  static GateContent _randomGate(DifficultyParams p, Random rnd) {
    final op = _pickWeighted(rnd, p.opWeights);
    // Multiply/divide use their own (small, slow-growing) value range —
    // sharing add/subtract's level-scaled range let a single gate multiply
    // by dozens, which compounds into absurd numbers over a run's many
    // rows. See DifficultyParams.forLevel for the full story.
    final (low, high) = op == GateOperation.multiply || op == GateOperation.divide
        ? p.multiplyDivideValueRange
        : p.gateValueRange;
    final value = low + rnd.nextInt(max(1, high - low + 1));
    return GateContent(op, value);
  }

  static GateOperation _pickWeighted(Random rnd, Map<GateOperation, double> weights) {
    final total = weights.values.fold(0.0, (a, b) => a + b);
    double r = rnd.nextDouble() * total;
    for (final entry in weights.entries) {
      r -= entry.value;
      if (r <= 0) return entry.key;
    }
    return weights.keys.first;
  }

  // ---- Best/worst-case simulation ------------------------------------

  /// Worst-case is meant to model a no-skill/unlucky playthrough, not an
  /// adversary that deliberately idles forever — an empty ("do nothing")
  /// lane must never be allowed to win the minimum just because it exists.
  /// The fairness constraint guarantees a survivable lane every row,
  /// usually including an empty one, so treating "no change" as an
  /// eligible worst-case outcome pins this simulation at the starting
  /// number for the entire run (an empty lane's "result" is always
  /// `current`, at or below any survivable gate/number outcome). That
  /// collapses the wall budget to ~0 and made nearly every generation
  /// attempt fail its own feasibility check, silently falling back to the
  /// bland safety-net preset for most levels. Only fall through to "no
  /// change" when idling is the *only* survivable option in the row.
  static double _worstCaseStepForRow(double current, List<LaneContent?> lanes) {
    double? worstNonIdle;
    bool hasIdleOption = false;
    for (final c in lanes) {
      if (c == null) {
        hasIdleOption = true;
        continue;
      }
      final result = _resultFor(c, current);
      if (result != null && (worstNonIdle == null || result < worstNonIdle)) {
        worstNonIdle = result;
      }
    }
    if (worstNonIdle != null) return worstNonIdle;
    if (hasIdleOption) return current;
    return current; // No survivable lane at all — shouldn't happen given fairness.
  }

  static double _bestCaseStepForRow(double current, List<LaneContent?> lanes) {
    double? best;
    for (final c in lanes) {
      final result = _resultFor(c, current);
      if (result != null && (best == null || result > best)) best = result;
    }
    return best ?? current;
  }

  /// Result of taking lane content [c] at number [current], or null if
  /// doing so is fatal (excluded from best/worst-case consideration).
  static double? _resultFor(LaneContent? c, double current) {
    if (c == null) return current;
    if (c is GateContent) return c.op.apply(current.round(), c.value).toDouble();
    if (c is LooseNumberContent) {
      return c.value < current ? current + c.value : null;
    }
    return null; // HazardContent
  }

  static double _simulateWorstCase(List<SpawnRow> rows) {
    double current = 1;
    for (final row in rows) {
      current = _worstCaseStepForRow(current, row.lanes);
    }
    return current;
  }

  static double _simulateBestCase(List<SpawnRow> rows) {
    double current = 1;
    for (final row in rows) {
      current = _bestCaseStepForRow(current, row.lanes);
    }
    return current;
  }

  // ---- Wall sequence ---------------------------------------------------

  static _WallGenResult _generateWalls(
    DifficultyParams p,
    Random rnd,
    double worstCase,
    double bestCase,
    double runLength,
  ) {
    final n = p.wallSequenceLength;
    // Higher floor/ceiling than before (was 0.15..0.6): walls now eat
    // further into a worst-case run even at level 1, so clearing them
    // takes real margin from good lane choices rather than always leaving
    // a trivial leftover.
    final bias = (p.level / 20.0).clamp(0.3, 0.8);
    final rawBudget = worstCase * 0.7 + (bestCase * 0.9 - worstCase * 0.7) * bias;
    // bestCase is routinely far above worstCase (best play vs. no-skill
    // play), so blending toward it could target a budget *larger than
    // worstCase itself* — which makes feasibility structurally impossible
    // no matter how the total is split across walls, regardless of luck.
    // That was silently failing nearly every generation attempt across
    // every level, falling back to the bland safety-net preset almost
    // always. Clamp the target well under worstCase so it's achievable in
    // principle, leaving a margin for rounding.
    final budget = min(rawBudget, worstCase * 0.9);

    final walls = <WallSpec>[];
    double remainingBudget = budget;
    double runningWorst = worstCase;
    bool feasible = true;

    for (int i = 0; i < n; i++) {
      final wallsLeft = n - i;
      // Narrower variance than before (was 0.7..1.3) and rebalanced off
      // *remaining* budget/walls each step — a fixed budget/n share let
      // early rounding-up eat into what was left for the last wall.
      final randomFactor = 0.85 + rnd.nextDouble() * 0.3;
      int value = ((remainingBudget / wallsLeft) * randomFactor).round();
      if (value < 1) value = 1;
      if (value > runningWorst) {
        feasible = false;
        value = max(1, runningWorst.floor());
      }
      runningWorst -= value;
      remainingBudget -= value;
      walls.add(WallSpec(distance: runLength + (i + 1) * 12.0, value: value));
    }

    return _WallGenResult(walls, feasible);
  }
}

class _RowsResult {
  _RowsResult(this.rows, this.allFair);
  final List<SpawnRow> rows;
  final bool allFair;
}

class _WallGenResult {
  _WallGenResult(this.walls, this.feasible);
  final List<WallSpec> walls;
  final bool feasible;
}
