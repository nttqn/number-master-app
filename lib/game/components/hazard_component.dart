import 'dart:math';
import 'dart:ui';

import 'player_component.dart';
import 'track_entity.dart';

/// A non-numeric hazard (spinning saw) blocking a lane. Fatal on contact,
/// no effect if the player is in a different lane when it resolves.
class HazardComponent extends TrackEntity {
  HazardComponent({required super.lane, required super.spawnDistance}) : super(baseSize: 74);

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
    final center = Offset(size.x / 2, size.y / 2);
    final r = size.x / 2;

    canvas.drawCircle(center, r * 0.55, Paint()..color = const Color(0xFF9CA3AF));

    final spikePaint = Paint()..color = const Color(0xFFDC2626);
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
  }
}
