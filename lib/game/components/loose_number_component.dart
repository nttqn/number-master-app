import 'dart:ui';

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
    final center = Offset(size.x / 2, size.y / 2);
    canvas.drawCircle(center, size.x / 2, Paint()..color = const Color(0xFFF59E0B));
    paintCenteredLabel(canvas, '$value');
  }
}
