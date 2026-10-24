import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../../models/lane.dart';
import '../../theme/palette.dart';
import '../number_master_game.dart';

/// Draws the converging kLaneCount-lane road as a floating bridge over the
/// sky background: a thick underside, red/white curbs, alternating surface
/// stripes, dashed lane dividers and flag posts along both edges.
///
/// Everything that repeats along the road (stripes, curb blocks, dashes,
/// posts) is laid out in *world* distance and offset by
/// [NumberMasterGame.scrolled], so it scrolls toward the player at exactly
/// the speed entities approach — without that the road surface was static
/// and the game had almost no sense of speed.
class RoadComponent extends PositionComponent with HasGameReference<NumberMasterGame> {
  static const double _stripeLength = 3.5;
  static const double _farDistance = 320;

  /// Past the player (negative distance) so the road runs off the bottom
  /// of the screen instead of ending at the player's feet.
  static const double _nearDistance = -4.0;
  static const double _roadHalfWidth = 1.6;
  static const double _curbWidth = 0.14;
  static const double _postSpacing = 14.0;
  static const double _postMaxDistance = 160;

  static const List<Color> _flagColors = [
    Color(0xFFFF4D6D),
    Color(0xFFFFC233),
    Color(0xFF2ED47A),
    Color(0xFF3D8BFF),
    Color(0xFFB55CFF),
  ];

  Image? _backgroundImage;
  double _time = 0;

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
  void update(double dt) {
    super.update(dt);
    _time += dt;
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
    final scrolled = game.scrolled;

    Offset pt(double laneOffset, double d) {
      final s = p.roadScaleAt(d);
      return Offset(p.screenCenterX + laneOffset * p.maxLaneOffsetPx * s, p.horizonY + (p.groundY - p.horizonY) * s);
    }

    void quad(double offA, double offB, double d0, double d1, Paint paint) {
      final a0 = pt(offA, d0), b0 = pt(offB, d0), b1 = pt(offB, d1), a1 = pt(offA, d1);
      final path = Path()
        ..moveTo(a0.dx, a0.dy)
        ..lineTo(b0.dx, b0.dy)
        ..lineTo(b1.dx, b1.dy)
        ..lineTo(a1.dx, a1.dy)
        ..close();
      canvas.drawPath(path, paint);
    }

    const outer = _roadHalfWidth + _curbWidth;

    // Underside: the road's outline shifted down by a thickness that
    // scales with perspective. Perspective keeps the edges straight lines,
    // so the far and near ends are enough.
    Offset low(double laneOffset, double d) => pt(laneOffset, d) + Offset(0, 26 * p.roadScaleAt(d) * p.unit);
    final underside = Path()
      ..moveTo(low(-outer, _farDistance).dx, low(-outer, _farDistance).dy)
      ..lineTo(low(-outer, _nearDistance).dx, low(-outer, _nearDistance).dy)
      ..lineTo(low(outer, _nearDistance).dx, low(outer, _nearDistance).dy)
      ..lineTo(low(outer, _farDistance).dx, low(outer, _farDistance).dy)
      ..close();
    canvas.drawPath(underside, Paint()..color = AppPalette.roadUnderside);

    // Scrolling bands. Band boundaries sit at multiples of _stripeLength
    // in world space, so `(b + scrolled) / _stripeLength` is an integer
    // that identifies the same band across frames.
    final surfaceA = Paint()..color = AppPalette.roadSurface;
    final surfaceB = Paint()..color = AppPalette.roadStripe;
    final curbRed = Paint()..color = AppPalette.curbRed;
    final curbWhite = Paint()..color = const Color(0xFFFFFFFF);
    final dashPaint = Paint()..color = AppPalette.laneDivider;
    final dividerOffsets = [
      for (int i = 0; i < kLaneCount - 1; i++) (i.laneOffset + (i + 1).laneOffset) / 2,
    ];

    final phase = scrolled % _stripeLength;
    for (double b = _nearDistance - phase; b < _farDistance; b += _stripeLength) {
      final d0 = max(b, _nearDistance);
      final d1 = min(b + _stripeLength, _farDistance);
      if (d1 <= d0) continue;
      final even = ((b + scrolled) / _stripeLength).round().isEven;
      quad(-_roadHalfWidth, _roadHalfWidth, d0, d1, even ? surfaceA : surfaceB);
      quad(-outer, -_roadHalfWidth, d0, d1, even ? curbRed : curbWhite);
      quad(_roadHalfWidth, outer, d0, d1, even ? curbRed : curbWhite);
      if (even) {
        // Dashes as thin quads (not strokes) so they shrink with
        // perspective like everything else.
        for (final o in dividerOffsets) {
          quad(o - 0.022, o + 0.022, d0, d1, dashPaint);
        }
      }
    }

    _renderPosts(canvas, pt, scrolled);
  }

  void _renderPosts(Canvas canvas, Offset Function(double, double) pt, double scrolled) {
    final p = game.projection;
    final phase = scrolled % _postSpacing;
    final firstId = (scrolled / _postSpacing).floor();
    final posts = <(double, int)>[];
    for (int j = 0;; j++) {
      final d = j * _postSpacing - phase;
      if (d > _postMaxDistance) break;
      if (d < _nearDistance) continue;
      posts.add((d, firstId + j));
    }
    const postOffset = _roadHalfWidth + _curbWidth / 2;
    final polePaint = Paint()
      ..color = const Color(0xFF5B6B82)
      ..strokeCap = StrokeCap.round;
    final knobPaint = Paint()..color = const Color(0xFFFFD23F);
    for (final (d, id) in posts.reversed) {
      final s = p.roadScaleAt(d) * p.unit; // post sizes only; positions come from pt()
      final flagPaint = Paint()..color = _flagColors[id % _flagColors.length];
      for (final side in const [-1.0, 1.0]) {
        final base = pt(side * postOffset, d);
        final w = max(1.5, 5 * s);
        final top = Offset(base.dx, base.dy - 120 * s);
        canvas.drawLine(base, top, polePaint..strokeWidth = w);
        canvas.drawCircle(top, w * 1.1, knobPaint);
        // Pennant pointing outward, its tip waving.
        final wave = sin(_time * 7 + id) * 5 * s;
        final flag = Path()
          ..moveTo(top.dx, top.dy + w)
          ..lineTo(top.dx + 34 * s * side, top.dy + 9 * s + wave)
          ..lineTo(top.dx, top.dy + 20 * s)
          ..close();
        canvas.drawPath(flag, flagPaint);
      }
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
