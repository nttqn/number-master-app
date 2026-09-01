import 'package:flutter_test/flutter_test.dart';
import 'package:number_master/game/spawner/level_generator.dart';
import 'package:number_master/game/spawner/spawn_row.dart';
import 'package:number_master/models/lane.dart';

/// Mirrors LevelGenerator's own worst-case simulation so the test can
/// independently verify a generated level is actually beatable, rather
/// than trusting the generator's internal accounting.
double _worstCaseStepForRow(double current, SpawnRow row) {
  double? worst;
  for (final c in row.lanes) {
    double? result;
    if (c == null) {
      result = current;
    } else if (c is GateContent) {
      result = c.op.apply(current.round(), c.value).toDouble();
    } else if (c is LooseNumberContent) {
      result = c.value < current ? current + c.value : null;
    } else {
      result = null; // hazard
    }
    if (result != null && (worst == null || result < worst)) worst = result;
  }
  return worst ?? current;
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
  }

  test('difficulty ramps up: level 20 has more hazard rows than level 1', () {
    final low = LevelGenerator.generate(1);
    final high = LevelGenerator.generate(20);
    int hazardRows(List<SpawnRow> rows) =>
        rows.where((r) => r.lanes.whereType<HazardContent>().isNotEmpty).length;
    expect(hazardRows(high.rows) / high.rows.length, greaterThanOrEqualTo(hazardRows(low.rows) / low.rows.length));
  });
}
