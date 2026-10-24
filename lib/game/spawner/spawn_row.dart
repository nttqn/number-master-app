import '../../models/gate_operation.dart';

/// One lane's contents at a given spawn row. `null` means the lane is
/// empty/safe to take.
sealed class LaneContent {
  const LaneContent();
}

class GateContent extends LaneContent {
  const GateContent(this.op, this.value);
  final GateOperation op;
  final int value;
}

class LooseNumberContent extends LaneContent {
  const LooseNumberContent(this.value);
  final int value;
}

class HazardContent extends LaneContent {
  const HazardContent();
}

/// A gate that cycles through [options] on a timer (see
/// CyclingGateComponent) — whichever is showing when the player passes is
/// applied, so the player must time it. The generator's simulations treat
/// it as the worst option (worst case) or the best one (best case).
class CyclingGateContent extends LaneContent {
  const CyclingGateContent(this.options);
  final List<GateContent> options;
}

/// A gap in the bridge, [HoleContent.length] world units long and centered
/// on the row: fatal for as long as the player's lane is the hole's while
/// it passes underneath — including crossing it mid lane-change.
class HoleContent extends LaneContent {
  const HoleContent();

  /// Kept well under the row spacing (10) so there's always time to change
  /// lanes between a hole and the next row.
  static const double length = 5.0;
}

/// A saw sliding back and forth across lanes [fromLane]..[toLane] (inclusive)
/// of its row, one full back-and-forth per [period] seconds. Fatal only for
/// the lane it's over at the instant the row reaches the player, so the
/// span's lanes are passable with timing — the generator treats them as
/// open (some lane in the span is always clear).
class SawSweep {
  const SawSweep({required this.fromLane, required this.toLane, required this.period});
  final int fromLane;
  final int toLane;
  final double period;
}

/// A single row of up to [kLaneCount] lane contents placed at [distance]
/// along the level (distance is measured from the level start, growing as
/// the level goes on — the generator lays rows out in increasing distance
/// order, then the runtime spawns each row's entities once its distance
/// comes within the spawn window ahead of the player).
class SpawnRow {
  const SpawnRow({required this.distance, required this.lanes, this.sweep});

  final double distance;
  final List<LaneContent?> lanes; // length kLaneCount, leftmost to rightmost

  /// Optional sliding saw over part of this row.
  final SawSweep? sweep;
}

/// A single wall at the end of a level. Walls are full-width (not
/// lane-scoped) and resolved in sequence.
class WallSpec {
  const WallSpec({required this.distance, required this.value});
  final double distance;
  final int value;
}

/// The full output of generating one level: the ordered spawn rows plus the
/// end-of-level wall sequence, and the total track distance (so the runtime
/// knows when normal spawning ends and the wall sequence begins).
class GeneratedLevel {
  const GeneratedLevel({
    required this.level,
    required this.rows,
    required this.walls,
    required this.trackSpeed,
    required this.runLength,
    required this.stairCosts,
  });

  final int level;
  final List<SpawnRow> rows;
  final List<WallSpec> walls;
  final double trackSpeed;

  /// Total distance of the running portion, before the wall sequence.
  final double runLength;

  /// Number spent on each of the 9 bonus steps after the walls: index 0 is
  /// the x2 step, index 8 the x10 step. Costs grow geometrically, so a
  /// middling run lands mid-staircase and only near-best play reaches x10.
  final List<int> stairCosts;
}
