import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/animation.dart' show Curves;

import '../../models/lane.dart';
import '../../services/save_service.dart';
import '../game_state.dart';
import '../number_master_game.dart';
import '../skin_painter.dart';

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

  /// Shrink and sink through a hole in the bridge.
  void fall() {
    _cancelActiveMoveEffect();
    add(ScaleEffect.to(Vector2.all(0.15), EffectController(duration: 0.5, curve: Curves.easeIn)));
    add(MoveByEffect(Vector2(0, size.y * 0.9), EffectController(duration: 0.5, curve: Curves.easeIn)));
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

  bool get isMoving {
    final s = game.stateNotifier.value;
    return s == GameState.running || s == GameState.wallSequence || s == GameState.bonusStairs;
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
    final hop = isMoving ? sin(_time * 14).abs() * w * 0.06 : 0.0;

    canvas.drawOval(
      Rect.fromCenter(center: Offset(w / 2, ground), width: w * (0.95 - hop / w), height: w * 0.22),
      Paint()..color = const Color(0x40000000),
    );
    // Read live so a skin picked in the shop (reachable from pause) shows
    // as soon as play resumes.
    paintPlayerSkin(canvas, w: w, ground: ground, hop: hop, skin: SaveService.instance.selectedSkin, number: number);
  }
}
