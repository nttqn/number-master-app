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

/// A single row of up to [kLaneCount] lane contents placed at [distance]
/// along the level (distance is measured from the level start, growing as
/// the level goes on — the generator lays rows out in increasing distance
/// order, then the runtime spawns each row's entities once its distance
/// comes within the spawn window ahead of the player).
class SpawnRow {
  const SpawnRow({required this.distance, required this.lanes});

  final double distance;
  final List<LaneContent?> lanes; // length 3: left, mid, right
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
  });

  final int level;
  final List<SpawnRow> rows;
  final List<WallSpec> walls;
  final double trackSpeed;

  /// Total distance of the running portion, before the wall sequence.
  final double runLength;
}
