import 'dart:math';
import 'dart:ui';

import 'player_component.dart';
import 'track_entity.dart';

/// A non-numeric hazard (spinning saw) blocking a lane. Fatal on contact,
/// no effect if the player is in a different lane when it resolves.
class HazardComponent extends TrackEntity {
  HazardComponent({required super.lane, required super.spawnDistance})
    : super(baseSize: 42); // shrunk for 5 narrower lanes (was 74 for 3)

  double _spin = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _spin += dt * 9;
  }

  @override
  void onResolve(PlayerComponent player) {
    if (lane == player.currentLane) {
      game.triggerGameOver();
    }
    removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    if (size.x < 4) return;
    final r = size.x / 2;
    paintShadow(canvas, widthFactor: 0.8);
    // Upright saw blade standing on the road on a small base.
    final center = Offset(size.x / 2, groundLocalY - r * 0.95);
    canvas.drawRect(
      Rect.fromCenter(center: Offset(size.x / 2, groundLocalY - r * 0.2), width: r * 0.9, height: r * 0.4),
      Paint()..color = const Color(0xFF4B5563),
    );

    final spikePaint = Paint()..color = const Color(0xFFDC2626);
    canvas.drawCircle(center, r * 0.62, Paint()..color = const Color(0xFF991B1B));
    const spikeCount = 8;
    for (int i = 0; i < spikeCount; i++) {
      final a = _spin + i * (2 * pi / spikeCount);
      final base1 = center + Offset(cos(a - 0.2), sin(a - 0.2)) * (r * 0.5);
      final base2 = center + Offset(cos(a + 0.2), sin(a + 0.2)) * (r * 0.5);
      final tip = center + Offset(cos(a), sin(a)) * r;
      final path = Path()
        ..moveTo(base1.dx, base1.dy)
        ..lineTo(tip.dx, tip.dy)
        ..lineTo(base2.dx, base2.dy)
        ..close();
      canvas.drawPath(path, spikePaint);
    }
    // Metallic hub drawn over the spikes' bases.
    canvas.drawCircle(
      center,
      r * 0.5,
      Paint()
        ..shader = Gradient.radial(
          center - Offset(r * 0.15, r * 0.15),
          r * 0.6,
          const [Color(0xFFF3F4F6), Color(0xFF6B7280)],
        ),
    );
    canvas.drawCircle(center, r * 0.14, Paint()..color = const Color(0xFF374151));
  }
}
