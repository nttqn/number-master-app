import '../models/lane.dart';
import 'components/gate_component.dart';
import 'components/hazard_component.dart';
import 'components/loose_number_component.dart';
import 'components/wall_component.dart';
import 'number_master_game.dart';
import 'spawner/spawn_row.dart';

/// Drives spawning for one level attempt: converts each [SpawnRow]'s
/// level-relative distance into an entity's distance-to-player at the
/// moment it enters the spawn window, then flips the game into
/// [GameState.wallSequence] once every row has actually been resolved (not
/// merely spawned).
///
/// Walls are the exception: all of them are spawned immediately, at
/// construction time, at their true (large) distance — since a wall's
/// on-screen scale/position is a pure function of `distance - traveled`
/// regardless of when it was added, spawning it early just means it's
/// visible tiny near the horizon from the very start of the level, like a
/// finish line you can see coming, rather than popping into view once the
/// preceding rows are done.
class LevelRuntime {
  LevelRuntime(this.game, this.generated) {
    for (final wall in generated.walls) {
      game.add(WallComponent(value: wall.value, spawnDistance: wall.distance));
    }
  }

  final NumberMasterGame game;
  final GeneratedLevel generated;

  /// How far ahead of the player (in world distance units) a row entity is
  /// allowed to spawn — matches the road's visible draw distance so
  /// entities fade in near the horizon rather than popping into view.
  static const double spawnAheadDistance = 90;

  int _nextRowIndex = 0;
  double traveled = 0;
  bool wallSequenceStarted = false;

  void update(double dt) {
    traveled += game.trackSpeed * dt;

    while (_nextRowIndex < generated.rows.length &&
        generated.rows[_nextRowIndex].distance - traveled <= spawnAheadDistance) {
      _spawnRow(generated.rows[_nextRowIndex]);
      _nextRowIndex++;
    }

    // A row's entities keep depth == row.distance - traveled for their
    // entire lifetime (both decrease at trackSpeed), so waiting for
    // traveled to reach runLength (last row's distance + one row's worth
    // of margin) — not just for the last row to have *spawned* — is what
    // actually guarantees every row has been resolved before the HUD
    // switches into "break through the wall" mode.
    if (!wallSequenceStarted && _nextRowIndex >= generated.rows.length && traveled >= generated.runLength) {
      wallSequenceStarted = true;
      game.enterWallSequence();
    }
  }

  void _spawnRow(SpawnRow row) {
    final entityDistance = row.distance - traveled;
    for (int lane = 0; lane < kLaneCount; lane++) {
      final content = row.lanes[lane];
      if (content == null) continue;
      switch (content) {
        case GateContent(:final op, :final value):
          game.add(GateComponent(op: op, value: value, lane: lane, spawnDistance: entityDistance));
        case LooseNumberContent(:final value):
          game.add(LooseNumberComponent(value: value, lane: lane, spawnDistance: entityDistance));
        case HazardContent():
          game.add(HazardComponent(lane: lane, spawnDistance: entityDistance));
      }
    }
  }
}
