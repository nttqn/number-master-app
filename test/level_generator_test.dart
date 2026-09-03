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
double _worstCaseStepForRow(double current, SpawnRow row) {
  double? worstNonIdle;
  bool hasIdleOption = false;
  for (final c in row.lanes) {
    if (c == null) {
      hasIdleOption = true;
      continue;
    }
    double? result;
    if (c is GateContent) {
      result = c.op.apply(current.round(), c.value).toDouble();
    } else if (c is LooseNumberContent) {
      result = c.value < current ? current + c.value : null;
    } else {
      result = null; // hazard
    }
    if (result != null && (worstNonIdle == null || result < worstNonIdle)) {
      worstNonIdle = result;
    }
  }
  if (worstNonIdle != null) return worstNonIdle;
  if (hasIdleOption) return current;
  return current;
}

double _simulateWorstCase(List<SpawnRow> rows) {
  double current = 1;
  for (final row in rows) {
    current = _worstCaseStepForRow(current, row);
  }
  return current;
}

bool _rowIsFair(SpawnRow row, double worstBefore) {
  return row.lanes.any((c) {
    if (c == null) return true;
    if (c is GateContent) return true;
    if (c is LooseNumberContent) return c.value < worstBefore;
    return false; // hazard
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
        final hazardCount = row.lanes.whereType<HazardContent>().length;
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
        rows.where((r) => r.lanes.whereType<HazardContent>().isNotEmpty).length;
    expect(hazardRows(high.rows) / high.rows.length, greaterThanOrEqualTo(hazardRows(low.rows) / low.rows.length));
  });
}
