import 'dart:math';
import 'dart:ui';

import 'package:flutter/painting.dart' show TextPainter, TextSpan, TextStyle, FontWeight;

import '../theme/palette.dart';
import 'components/text_fit.dart';
import 'cosmetics.dart';

/// Body color by number size (2048-style tiers): roughly log2(number).
Color tierColor(int number) {
  final tier = (log(max(1, number)) / ln2).floor();
  return AppPalette.playerTiers[tier.clamp(0, AppPalette.playerTiers.length - 1)];
}

const _white = Color(0xFFFFFFFF);
const _black = Color(0xFF000000);

Color _lighten(Color c, double t) => Color.lerp(c, _white, t)!;
Color _darken(Color c, double t) => Color.lerp(c, _black, t)!;

/// Draws the player's body for [skin] in a box [w] wide whose ground
/// contact line is at [ground], lifted by [hop]. Shared by the in-game
/// [PlayerComponent] and the shop's previews, so a skin always looks the
/// same in both. The caller draws the contact shadow.
void paintPlayerSkin(Canvas canvas, {
  required double w,
  required double ground,
  required double hop,
  required PlayerSkin skin,
  required int number,
}) {
  // The candy-stripe and wood-grain loops step by a fraction of w — at
  // w == 0 (e.g. a shop preview laid out at zero size) they'd never end.
  if (w < 4) return;
  final body = tierColor(number);
  final bottom = ground - hop;
  switch (skin) {
    case PlayerSkin.cube:
      _paintBlock(canvas, w, bottom, '$number', front: body, top: _lighten(body, 0.4));
    case PlayerSkin.wood:
      _paintBlock(
        canvas,
        w,
        bottom,
        '$number',
        front: const Color(0xFFB9854F),
        top: const Color(0xFFDDB27C),
        grain: true,
      );
    case PlayerSkin.ball:
      _paintBall(canvas, w, bottom, '$number', body);
    case PlayerSkin.candy:
      _paintCandy(canvas, w, bottom, '$number', body);
    case PlayerSkin.slime:
      _paintSlime(canvas, w, bottom, '$number', body);
    case PlayerSkin.gem:
      _paintGem(canvas, w, bottom, '$number', body);
  }
}

void _paintNumber(Canvas canvas, String text, Offset center, double maxWidth, double desiredSize) {
  final fontSize = fitFontSize(textLength: text.length, desiredFontSize: desiredSize, maxWidth: maxWidth);
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
    text: TextSpan(text: text, style: style.copyWith(color: _white)),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();
  final offset = Offset(center.dx - fill.width / 2, center.dy - fill.height / 2);
  stroke.paint(canvas, offset);
  fill.paint(canvas, offset);
}

/// Cube-like block: front face + a top face narrowing away from the camera.
void _paintBlock(Canvas canvas, double w, double bottom, String text,
    {required Color front, required Color top, bool grain = false}) {
  final frontW = w * 0.86;
  final frontH = w * 0.6;
  final topH = w * 0.24;
  final left = (w - frontW) / 2;
  final rect = Rect.fromLTWH(left, bottom - frontH, frontW, frontH);

  final inset = w * 0.07;
  final topFace = Path()
    ..moveTo(rect.left, rect.top)
    ..lineTo(rect.left + inset, rect.top - topH)
    ..lineTo(rect.right - inset, rect.top - topH)
    ..lineTo(rect.right, rect.top)
    ..close();
  canvas.drawPath(topFace, Paint()..color = top);

  canvas.drawRRect(
    RRect.fromRectAndCorners(rect, bottomLeft: Radius.circular(w * 0.08), bottomRight: Radius.circular(w * 0.08)),
    Paint()..shader = Gradient.linear(rect.topCenter, rect.bottomCenter, [front, _darken(front, 0.25)]),
  );
  if (grain) {
    // A few wavy darker lines across the front, and rings on the top.
    final grainPaint = Paint()
      ..color = const Color(0x55603813)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.0, w * 0.018);
    for (int i = 1; i <= 3; i++) {
      final y = rect.top + rect.height * i / 4;
      final path = Path()..moveTo(rect.left, y);
      for (double x = 0; x <= frontW; x += frontW / 8) {
        path.lineTo(rect.left + x, y + sin(x / frontW * 2 * pi + i) * w * 0.02);
      }
      canvas.drawPath(path, grainPaint);
    }
    final topCenter = Offset(w / 2, rect.top - topH / 2);
    for (int i = 1; i <= 2; i++) {
      canvas.drawOval(Rect.fromCenter(center: topCenter, width: w * 0.22 * i, height: topH * 0.35 * i), grainPaint);
    }
  } else {
    canvas.drawRect(Rect.fromLTWH(rect.left, rect.top, frontW, frontH * 0.14), Paint()..color = const Color(0x33FFFFFF));
  }
  _paintNumber(canvas, text, rect.center, frontW * 0.88, w * 0.36);
}

void _paintBall(Canvas canvas, double w, double bottom, String text, Color body) {
  final r = w * 0.42;
  final c = Offset(w / 2, bottom - r);
  canvas.drawCircle(
    c,
    r,
    Paint()
      ..shader = Gradient.radial(c - Offset(r * 0.35, r * 0.4), r * 1.4, [_lighten(body, 0.45), body, _darken(body, 0.35)], [0, 0.45, 1]),
  );
  canvas.drawOval(
    Rect.fromCenter(center: c - Offset(r * 0.38, r * 0.5), width: r * 0.55, height: r * 0.3),
    Paint()..color = const Color(0x66FFFFFF),
  );
  _paintNumber(canvas, text, c, r * 1.6, w * 0.36);
}

void _paintCandy(Canvas canvas, double w, double bottom, String text, Color body) {
  final bw = w * 0.68;
  final bh = w * 0.56;
  final rect = Rect.fromLTWH((w - bw) / 2, bottom - bh, bw, bh);
  final wrap = _lighten(body, 0.35);
  // Twisted wrapper ends.
  for (final side in const [-1.0, 1.0]) {
    final x = side < 0 ? rect.left : rect.right;
    final tip = x + side * w * 0.2;
    final path = Path()
      ..moveTo(x, rect.center.dy)
      ..lineTo(tip, rect.top + bh * 0.05)
      ..lineTo(tip - side * w * 0.04, rect.center.dy)
      ..lineTo(tip, rect.bottom - bh * 0.05)
      ..close();
    canvas.drawPath(path, Paint()..color = wrap);
  }
  final rrect = RRect.fromRectAndRadius(rect, Radius.circular(bh * 0.45));
  canvas.drawRRect(rrect, Paint()..color = body);
  canvas.save();
  canvas.clipRRect(rrect);
  final stripe = Paint()
    ..color = const Color(0x59FFFFFF)
    ..strokeWidth = bw * 0.1;
  for (double x = -bh; x < bw + bh; x += bw * 0.24) {
    canvas.drawLine(Offset(rect.left + x, rect.bottom), Offset(rect.left + x + bh, rect.top), stripe);
  }
  canvas.restore();
  _paintNumber(canvas, text, rect.center, bw * 0.9, w * 0.34);
}

void _paintSlime(Canvas canvas, double w, double bottom, String text, Color body) {
  final sw = w * 0.9;
  final sh = w * 0.72;
  final left = (w - sw) / 2;
  final top = bottom - sh;
  final path = Path()
    ..moveTo(left, bottom)
    ..cubicTo(left - sw * 0.02, top + sh * 0.2, left + sw * 0.18, top, w / 2, top)
    ..cubicTo(left + sw * 0.82, top, left + sw * 1.02, top + sh * 0.2, left + sw, bottom)
    ..close();
  canvas.drawPath(
    path,
    Paint()..shader = Gradient.linear(Offset(w / 2, top), Offset(w / 2, bottom), [_lighten(body, 0.3), _darken(body, 0.15)]),
  );
  canvas.drawOval(
    Rect.fromLTWH(left + sw * 0.18, top + sh * 0.1, sw * 0.22, sh * 0.12),
    Paint()..color = const Color(0x66FFFFFF),
  );
  final eyeY = top + sh * 0.36;
  for (final dx in const [-0.17, 0.17]) {
    final eye = Offset(w / 2 + dx * sw, eyeY);
    canvas.drawCircle(eye, sw * 0.09, Paint()..color = _white);
    canvas.drawCircle(eye + Offset(0, sw * 0.02), sw * 0.05, Paint()..color = const Color(0xFF1F2937));
  }
  _paintNumber(canvas, text, Offset(w / 2, top + sh * 0.72), sw * 0.7, w * 0.28);
}

void _paintGem(Canvas canvas, double w, double bottom, String text, Color body) {
  final h = w * 0.8;
  final top = bottom - h;
  final crownY = top + h * 0.3;
  final pts = [
    Offset(w * 0.22, top),
    Offset(w * 0.78, top),
    Offset(w * 0.96, crownY),
    Offset(w / 2, bottom),
    Offset(w * 0.04, crownY),
  ];
  final outline = Path()..addPolygon(pts, true);
  canvas.drawPath(outline, Paint()..color = body);
  // Facets: light crown, two-tone pavilion.
  canvas.drawPath(
    Path()..addPolygon([pts[0], pts[1], pts[2], pts[4]], true),
    Paint()..color = _lighten(body, 0.35),
  );
  canvas.drawPath(
    Path()..addPolygon([pts[4], Offset(w / 2, crownY), pts[3]], true),
    Paint()..color = _lighten(body, 0.12),
  );
  canvas.drawPath(
    Path()..addPolygon([Offset(w / 2, crownY), pts[2], pts[3]], true),
    Paint()..color = _darken(body, 0.2),
  );
  final edge = Paint()
    ..color = const Color(0x99FFFFFF)
    ..style = PaintingStyle.stroke
    ..strokeWidth = max(1.0, w * 0.02);
  canvas.drawPath(outline, edge);
  canvas.drawLine(pts[4], pts[2], edge);
  _paintNumber(canvas, text, Offset(w / 2, crownY + h * 0.05), w * 0.6, w * 0.3);
}
