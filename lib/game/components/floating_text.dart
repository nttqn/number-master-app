import 'dart:ui' hide TextStyle;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart' show TextPainter, TextSpan, TextStyle, FontWeight;

/// A one-shot label ("+5", "x2", "x4 BONUS!") that pops in, floats up and
/// fades out above where something happened, then removes itself.
class FloatingText extends PositionComponent {
  FloatingText({required this.text, required this.color, required Vector2 position, this.fontSize = 30})
    : super(position: position.clone(), anchor: Anchor.center);

  final String text;
  final Color color;
  final double fontSize;

  late final TextPainter _stroke;
  late final TextPainter _fill;
  double _elapsed = 0;
  static const double _duration = 0.85;

  @override
  Future<void> onLoad() async {
    super.onLoad();
    final style = TextStyle(fontSize: fontSize, fontWeight: FontWeight.w900);
    _stroke = TextPainter(
      text: TextSpan(
        text: text,
        style: style.copyWith(
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = fontSize * 0.18
            ..color = const Color(0xFFFFFFFF),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    _fill = TextPainter(
      text: TextSpan(text: text, style: style.copyWith(color: color)),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    position.y -= 70 * dt;
    if (_elapsed >= _duration) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final t = (_elapsed / _duration).clamp(0.0, 1.0);
    // Overshoot pop-in over the first 15%, then hold; fade over the last 40%.
    final pop = t < 0.15 ? 0.6 + (t / 0.15) * 0.6 : (t < 0.25 ? 1.2 - (t - 0.15) * 2 : 1.0);
    final opacity = t < 0.6 ? 1.0 : 1 - (t - 0.6) / 0.4;
    canvas.save();
    canvas.scale(pop);
    canvas.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, opacity));
    final offset = Offset(-_fill.width / 2, -_fill.height / 2);
    _stroke.paint(canvas, offset);
    _fill.paint(canvas, offset);
    canvas.restore();
    canvas.restore();
  }
}
