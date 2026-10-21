import 'dart:math';
import 'dart:ui' hide TextStyle;

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/animation.dart' show Curves;
import 'package:flutter/painting.dart' show TextPainter, TextSpan, TextStyle, FontWeight;

import '../../models/lane.dart';
import '../../theme/palette.dart';
import '../game_state.dart';
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

  double _time = 0;

  /// The cube grows a little with every doubling of [number] so getting
  /// bigger reads at a glance, capped so it never covers its neighbors.
  double get _growth => (1 + 0.07 * log(max(1, number)) / ln2).clamp(1.0, 1.5);

  Color get _bodyColor {
    final tier = (log(max(1, number)) / ln2).floor();
    return AppPalette.playerTiers[tier.clamp(0, AppPalette.playerTiers.length - 1)];
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
    size = Vector2.all(baseSize * _growth);
  }

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final ground = size.y * 0.62;
    // A small running hop, only while the track is actually moving.
    final moving = game.stateNotifier.value == GameState.running ||
        game.stateNotifier.value == GameState.wallSequence ||
        game.stateNotifier.value == GameState.bonusStairs;
    final hop = moving ? sin(_time * 14).abs() * w * 0.06 : 0.0;

    canvas.drawOval(
      Rect.fromCenter(center: Offset(w / 2, ground), width: w * (0.95 - hop / w), height: w * 0.22),
      Paint()..color = const Color(0x40000000),
    );

    final body = _bodyColor;
    final frontW = w * 0.86;
    final frontH = w * 0.6;
    final topH = w * 0.24;
    final left = (w - frontW) / 2;
    final bottom = ground - hop;
    final front = Rect.fromLTWH(left, bottom - frontH, frontW, frontH);

    // Top face: a trapezoid narrowing away from the camera.
    final inset = w * 0.07;
    final topFace = Path()
      ..moveTo(front.left, front.top)
      ..lineTo(front.left + inset, front.top - topH)
      ..lineTo(front.right - inset, front.top - topH)
      ..lineTo(front.right, front.top)
      ..close();
    canvas.drawPath(topFace, Paint()..color = Color.lerp(body, const Color(0xFFFFFFFF), 0.4)!);

    canvas.drawRRect(
      RRect.fromRectAndCorners(front, bottomLeft: Radius.circular(w * 0.08), bottomRight: Radius.circular(w * 0.08)),
      Paint()
        ..shader = Gradient.linear(
          front.topCenter,
          front.bottomCenter,
          [body, Color.lerp(body, const Color(0xFF000000), 0.25)!],
        ),
    );
    // Glossy highlight strip along the front face's top edge.
    canvas.drawRect(
      Rect.fromLTWH(front.left, front.top, frontW, frontH * 0.14),
      Paint()..color = const Color(0x33FFFFFF),
    );

    final text = '$number';
    // Shrink-to-fit and force a single line — a fixed font size wrapped a
    // long number onto two lines that spilled outside the body.
    final fontSize = fitFontSize(textLength: text.length, desiredFontSize: w * 0.36, maxWidth: frontW * 0.88);
    final style = TextStyle(fontSize: fontSize, fontWeight: FontWeight.w900);
    final stroke = TextPainter(
      text: TextSpan(
        text: text,
        style: style.copyWith(
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = fontSize * 0.14
            ..color = const Color(0x99000000),
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final fill = TextPainter(
      text: TextSpan(text: text, style: style.copyWith(color: const Color(0xFFFFFFFF))),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final offset = Offset(w / 2 - fill.width / 2, front.center.dy - fill.height / 2);
    stroke.paint(canvas, offset);
    fill.paint(canvas, offset);
  }
}
