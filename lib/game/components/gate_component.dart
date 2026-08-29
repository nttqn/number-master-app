import 'dart:ui';

import '../../models/gate_operation.dart';
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
  }) : super(baseSize: 96);

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
    final color = op.isBeneficialColor ? const Color(0xFF3B82F6) : const Color(0xFFEF4444);
    final rect = Rect.fromLTWH(0, 0, size.x, size.y * 1.6);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(size.x * 0.18)),
      Paint()..color = color,
    );
    paintCenteredLabel(canvas, op.label(value));
  }
}
