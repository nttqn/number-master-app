import 'dart:ui' hide TextStyle;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart' show TextPainter, TextSpan, TextStyle, FontWeight;

import '../../theme/palette.dart';
import '../number_master_game.dart';
import 'text_fit.dart';

/// A full-width wall at the end of a level, not scoped to a single lane —
/// breaking through requires the player's number to be at least [value];
/// otherwise it's game over. Walls resolve in the sequence the level
/// generator laid them out in.
class WallComponent extends PositionComponent with HasGameReference<NumberMasterGame> {
  WallComponent({required this.value, required double spawnDistance})
    : depth = spawnDistance,
      super(anchor: Anchor.center);

  final int value;

  /// Remaining distance to the player. Named `depth` (not `distance`) to
  /// avoid clashing with PositionComponent's own `distance` method.
  double depth;
  bool resolved = false;

  static const double resolveDistance = 2.0;
  static const double despawnDistance = -3.0;

  @override
  void update(double dt) {
    super.update(dt);
    depth -= game.trackSpeed * dt;

    final p = game.projection;
    final s = p.scaleAt(depth);
    size = Vector2(p.maxLaneOffsetPx * 2.6 * s, 150 * s);
    position = Vector2(p.screenCenterX, p.screenYAt(depth));

    if (!resolved && depth <= resolveDistance) {
      resolved = true;
      game.resolveWall(this);
    }
    if (depth <= despawnDistance) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    if (size.x < 4) return;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), Paint()..color = AppPalette.wallFill);
    final text = '$value';
    final fontSize = fitFontSize(textLength: text.length, desiredFontSize: size.y * 0.45, maxWidth: size.x * 0.9);
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: const Color(0xFFFFFFFF), fontSize: fontSize, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout();
    tp.paint(canvas, Offset(size.x / 2 - tp.width / 2, size.y / 2 - tp.height / 2));
  }
}
