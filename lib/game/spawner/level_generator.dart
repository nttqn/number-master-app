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
      stairCosts: _stairCosts(worstCase, bestCase, wallResult.walls),
    );
  }

  /// Costs of the 9 bonus steps (x2 … x10), growing geometrically: the
  /// total needed to reach x(k+1) is spread evenly on a log scale from
  /// the worst-case leftover after the walls up to 90% of the best-case
  /// leftover (x10 ≈ near-perfect play).
  ///
  /// History: a flat cost of worst-case-based leftover/… was ~2 on early
  /// levels (worst-case leftover is ~1 by design, walls eat ~90% of it) so
  /// every run hit x10; a flat bestLeft/10 then became unreachable once
  /// cycling gates made the best case exponential (perfect timing on every
  /// ×). A log scale stays meaningful whether the best case is 60 or 3M.
  static List<int> _stairCosts(double worstCase, double bestCase, List<WallSpec> walls) {
    final wallTotal = walls.fold<int>(0, (sum, w) => sum + w.value);
    final low = max(1.0, worstCase - wallTotal);
    final high = max(low * 2, (bestCase - wallTotal) * 0.9);
    final costs = <int>[];
    double reached = 0;
    for (int k = 1; k <= 9; k++) {
      final threshold = low * pow(high / low, k / 9);
      final cost = max(1, (threshold - reached).ceil());
      costs.add(cost);
      reached += cost;
    }
    return costs;
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
        rows[i] = SpawnRow(distance: rows[i].distance, lanes: lanes, sweep: rows[i].sweep);
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
      stairCosts: _stairCosts(worst, _simulateBestCase(rows), walls),
    );
  }

  // ---- Row generation -----------------------------------------------

  static _RowsResult _generateRows(DifficultyParams p, Random rnd) {
    final rows = <SpawnRow>[];
    double worstSoFar = 1;
    bool allFair = true;

    for (int i = 0; i < p.rowCount; i++) {
      final distance = (i + 1) * p.rowSpacing;
      final (lanes, sweep) = _generateRowLanes(p, rnd, worstSoFar);
      if (!_rowIsFair(lanes, worstSoFar)) allFair = false;
      rows.add(SpawnRow(distance: distance, lanes: lanes, sweep: sweep));
      worstSoFar = _worstCaseStepForRow(worstSoFar, lanes);
    }
    return _RowsResult(rows, allFair);
  }

  static bool _rowIsFair(List<LaneContent?> lanes, double worstBefore) {
    return lanes.any((c) => _isSurvivable(c, worstBefore));
  }

  /// A lane in a sliding saw's span counts as survivable here: the saw
  /// covers one lane at a time, so with timing every span lane is open —
  /// and span lanes always hold gates, which are survivable anyway.
  static bool _isSurvivable(LaneContent? c, double worstBefore) => switch (c) {
    null || GateContent() || CyclingGateContent() => true,
    LooseNumberContent(:final value) => value < worstBefore,
    HazardContent() || HoleContent() => false,
  };

  static (List<LaneContent?>, SawSweep?) _generateRowLanes(
    DifficultyParams p,
    Random rnd,
    double currentWorst,
  ) {
    final lanes = List<LaneContent?>.filled(kLaneCount, null);
    if (rnd.nextDouble() < p.sweepChance) {
      return (lanes, _fillSweepRow(lanes, p, rnd));
    }
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

    return (lanes, null);
  }

  /// A saw slides over 2-3 adjacent lanes holding *good* gates — the
  /// reward sits under the blade. Outside the span the lanes are empty
  /// (optional risk) or, at higher levels, blocked (timing is the only way
  /// through).
  static SawSweep _fillSweepRow(List<LaneContent?> lanes, DifficultyParams p, Random rnd) {
    final span = p.level < 6 ? 2 : 3;
    final from = rnd.nextInt(kLaneCount - span + 1);
    final to = from + span - 1;
    for (int lane = from; lane <= to; lane++) {
      lanes[lane] = _maybeCycling(p, rnd, _gateOfColor(p, rnd, beneficial: true));
    }
    final forced = rnd.nextDouble() < p.forcedSweepChance;
    if (forced) {
      final blocker = rnd.nextDouble() < p.holeChance ? const HoleContent() : const HazardContent();
      for (int lane = 0; lane < kLaneCount; lane++) {
        if (lane < from || lane > to) lanes[lane] = blocker;
      }
    }
    // Faster at higher levels; never so fast that a lane is never clear
    // long enough to slip through.
    final period = max(1.3, 2.4 - p.level * 0.04) + rnd.nextDouble() * 0.4;
    return SawSweep(fromLane: from, toLane: to, period: period);
  }

  static void _fillHazardRow(List<LaneContent?> lanes, DifficultyParams p, Random rnd) {
    final hazardLaneCount = 1 + rnd.nextInt(kLaneCount - 1); // never all lanes (fairness)
    final order = List.generate(kLaneCount, (i) => i)..shuffle(rnd);
    final blocker = rnd.nextDouble() < p.holeChance ? const HoleContent() : const HazardContent();
    for (int i = 0; i < hazardLaneCount; i++) {
      lanes[order[i]] = blocker;
    }
    for (int i = hazardLaneCount; i < kLaneCount; i++) {
      lanes[order[i]] = rnd.nextBool() ? _maybeCycling(p, rnd, _randomGate(p, rnd)) : null;
    }
  }

  /// With [DifficultyParams.cyclingGateChance], turns [gate] into a gate
  /// that alternates with one of the opposite color (and sometimes a third
  /// random option), so taking it well takes timing.
  static LaneContent _maybeCycling(DifficultyParams p, Random rnd, GateContent gate) {
    if (rnd.nextDouble() >= p.cyclingGateChance) return gate;
    final options = [gate, _gateOfColor(p, rnd, beneficial: !gate.op.isBeneficialColor)];
    if (rnd.nextBool()) options.add(_randomGate(p, rnd));
    return CyclingGateContent(options);
  }

  /// A gate that grows (add/multiply) or shrinks (subtract/divide) the
  /// player, drawn from this level's own operation weights and ranges.
  static GateContent _gateOfColor(DifficultyParams p, Random rnd, {required bool beneficial}) {
    final weights = Map.of(p.opWeights)..removeWhere((op, w) => op.isBeneficialColor != beneficial || w <= 0);
    final op = weights.isEmpty
        ? (beneficial ? GateOperation.add : GateOperation.subtract)
        : _pickWeighted(rnd, weights);
    final (low, high) = op == GateOperation.multiply || op == GateOperation.divide
        ? p.multiplyDivideValueRange
        : p.gateValueRange;
    return GateContent(op, low + rnd.nextInt(max(1, high - low + 1)));
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
      lanes[order[i]] = _maybeCycling(p, rnd, _randomGate(p, rnd));
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
  ///
  /// Two flavors, by [timedCycling] (see [_resultsFor]):
  ///  - false, the true floor (cycling gates at their worst option): used
  ///    while generating rows, for fairness and loose-number sizing, so a
  ///    mistimed cycling gate can never strand the player in a row where
  ///    every loose number is bigger than them.
  ///  - true, cycling gates timed right: used for the wall budget, so
  ///    mistiming costs you at the walls — which you can see coming.
  static double _worstCaseStepForRow(double current, List<LaneContent?> lanes, {bool timedCycling = false}) {
    double? worstNonIdle;
    bool hasIdleOption = false;
    for (final c in lanes) {
      if (c == null) {
        hasIdleOption = true;
        continue;
      }
      for (final result in _resultsFor(c, current, timedCycling: timedCycling)) {
        if (worstNonIdle == null || result < worstNonIdle) worstNonIdle = result;
      }
    }
    if (worstNonIdle != null) return worstNonIdle;
    if (hasIdleOption) return current;
    return current; // No survivable lane at all — shouldn't happen given fairness.
  }

  static double _bestCaseStepForRow(double current, List<LaneContent?> lanes) {
    double? best;
    for (final c in lanes) {
      for (final result in _resultsFor(c, current)) {
        if (best == null || result > best) best = result;
      }
    }
    return best ?? current;
  }

  /// Every number the player could end up with by taking lane content [c]
  /// at number [current] — one per option for a cycling gate, none if it's
  /// fatal (excluded from best/worst-case consideration).
  ///
  /// [timedCycling]: a cycling gate yields only its best option, i.e. the
  /// player times it. The wall budget uses this — counting the worst
  /// option there crushed it to ~1 once cycling gates were common (level
  /// 10's walls all became 1), and timing them is the very skill they test.
  static List<double> _resultsFor(LaneContent? c, double current, {bool timedCycling = false}) => switch (c) {
    null => [current],
    GateContent(:final op, :final value) => [op.apply(current.round(), value).toDouble()],
    CyclingGateContent(:final options) when timedCycling => [
      options.map((o) => o.op.apply(current.round(), o.value).toDouble()).reduce(max),
    ],
    CyclingGateContent(:final options) => [
      for (final o in options) o.op.apply(current.round(), o.value).toDouble(),
    ],
    LooseNumberContent(:final value) => value < current ? [current + value] : [],
    HazardContent() || HoleContent() => [],
  };

  static double _simulateWorstCase(List<SpawnRow> rows) {
    double current = 1;
    for (final row in rows) {
      current = _worstCaseStepForRow(current, row.lanes, timedCycling: true);
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
