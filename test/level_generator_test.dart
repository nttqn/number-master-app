import 'package:flutter_test/flutter_test.dart';
import 'package:number_master/game/spawner/difficulty_params.dart';
import 'package:number_master/game/spawner/level_generator.dart';
import 'package:number_master/game/spawner/spawn_row.dart';
import 'package:number_master/models/lane.dart';

/// Mirrors LevelGenerator's own worst-case simulation so the test can
/// independently verify a generated level is actually beatable, rather
/// than trusting the generator's internal accounting. An idle/empty lane
/// only counts as the worst-case outcome when it's the *only* survivable
/// option in the row — otherwise it pins the simulation at the starting
/// number forever, since an idle lane's "result" is always `current`.
///
/// [timedCycling]: cycling gates count as their best option (the player
/// times them) — the wall-feasibility flavor. Without it they count as
/// every option, the true floor used for per-row fairness.
double _worstCaseStepForRow(double current, SpawnRow row, {bool timedCycling = false}) {
  double? worstNonIdle;
  bool hasIdleOption = false;
  for (final c in row.lanes) {
    if (c == null) {
      hasIdleOption = true;
      continue;
    }
    final results = <double>[];
    if (c is GateContent) {
      results.add(c.op.apply(current.round(), c.value).toDouble());
    } else if (c is CyclingGateContent) {
      final outcomes = c.options.map((o) => o.op.apply(current.round(), o.value).toDouble());
      if (timedCycling) {
        results.add(outcomes.reduce((a, b) => a > b ? a : b));
      } else {
        results.addAll(outcomes);
      }
    } else if (c is LooseNumberContent) {
      if (c.value < current) results.add(current + c.value);
    } // hazard / hole: fatal, no result
    for (final result in results) {
      if (worstNonIdle == null || result < worstNonIdle) worstNonIdle = result;
    }
  }
  if (worstNonIdle != null) return worstNonIdle;
  if (hasIdleOption) return current;
  return current;
}

double _simulateWorstCase(List<SpawnRow> rows) {
  double current = 1;
  for (final row in rows) {
    current = _worstCaseStepForRow(current, row, timedCycling: true);
  }
  return current;
}

bool _rowIsFair(SpawnRow row, double worstBefore) {
  return row.lanes.any((c) {
    if (c == null) return true;
    if (c is GateContent || c is CyclingGateContent) return true;
    if (c is LooseNumberContent) return c.value < worstBefore;
    return false; // hazard / hole
  });
}

void main() {
  for (final level in [1, 2, 5, 10, 15, 20, 30]) {
    test('level $level: every row leaves a survivable lane', () {
      final generated = LevelGenerator.generate(level);
      double worst = 1;
      for (final row in generated.rows) {
        expect(
          _rowIsFair(row, worst),
          isTrue,
          reason: 'row at distance ${row.distance} in level $level has no safe lane '
              '(worst-case number entering it: $worst)',
        );
        worst = _worstCaseStepForRow(worst, row);
      }
    });

    test('level $level: wall sequence is always beatable worst-case', () {
      final generated = LevelGenerator.generate(level);
      double number = _simulateWorstCase(generated.rows);
      for (final wall in generated.walls) {
        expect(
          number,
          greaterThanOrEqualTo(wall.value.toDouble()),
          reason: 'level $level: worst-case number $number cannot break a wall of ${wall.value}',
        );
        number -= wall.value;
      }
    });

    test('level $level: generation is deterministic for a fixed seed', () {
      final a = LevelGenerator.generate(level, seed: 42);
      final b = LevelGenerator.generate(level, seed: 42);
      expect(a.rows.length, b.rows.length);
      expect(a.walls.map((w) => w.value), b.walls.map((w) => w.value));
      for (var i = 0; i < a.rows.length; i++) {
        expect(a.rows[i].lanes.toString(), b.rows[i].lanes.toString());
      }
    });

    test('level $level: no row has all lanes hazardous', () {
      final generated = LevelGenerator.generate(level);
      for (final row in generated.rows) {
        final hazardCount = row.lanes.where((c) => c is HazardContent || c is HoleContent).length;
        expect(hazardCount, lessThan(kLaneCount));
      }
    });

    // Regression test for a real bug: the wall budget could target a total
    // above what worst-case play could ever pay (since it blends toward
    // bestCase, routinely far above worstCase), making feasibility
    // structurally impossible — which silently exhausted every retry and
    // fell back to the bland conservativeFallback preset (fixed 10 rows)
    // for nearly every level, regardless of the level number requested.
    // If this ever regresses, every level will quietly look identical
    // again instead of following DifficultyParams.forLevel's own curve.
    test('level $level: uses the real difficulty curve, not the fallback preset', () {
      final generated = LevelGenerator.generate(level);
      final expectedRowCount = DifficultyParams.forLevel(level).rowCount;
      expect(
        generated.rows.length,
        expectedRowCount,
        reason:
            'level $level generated ${generated.rows.length} rows instead of the '
            'expected $expectedRowCount — likely silently fell back to the '
            'conservative/sanitized safety-net preset instead of using the '
            'real per-level difficulty curve',
      );
    });
  }

  test('difficulty ramps up: level 20 has more hazard rows than level 1', () {
    final low = LevelGenerator.generate(1);
    final high = LevelGenerator.generate(20);
    int hazardRows(List<SpawnRow> rows) =>
        rows.where((r) => r.lanes.any((c) => c is HazardContent || c is HoleContent)).length;
    expect(hazardRows(high.rows) / high.rows.length, greaterThanOrEqualTo(hazardRows(low.rows) / low.rows.length));
  });

  test('bonus stairs: 9 steps, each costs at least 1, later steps cost more', () {
    for (int level = 1; level <= 40; level++) {
      final costs = LevelGenerator.generate(level).stairCosts;
      expect(costs.length, 9, reason: 'level $level');
      expect(costs.every((c) => c >= 1), isTrue, reason: 'level $level');
      expect(costs.last, greaterThan(costs.first), reason: 'level $level');
    }
  });

  test('bonus stairs stay on a log scale even when the best case explodes', () {
    // Regression: a flat bestLeft/10 cost made each step cost ~300k at
    // level 10 once cycling gates made the best case exponential. On a
    // log scale the first steps stay cheap next to the whole staircase.
    for (final level in [10, 15, 20, 30]) {
      final costs = LevelGenerator.generate(level).stairCosts;
      final total = costs.fold<int>(0, (a, b) => a + b);
      expect(costs.first * 20, lessThan(total), reason: 'level $level costs $costs');
    }
  });

  // Many seeds per level, so "appears at level N" doesn't hinge on one
  // lucky layout.
  List<SpawnRow> rowsAcrossSeeds(int level) => [
    for (int seed = 1; seed <= 25; seed++) ...LevelGenerator.generate(level, seed: seed).rows,
  ];

  test('new obstacles phase in: saws from 3, cycling gates from 5, holes from 8', () {
    bool hasSweep(List<SpawnRow> rows) => rows.any((r) => r.sweep != null);
    bool hasCycling(List<SpawnRow> rows) => rows.any((r) => r.lanes.any((c) => c is CyclingGateContent));
    bool hasHole(List<SpawnRow> rows) => rows.any((r) => r.lanes.any((c) => c is HoleContent));

    for (final level in [1, 2]) {
      final rows = rowsAcrossSeeds(level);
      expect(hasSweep(rows) || hasCycling(rows) || hasHole(rows), isFalse, reason: 'level $level');
    }
    expect(hasSweep(rowsAcrossSeeds(3)), isTrue);
    expect(hasCycling(rowsAcrossSeeds(4)), isFalse);
    expect(hasCycling(rowsAcrossSeeds(5)), isTrue);
    expect(hasHole(rowsAcrossSeeds(7)), isFalse);
    expect(hasHole(rowsAcrossSeeds(8)), isTrue);
  });

  test('sliding saw rows: span is in range and every span lane holds a gate', () {
    for (final level in [3, 6, 10, 20]) {
      for (final row in rowsAcrossSeeds(level).where((r) => r.sweep != null)) {
        final s = row.sweep!;
        expect(s.fromLane, greaterThanOrEqualTo(0));
        expect(s.toLane, lessThan(kLaneCount));
        expect(s.toLane, greaterThan(s.fromLane));
        expect(s.period, greaterThan(1.0));
        for (int lane = s.fromLane; lane <= s.toLane; lane++) {
          final c = row.lanes[lane];
          // Sanitizing may empty lane 0; otherwise it's a gate.
          expect(c == null || c is GateContent || c is CyclingGateContent, isTrue, reason: 'level $level lane $lane');
        }
      }
    }
  });

  test('cycling gates always mix a growing and a shrinking option', () {
    for (final row in rowsAcrossSeeds(12)) {
      for (final c in row.lanes.whereType<CyclingGateContent>()) {
        expect(c.options.length, inInclusiveRange(2, 3));
        expect(c.options.any((o) => o.op.isBeneficialColor), isTrue);
        expect(c.options.any((o) => !o.op.isBeneficialColor), isTrue);
      }
    }
  });

  test('holes leave time to change lanes before the next row', () {
    // A hole spans ±length/2 around its row; rows are 10 apart.
    expect(HoleContent.length, lessThan(DifficultyParams.forLevel(20).rowSpacing * 0.6));
  });

  test('early levels: bonus steps are not trivially cheap', () {
    // Regression: a worst-case-based cost made steps cost 2-3 here, so
    // every real run reached x10 (reaching it took ~20 in total).
    for (int level = 1; level <= 5; level++) {
      final total = LevelGenerator.generate(level).stairCosts.fold<int>(0, (a, b) => a + b);
      expect(total, greaterThanOrEqualTo(40), reason: 'level $level');
    }
  });
}
