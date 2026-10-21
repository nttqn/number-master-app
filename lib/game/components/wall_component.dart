import 'dart:ui' hide TextStyle;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart' show TextPainter, TextSpan, TextStyle, FontWeight;

import '../../theme/palette.dart';
import '../number_master_game.dart';
import 'text_fit.dart';

/// A full-width block at the end of a level, not scoped to a single lane.
/// Shared by the wall sequence ([WallComponent]) and the bonus staircase
/// ([StairStepComponent]): both approach like any track entity, are drawn
/// as a brick block standing on the road (front face + lighter top face),
/// and resolve once when they reach the player.
abstract class FullWidthBlock extends PositionComponent with HasGameReference<NumberMasterGame> {
  FullWidthBlock({required double spawnDistance})
    : depth = spawnDistance,
      super(anchor: Anchor.bottomCenter);

  /// Remaining distance to the player. Named `depth` (not `distance`) to
  /// avoid clashing with PositionComponent's own `distance` method.
  double depth;
  bool resolved = false;

  static const double resolveDistance = 2.0;
  static const double despawnDistance = -3.0;

  /// Un-scaled (d=0) height of the block's front face.
  double get baseHeight;
  Color get color;
  String get label;

  /// Called once, when this block reaches the player.
  void onResolve();

  @override
  void update(double dt) {
    super.update(dt);
    depth -= game.trackSpeed * dt;

    final p = game.projection;
    final s = p.scaleAt(depth);
    size = Vector2(p.maxLaneOffsetPx * 2.6 * s, baseHeight * s);
    position = Vector2(p.screenCenterX, p.screenYAt(depth));
    final layer = Layers.forDepth(depth);
    if (priority != layer) priority = layer;

    if (!resolved && depth <= resolveDistance) {
      resolved = true;
      onResolve();
    }
    if (depth <= despawnDistance) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    if (size.x < 4) return;
    final w = size.x;
    final h = size.y;
    final topH = h * 0.16;

    final top = Path()
      ..moveTo(0, topH)
      ..lineTo(w * 0.03, 0)
      ..lineTo(w * 0.97, 0)
      ..lineTo(w, topH)
      ..close();
    canvas.drawPath(top, Paint()..color = Color.lerp(color, const Color(0xFFFFFFFF), 0.35)!);

    final front = Rect.fromLTWH(0, topH, w, h - topH);
    canvas.drawRect(front, Paint()..color = color);

    // Brick mortar lines, alternate rows offset by half a brick.
    final mortar = Paint()
      ..color = Color.lerp(color, const Color(0xFF000000), 0.25)!
      ..strokeWidth = (h * 0.025).clamp(0.5, 3.0);
    const rows = 4;
    const bricksPerRow = 6;
    final rowH = front.height / rows;
    final brickW = w / bricksPerRow;
    for (int r = 0; r < rows; r++) {
      final y = front.top + r * rowH;
      if (r > 0) canvas.drawLine(Offset(0, y), Offset(w, y), mortar);
      final shift = r.isOdd ? brickW / 2 : 0.0;
      for (double x = shift; x < w; x += brickW) {
        if (x <= 0) continue;
        canvas.drawLine(Offset(x, y), Offset(x, y + rowH), mortar);
      }
    }

    final fontSize = fitFontSize(textLength: label.length, desiredFontSize: front.height * 0.55, maxWidth: w * 0.9);
    final style = TextStyle(fontSize: fontSize, fontWeight: FontWeight.w900);
    final stroke = TextPainter(
      text: TextSpan(
        text: label,
        style: style.copyWith(
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = fontSize * 0.14
            ..color = const Color(0x80000000),
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final fill = TextPainter(
      text: TextSpan(text: label, style: style.copyWith(color: const Color(0xFFFFFFFF))),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final offset = Offset(w / 2 - fill.width / 2, front.center.dy - fill.height / 2);
    stroke.paint(canvas, offset);
    fill.paint(canvas, offset);
  }
}

/// A wall in the end-of-level sequence — breaking through requires the
/// player's number to be at least [value]; otherwise it's game over.
class WallComponent extends FullWidthBlock {
  WallComponent({required this.value, required super.spawnDistance});

  final int value;

  @override
  double get baseHeight => 150;

  @override
  Color get color => AppPalette.wallFill;

  @override
  String get label => '$value';

  @override
  void onResolve() => game.resolveWall(this);
}

/// One step of the bonus staircase after the walls: costs [cost] of the
/// player's number to smash; each one smashed raises the coin multiplier
/// to [multiplier]. Running out of number just ends the bonus — never a
/// game over. Later steps are taller, so the row reads as a staircase.
class StairStepComponent extends FullWidthBlock {
  StairStepComponent({required this.multiplier, required this.cost, required super.spawnDistance});

  final int multiplier;
  final int cost;

  @override
  double get baseHeight => 60 + (multiplier - 2) * 16;

  @override
  Color get color => AppPalette.stairColors[(multiplier - 2).clamp(0, AppPalette.stairColors.length - 1)];

  @override
  String get label => 'x$multiplier';

  @override
  void onResolve() => game.resolveStairStep(this);
}
