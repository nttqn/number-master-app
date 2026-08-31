import 'dart:ui';

import '../../theme/palette.dart';
import 'player_component.dart';
import 'track_entity.dart';

/// A loose number sitting on the track. Absorbed (adds to the player's
/// number) if smaller than the player's current number when they hit it in
/// this lane; fatal if bigger.
class LooseNumberComponent extends TrackEntity {
  LooseNumberComponent({
    required this.value,
    required super.lane,
    required super.spawnDistance,
  }) : super(baseSize: 78);

  final int value;

  @override
  void onResolve(PlayerComponent player) {
    if (lane == player.currentLane) {
      if (value < player.number) {
        game.absorbNumber(value);
      } else {
        game.triggerGameOver();
      }
    }
    removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    if (size.x < 4) return;
    // Colored live against the player's *current* number rather than fixed
    // at spawn time — matches the reference's red(danger)/blue(safe) cue
    // and doubles as real-time feedback as the player's number changes.
    final isSafe = value < game.player.number;
    final color = isSafe ? AppPalette.friendlyNumber : AppPalette.enemyNumber;
    if (!isSafe) paintFlag(canvas);
    paintOutlinedNumber(canvas, '$value', color);
  }
}
