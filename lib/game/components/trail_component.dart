import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../../services/save_service.dart';
import '../cosmetics.dart';
import '../number_master_game.dart';

/// The shop trail streaming out behind the player. "Behind" is toward the
/// camera (screen bottom), so particles spawn at the player's feet and
/// drift down the screen, widening as they come closer — each particle
/// keeps the x it spawned at, so the trail curves when the player changes
/// lanes. Reads the selected trail live; [PlayerTrail.none] draws nothing.
class TrailComponent extends Component with HasGameReference<NumberMasterGame> {
  final List<_Particle> _particles = [];
  final Random _rnd = Random();
  double _time = 0;

  static const double _life = 0.55;
  static const double _speed = 280;

  static const List<Color> rainbow = [
    Color(0xFFFF4D6D),
    Color(0xFFFF8A3D),
    Color(0xFFFFC233),
    Color(0xFF2ED47A),
    Color(0xFF3D8BFF),
    Color(0xFFB55CFF),
  ];

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
    for (final p in _particles) {
      p.age += dt;
      p.y += p.vy * dt;
      p.x += p.vx * dt;
    }
    _particles.removeWhere((p) => p.age >= _life);

    final trail = SaveService.instance.selectedTrail;
    final player = game.player;
    if (trail == PlayerTrail.none || !player.isMoving) return;
    final footY = player.position.y + player.size.y * 0.12;
    final w = player.size.x;
    switch (trail) {
      case PlayerTrail.none:
        break;
      case PlayerTrail.rainbow:
        _particles.add(_Particle(player.position.x, footY, 0, _speed, w * 0.62));
      case PlayerTrail.fire:
        for (int i = 0; i < 2; i++) {
          _particles.add(_Particle(
            player.position.x + (_rnd.nextDouble() - 0.5) * w * 0.5,
            footY - _rnd.nextDouble() * w * 0.1,
            (_rnd.nextDouble() - 0.5) * 40,
            _speed * (0.6 + _rnd.nextDouble() * 0.4),
            w * (0.16 + _rnd.nextDouble() * 0.12),
          ));
        }
      case PlayerTrail.sparkle:
        for (int i = 0; i < 2; i++) {
          _particles.add(_Particle(
            player.position.x + (_rnd.nextDouble() - 0.5) * w * 0.9,
            footY - _rnd.nextDouble() * w * 0.4,
            (_rnd.nextDouble() - 0.5) * 60,
            _speed * (0.5 + _rnd.nextDouble() * 0.5),
            w * (0.1 + _rnd.nextDouble() * 0.08),
            hue: _rnd.nextInt(3),
          ));
        }
    }
  }

  @override
  void render(Canvas canvas) {
    final trail = SaveService.instance.selectedTrail;
    if (trail == PlayerTrail.rainbow) {
      _renderRibbon(canvas);
      return;
    }
    for (final p in _particles) {
      final t = p.age / _life;
      switch (trail) {
        case PlayerTrail.none:
        case PlayerTrail.rainbow:
          break;
        case PlayerTrail.fire:
          paintFlame(canvas, Offset(p.x, p.y), p.size * (1 + t * 1.2), t);
        case PlayerTrail.sparkle:
          paintSparkle(canvas, Offset(p.x, p.y), p.size * (0.6 + 0.4 * sin(_time * 20 + p.x)).abs(), p.hue, 1 - t);
      }
    }
  }

  /// The rainbow as one continuous ribbon: each color band is a quad
  /// strip joining consecutive particles, so it never breaks into slices
  /// however far apart particles land (low frame rate, fast track).
  void _renderRibbon(Canvas canvas) {
    final bands = TrailComponent.rainbow.length;
    for (int i = 0; i + 1 < _particles.length; i++) {
      final a = _particles[i], b = _particles[i + 1];
      final ta = a.age / _life, tb = b.age / _life;
      final wa = a.size * (1 + ta * 0.8), wb = b.size * (1 + tb * 0.8);
      final opacity = (1 - ta) * 0.85;
      for (int k = 0; k < bands; k++) {
        final la = a.x - wa / 2 + wa * k / bands, ra = la + wa / bands;
        final lb = b.x - wb / 2 + wb * k / bands, rb = lb + wb / bands;
        final path = Path()
          ..moveTo(la, a.y)
          ..lineTo(ra + 0.5, a.y)
          ..lineTo(rb + 0.5, b.y)
          ..lineTo(lb, b.y)
          ..close();
        canvas.drawPath(path, Paint()..color = TrailComponent.rainbow[k].withValues(alpha: opacity));
      }
    }
  }
}

class _Particle {
  _Particle(this.x, this.y, this.vx, this.vy, this.size, {this.hue = 0});
  double x, y, vx, vy, size;
  final int hue;
  double age = 0;
}

/// One horizontal slice of the rainbow ribbon, [width] wide, centered on
/// [c].
void paintRainbowSlice(Canvas canvas, Offset c, double width, double height, double opacity) {
  final band = width / TrailComponent.rainbow.length;
  for (int i = 0; i < TrailComponent.rainbow.length; i++) {
    canvas.drawRect(
      Rect.fromLTWH(c.dx - width / 2 + i * band, c.dy - height / 2, band + 0.5, height),
      Paint()..color = TrailComponent.rainbow[i].withValues(alpha: opacity * 0.85),
    );
  }
}

/// A fire puff at life fraction [t]: yellow core → orange → red → fading.
void paintFlame(Canvas canvas, Offset c, double r, double t) {
  final color = t < 0.3
      ? Color.lerp(const Color(0xFFFFF176), const Color(0xFFFF9800), t / 0.3)!
      : Color.lerp(const Color(0xFFFF9800), const Color(0xFFD32F2F), ((t - 0.3) / 0.7).clamp(0.0, 1.0))!;
  canvas.drawCircle(c, r, Paint()..color = color.withValues(alpha: (1 - t) * 0.85));
}

// Saturated, not white — the road surface is near-white.
const List<Color> _sparkleColors = [Color(0xFFFFB800), Color(0xFF14C8E8), Color(0xFFFF4FC0)];

/// A four-point star.
void paintSparkle(Canvas canvas, Offset c, double r, int hue, double opacity) {
  final path = Path()
    ..moveTo(c.dx, c.dy - r)
    ..quadraticBezierTo(c.dx, c.dy, c.dx + r, c.dy)
    ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r)
    ..quadraticBezierTo(c.dx, c.dy, c.dx - r, c.dy)
    ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r)
    ..close();
  canvas.drawPath(path, Paint()..color = _sparkleColors[hue % _sparkleColors.length].withValues(alpha: opacity));
}

/// Static picture of [trail] for the shop card, drawn in a [size] box
/// (streaming downward from the top center, like in game).
void paintTrailPreview(Canvas canvas, Size size, PlayerTrail trail) {
  if (size.shortestSide < 4) return;
  final cx = size.width / 2;
  switch (trail) {
    case PlayerTrail.none:
      final p = Paint()
        ..color = const Color(0x66FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      final r = size.shortestSide * 0.25;
      canvas.drawCircle(size.center(Offset.zero), r, p);
      canvas.drawLine(
        size.center(Offset(-r * 0.7, r * 0.7)),
        size.center(Offset(r * 0.7, -r * 0.7)),
        p,
      );
    case PlayerTrail.rainbow:
      for (double y = 4; y < size.height - 4; y += 6) {
        final t = y / size.height;
        paintRainbowSlice(canvas, Offset(cx, y), size.width * (0.3 + 0.4 * t), 7, 1 - t * 0.6);
      }
    case PlayerTrail.fire:
      final rnd = Random(3);
      for (int i = 0; i < 26; i++) {
        final t = i / 26;
        paintFlame(
          canvas,
          Offset(cx + (rnd.nextDouble() - 0.5) * size.width * 0.35, 8 + t * (size.height - 16)),
          size.width * (0.08 + 0.08 * t),
          t * 0.9,
        );
      }
    case PlayerTrail.sparkle:
      final rnd = Random(7);
      for (int i = 0; i < 14; i++) {
        final t = rnd.nextDouble();
        paintSparkle(
          canvas,
          Offset(cx + (rnd.nextDouble() - 0.5) * size.width * 0.7, 6 + t * (size.height - 12)),
          size.width * (0.05 + rnd.nextDouble() * 0.06),
          i,
          1 - t * 0.5,
        );
      }
  }
}
