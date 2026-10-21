import 'dart:ui';

import '../../models/gate_operation.dart';
import '../../theme/palette.dart';
import 'player_component.dart';
import 'track_entity.dart';

/// A math gate spanning one lane, drawn as a framed glass panel. Blue
/// (add/multiply) or red (subtract/divide) per the original's color
/// language. Only applies its operation if the player was in this lane
/// when it resolved — the other lanes' gates simply pass through unused,
/// which is what forces the lane choice.
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
      game.applyGate(op, value, at: absoluteCenter, color: _color);
    }
    removeFromParent();
  }

  Color get _color => op.isBeneficialColor ? AppPalette.friendlyNumber : AppPalette.enemyNumber;

  @override
  void render(Canvas canvas) {
    if (size.x < 4) return;
    final w = size.x;
    final color = _color;
    paintShadow(canvas, widthFactor: 1.1);

    final panelW = w * 1.15;
    final panelH = size.y * 1.2;
    final panel = Rect.fromLTWH((w - panelW) / 2, groundLocalY - panelH, panelW, panelH);
    final postW = w * 0.09;

    // Translucent glass with a diagonal sheen.
    canvas.drawRect(panel, Paint()..color = color.withValues(alpha: 0.32));
    final sheen = Path()
      ..moveTo(panel.left + panelW * 0.15, panel.top)
      ..lineTo(panel.left + panelW * 0.4, panel.top)
      ..lineTo(panel.left + panelW * 0.1, panel.bottom)
      ..lineTo(panel.left, panel.bottom)
      ..close();
    canvas.drawPath(sheen, Paint()..color = const Color(0x40FFFFFF));

    // Frame: two posts and a top bar.
    final frame = Paint()..color = Color.lerp(color, const Color(0xFF000000), 0.2)!;
    canvas.drawRect(Rect.fromLTWH(panel.left - postW / 2, panel.top, postW, panelH), frame);
    canvas.drawRect(Rect.fromLTWH(panel.right - postW / 2, panel.top, postW, panelH), frame);
    canvas.drawRect(Rect.fromLTWH(panel.left - postW / 2, panel.top - postW, panelW + postW, postW * 1.3), frame);

    paintOutlinedNumber(canvas, op.label(value), color, scale: 0.5, center: panel.center);
  }
}
