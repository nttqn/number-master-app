import 'dart:ui';

import 'package:flame/components.dart';

import '../../models/lane.dart';
import '../../theme/palette.dart';
import '../number_master_game.dart';

/// Draws the converging kLaneCount-lane road by sampling the same
/// [Projection] used for every entity at a handful of reference distances
/// and connecting the points — this is what makes the road's edges/
/// dividers curve in a way that visually matches how entities approach
/// along them. The road surface is banded with alternating light stripes
/// (rather than a single flat fill) for a bit of texture/depth cue as it
/// recedes.
class RoadComponent extends PositionComponent with HasGameReference<NumberMasterGame> {
  static const List<double> _samples = [500, 250, 130, 70, 40, 22, 12, 6, 2, 0];

  Image? _backgroundImage;

  @override
  Future<void> onLoad() async {
    super.onLoad();
    try {
      _backgroundImage = await game.images.load('bg.png');
    } catch (_) {
      // Missing/invalid asset — falls back to the plain gradient sky below.
    }
  }

  @override
  void render(Canvas canvas) {
    final size = game.size;
    final bg = _backgroundImage;
    if (bg != null) {
      canvas.drawImageRect(bg, _coverSrcRect(bg, size), Rect.fromLTWH(0, 0, size.x, size.y), Paint());
    } else {
      final skyPaint = Paint()
        ..shader = Gradient.linear(
          Offset(size.x / 2, 0),
          Offset(size.x / 2, size.y),
          [AppPalette.skyTop, AppPalette.skyBottom],
        );
      canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), skyPaint);
    }

    final p = game.projection;

    Offset pt(double laneOffset, double d) => Offset(p.screenXAt(laneOffset, d), p.screenYAt(d));

    final leftEdge = _samples.map((d) => pt(-1.6, d)).toList();
    final rightEdge = _samples.map((d) => pt(1.6, d)).toList();

    for (int i = 0; i < _samples.length - 1; i++) {
      final band = Path()
        ..moveTo(leftEdge[i].dx, leftEdge[i].dy)
        ..lineTo(rightEdge[i].dx, rightEdge[i].dy)
        ..lineTo(rightEdge[i + 1].dx, rightEdge[i + 1].dy)
        ..lineTo(leftEdge[i + 1].dx, leftEdge[i + 1].dy)
        ..close();
      canvas.drawPath(band, Paint()..color = i.isEven ? AppPalette.roadSurface : AppPalette.roadStripe);
    }

    final dividerPaint = Paint()
      ..color = AppPalette.laneDivider
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    // One divider between every pair of adjacent lanes — the midpoint of
    // their normalized offsets, which works regardless of kLaneCount.
    final dividerOffsets = [
      for (int i = 0; i < kLaneCount - 1; i++) (i.laneOffset + (i + 1).laneOffset) / 2,
    ];
    for (final laneOffset in dividerOffsets) {
      final points = _samples.map((d) => pt(laneOffset, d)).toList();
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final o in points.skip(1)) {
        path.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(path, dividerPaint);
    }
  }

  /// BoxFit.cover-equivalent: the largest centered crop of [image] whose
  /// aspect ratio matches [dstSize], so the background fills the screen
  /// without stretching regardless of device aspect ratio.
  Rect _coverSrcRect(Image image, Vector2 dstSize) {
    final imgW = image.width.toDouble();
    final imgH = image.height.toDouble();
    final imgAspect = imgW / imgH;
    final dstAspect = dstSize.x / dstSize.y;
    double srcW, srcH;
    if (imgAspect > dstAspect) {
      srcH = imgH;
      srcW = imgH * dstAspect;
    } else {
      srcW = imgW;
      srcH = imgW / dstAspect;
    }
    return Rect.fromLTWH((imgW - srcW) / 2, (imgH - srcH) / 2, srcW, srcH);
  }
}
