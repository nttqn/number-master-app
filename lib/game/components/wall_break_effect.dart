import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

/// A short-lived burst of rectangular shards exploding outward from where
/// a wall was, fading and shrinking out over [_duration] then removing
/// itself — a self-contained one-shot effect, not tied to the wall's own
/// lifecycle (the wall is removed the instant it breaks; this keeps
/// playing independently after that).
class WallBreakEffect extends PositionComponent {
  WallBreakEffect({required Vector2 position, required double scale, required this.color})
    : _baseShardSize = (18 * scale).clamp(4.0, 40.0),
      super(position: position.clone(), anchor: Anchor.center);

  final Color color;
  final double _baseShardSize;
  final List<_Shard> _shards = [];
  final Random _rnd = Random();

  double _elapsed = 0;
  static const double _duration = 0.5;
  static const int _shardCount = 12;

  @override
  Future<void> onLoad() async {
    super.onLoad();
    for (int i = 0; i < _shardCount; i++) {
      final angle = _rnd.nextDouble() * pi * 2;
      final speed = 90 + _rnd.nextDouble() * 160;
      _shards.add(
        _Shard(
          velocity: Vector2(cos(angle), sin(angle)) * speed,
          rotationSpeed: (_rnd.nextDouble() - 0.5) * 12,
          size: _baseShardSize * (0.5 + _rnd.nextDouble()),
        ),
      );
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    for (final shard in _shards) {
      shard.offset += shard.velocity * dt;
      shard.velocity *= 0.90;
      shard.rotation += shard.rotationSpeed * dt;
    }
    if (_elapsed >= _duration) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final t = (_elapsed / _duration).clamp(0.0, 1.0);
    final opacity = 1 - t;
    final shrink = 1 - t * 0.6;
    final paint = Paint()..color = color.withValues(alpha: opacity);
    for (final shard in _shards) {
      canvas.save();
      canvas.translate(shard.offset.x, shard.offset.y);
      canvas.rotate(shard.rotation);
      final s = shard.size * shrink;
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: s, height: s), paint);
      canvas.restore();
    }
  }
}

class _Shard {
  _Shard({required this.velocity, required this.rotationSpeed, required this.size});
  Vector2 offset = Vector2.zero();
  Vector2 velocity;
  double rotation = 0;
  double rotationSpeed;
  double size;
}
