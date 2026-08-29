import 'dart:ui' hide TextStyle;

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/animation.dart' show Curves;
import 'package:flutter/painting.dart' show TextPainter, TextSpan, TextStyle, FontWeight;

import '../../models/lane.dart';
import '../number_master_game.dart';

/// The player: fixed at the ground plane (distance 0), only its lane (x
/// position) ever changes, via a tween triggered by swipe input. The
/// player's number is purely a display/logic value here — [pulse] gives it
/// a little visual feedback whenever it changes.
class PlayerComponent extends PositionComponent with HasGameReference<NumberMasterGame> {
  PlayerComponent() : super(size: Vector2.all(baseSize), anchor: Anchor.center);

  static const double baseSize = 104;

  int currentLane = 1;
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

  void moveToLane(int lane) {
    if (lane == currentLane || lane < 0 || lane >= kLaneCount) return;
    currentLane = lane;
    final p = game.projection;
    final targetX = p.screenXAt(lane.laneOffset, 0);
    add(
      MoveToEffect(
        Vector2(targetX, position.y),
        EffectController(duration: 0.18, curve: Curves.easeOutCubic),
      ),
    );
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
    final tp = TextPainter(
      text: TextSpan(
        text: '$number',
        style: TextStyle(color: const Color(0xFFFFFFFF), fontSize: size.x * 0.34, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.x * 0.95);
    tp.paint(canvas, Offset(size.x / 2 - tp.width / 2, size.y / 2 - tp.height / 2));
  }
}
