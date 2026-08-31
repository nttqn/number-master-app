import 'dart:ui' hide TextStyle;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart' show TextPainter, TextSpan, TextStyle, FontWeight;

import '../../models/lane.dart';
import '../number_master_game.dart';
import 'player_component.dart';

/// Shared lifecycle for everything that lives on the track (gates, loose
/// numbers, hazards): carries a scalar [distance] to the player that
/// decreases every frame at the world's scroll speed, feeds that through
/// the game's [Projection] for screen position/scale, and fires
/// [onResolve] exactly once when [distance] crosses [resolveDistance].
///
/// Resolution is a distance-threshold event rather than pixel/AABB
/// collision — comparing [lane] to the player's current lane at the
/// instant of crossing avoids fragile hit-testing against perspective-
/// scaled sprites.
abstract class TrackEntity extends PositionComponent
    with HasGameReference<NumberMasterGame> {
  TrackEntity({
    required this.lane,
    required double spawnDistance,
    required this.baseSize,
  }) : depth = spawnDistance,
       super(anchor: Anchor.center);

  final int lane; // 0, 1, 2

  /// Remaining distance to the player. Named `depth` (not `distance`) to
  /// avoid clashing with PositionComponent's own `distance` method.
  double depth;
  final double baseSize;
  bool resolved = false;

  static const double resolveDistance = 2.0;
  static const double despawnDistance = -3.0;

  @override
  void update(double dt) {
    super.update(dt);
    depth -= game.trackSpeed * dt;

    final p = game.projection;
    position = Vector2(p.screenXAt(lane.laneOffset, depth), p.screenYAt(depth));
    final s = p.renderSizeAt(depth, baseSize);
    size = Vector2.all(s);

    if (!resolved && depth <= resolveDistance) {
      resolved = true;
      onResolve(game.player);
    }
    if (depth <= despawnDistance) {
      removeFromParent();
    }
  }

  /// Called once, at the instant this entity reaches the player's plane.
  void onResolve(PlayerComponent player);

  void paintCenteredLabel(Canvas canvas, String text, {Color color = const Color(0xFFFFFFFF)}) {
    if (size.x < 6) return;
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: size.x * 0.4, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.x * 1.4);
    tp.paint(canvas, Offset(size.x / 2 - tp.width / 2, size.y / 2 - tp.height / 2));
  }

  /// Plain bold number with a white outline, no background shape — matches
  /// the reference game's on-track number style (as opposed to the boxed
  /// badge look [paintCenteredLabel] still uses for walls).
  void paintOutlinedNumber(Canvas canvas, String text, Color color, {double scale = 0.52}) {
    if (size.x < 6) return;
    final fontSize = size.x * scale;
    final style = TextStyle(fontSize: fontSize, fontWeight: FontWeight.w900);
    final strokePainter = TextPainter(
      text: TextSpan(
        text: text,
        style: style.copyWith(
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = fontSize * 0.16
            ..color = const Color(0xFFFFFFFF),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final fillPainter = TextPainter(
      text: TextSpan(text: text, style: style.copyWith(color: color)),
      textDirection: TextDirection.ltr,
    )..layout();
    final offset = Offset(size.x / 2 - fillPainter.width / 2, size.y / 2 - fillPainter.height / 2);
    strokePainter.paint(canvas, offset);
    fillPainter.paint(canvas, offset);
  }

  /// Small flag glyph drawn above a threatening (enemy-colored) number,
  /// matching the reference's "marked as danger" cue.
  void paintFlag(Canvas canvas) {
    if (size.x < 6) return;
    final poleX = size.x / 2;
    final poleTop = -size.y * 0.28;
    final poleBottom = -size.y * 0.02;
    final polePaint = Paint()
      ..color = const Color(0xFF7A2E38)
      ..strokeWidth = size.x * 0.05
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(poleX, poleTop), Offset(poleX, poleBottom), polePaint);
    final flagPath = Path()
      ..moveTo(poleX, poleTop)
      ..lineTo(poleX + size.x * 0.26, poleTop + size.y * 0.07)
      ..lineTo(poleX, poleTop + size.y * 0.14)
      ..close();
    canvas.drawPath(flagPath, Paint()..color = const Color(0xFFE0293E));
  }
}
