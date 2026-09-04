import 'dart:ui' hide TextStyle;

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/animation.dart' show Curves;
import 'package:flutter/painting.dart' show TextPainter, TextSpan, TextStyle, FontWeight;

import '../../models/lane.dart';
import '../number_master_game.dart';
import 'text_fit.dart';

/// The player: fixed at the ground plane (distance 0). Its x position
/// follows the drag gesture 1:1 while the finger is down (clamped to the
/// road's width) — [currentLane] is continuously recomputed as "whichever
/// lane center is nearest right now", not just decided once per swipe —
/// and on release it eases into that lane's exact center. The player's
/// number is purely a display/logic value here — [pulse] gives it a little
/// visual feedback whenever it changes.
class PlayerComponent extends PositionComponent with HasGameReference<NumberMasterGame> {
  PlayerComponent() : super(size: Vector2.all(baseSize), anchor: Anchor.center);

  // Smaller than the 3-lane era's 104 — 5 narrower lanes need
  // proportionally smaller entities to leave a visible gap between them.
  static const double baseSize = 58;

  int currentLane = (kLaneCount - 1) ~/ 2;
  int number = 1;

  @override
  void onMount() {
    super.onMount();
    _snapToLane();
  }

  void _snapToLane() {
    final p = game.projection;
    position = Vector2(p.screenXAt(currentLane.laneOffset, 0), p.groundY);
  }

  /// Shifts the player by [deltaX] screen pixels (a raw drag delta),
  /// clamped to stay between the outermost lanes, and updates
  /// [currentLane] to whichever lane is nearest to the new position.
  void followDrag(double deltaX) {
    _cancelActiveMoveEffect();
    final p = game.projection;
    final minX = p.screenXAt(0.laneOffset, 0);
    final maxX = p.screenXAt((kLaneCount - 1).laneOffset, 0);
    final newX = (position.x + deltaX).clamp(minX, maxX);
    position = Vector2(newX, position.y);
    currentLane = _nearestLaneTo(newX);
  }

  /// Eases from wherever the finger left off into the exact center of
  /// [currentLane] — call on drag end.
  void snapToNearestLane() {
    _cancelActiveMoveEffect();
    final p = game.projection;
    final targetX = p.screenXAt(currentLane.laneOffset, 0);
    add(
      MoveToEffect(
        Vector2(targetX, position.y),
        EffectController(duration: 0.12, curve: Curves.easeOutCubic),
      ),
    );
  }

  int _nearestLaneTo(double x) {
    final p = game.projection;
    int nearest = 0;
    double bestDist = double.infinity;
    for (int lane = 0; lane < kLaneCount; lane++) {
      final dist = (x - p.screenXAt(lane.laneOffset, 0)).abs();
      if (dist < bestDist) {
        bestDist = dist;
        nearest = lane;
      }
    }
    return nearest;
  }

  void _cancelActiveMoveEffect() {
    for (final effect in children.whereType<MoveToEffect>().toList()) {
      effect.removeFromParent();
    }
  }

  void pulse() {
    add(
      SequenceEffect([
        ScaleEffect.by(Vector2.all(1.22), EffectController(duration: 0.08, curve: Curves.easeOut)),
        ScaleEffect.by(Vector2.all(1 / 1.22), EffectController(duration: 0.12, curve: Curves.easeIn)),
      ]),
    );
  }

  @override
  void render(Canvas canvas) {
    final center = Offset(size.x / 2, size.y / 2);
    canvas.drawCircle(center, size.x / 2, Paint()..color = const Color(0xFF10B981));
    canvas.drawCircle(
      center,
      size.x / 2,
      Paint()
        ..color = const Color(0xFFFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    final text = '$number';
    // A fixed font size wrapped a long number onto two lines that spilled
    // outside the circle instead of shrinking to fit — shrink-to-fit and
    // force a single line instead (maxLines/ellipsis as a last-resort
    // safety net, not the primary mechanism).
    final fontSize = fitFontSize(textLength: text.length, desiredFontSize: size.x * 0.34, maxWidth: size.x * 0.82);
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: const Color(0xFFFFFFFF), fontSize: fontSize, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: size.x * 0.95);
    tp.paint(canvas, Offset(size.x / 2 - tp.width / 2, size.y / 2 - tp.height / 2));
  }
}
