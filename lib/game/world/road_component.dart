import 'dart:ui';

import 'package:flame/components.dart';

import '../number_master_game.dart';

/// Draws the converging 3-lane road by sampling the same [Projection] used
/// for every entity at a handful of reference distances and connecting the
/// points — this is what makes the road's edges/dividers curve in a way
/// that visually matches how entities approach along them.
class RoadComponent extends PositionComponent with HasGameReference<NumberMasterGame> {
  static const List<double> _samples = [500, 250, 130, 70, 40, 22, 12, 6, 2, 0];

  @override
  void render(Canvas canvas) {
    final size = game.size;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), Paint()..color = const Color(0xFF0F172A));

    final p = game.projection;

    Offset pt(double laneOffset, double d) => Offset(p.screenXAt(laneOffset, d), p.screenYAt(d));

    final leftEdge = _samples.map((d) => pt(-1.6, d)).toList();
    final rightEdge = _samples.map((d) => pt(1.6, d)).toList();

    final roadPath = Path()..moveTo(leftEdge.first.dx, leftEdge.first.dy);
    for (final o in leftEdge.skip(1)) {
      roadPath.lineTo(o.dx, o.dy);
    }
    for (final o in rightEdge.reversed) {
      roadPath.lineTo(o.dx, o.dy);
    }
    roadPath.close();
    canvas.drawPath(roadPath, Paint()..color = const Color(0xFF334155));

    final dividerPaint = Paint()
      ..color = const Color(0x59FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    for (final laneOffset in [-0.5, 0.5]) {
      final points = _samples.map((d) => pt(laneOffset, d)).toList();
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final o in points.skip(1)) {
        path.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(path, dividerPaint);
    }
  }
}
