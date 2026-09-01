import 'dart:ui';

import '../../models/gate_operation.dart';
import '../../theme/palette.dart';
import 'player_component.dart';
import 'track_entity.dart';

/// A math gate spanning one lane. Blue (add/multiply) or red
/// (subtract/divide) per the original's color language. Only applies its
/// operation if the player was in this lane when it resolved — the other
/// lanes' gates simply pass through unused, which is what forces the lane
/// choice.
class GateComponent extends TrackEntity {
  GateComponent({
    required this.op,
    required this.value,
    required super.lane,
    required super.spawnDistance,
  }) : super(baseSize: 52); // shrunk for 5 narrower lanes (was 96 for 3)

  final GateOperation op;
  final int value;

  @override
  void onResolve(PlayerComponent player) {
    if (lane == player.currentLane) {
      game.applyGate(op, value);
    }
    removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    if (size.x < 4) return;
    final color = op.isBeneficialColor ? AppPalette.friendlyNumber : AppPalette.enemyNumber;
    if (!op.isBeneficialColor) paintFlag(canvas);
    paintOutlinedNumber(canvas, op.label(value), color);
  }
}
