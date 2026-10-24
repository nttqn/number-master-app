import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../../models/lane.dart';
import '../../theme/palette.dart';
import '../number_master_game.dart';
import '../spawner/spawn_row.dart';
import 'gate_component.dart';
import 'hazard_component.dart';

/// A gate that switches between [options] every [interval] seconds. It
/// applies whichever option is showing when it reaches the player, so a
/// good result takes timing. Pips above the panel show how many options
/// there are and which one is up; a bar under the top beam counts down to
/// the next switch.
class CyclingGateComponent extends GateComponent {
  CyclingGateComponent({
    required this.options,
    required super.lane,
    required super.spawnDistance,
  }) : _time = lane * 0.23, // neighbors out of step with each other
       super(op: options.first.op, value: options.first.value);

  final List<GateContent> options;
  static const double interval = 0.7;
  double _time;

  int get _index => (_time / interval).floor() % options.length;

  @override
  void update(double dt) {
    _time += dt;
    // Set before super.update, which may resolve this frame.
    if (!resolved) {
      final o = options[_index];
      op = o.op;
      value = o.value;
    }
    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (size.x < 10) return;
    final panel = panelRect;
    final r = size.x * 0.06;
    final gap = r * 2.8;
    final y = panel.top - size.x * 0.22;
    final startX = panel.center.dx - gap * (options.length - 1) / 2;
    for (int i = 0; i < options.length; i++) {
      final c = Offset(startX + i * gap, y);
      final o = options[i];
      final color = o.op.isBeneficialColor ? AppPalette.friendlyNumber : AppPalette.enemyNumber;
      canvas.drawCircle(c, i == _index ? r * 1.35 : r, Paint()..color = i == _index ? color : color.withValues(alpha: 0.35));
      if (i == _index) {
        canvas.drawCircle(
          c,
          r * 1.35,
          Paint()
            ..color = const Color(0xFFFFFFFF)
            ..style = PaintingStyle.stroke
            ..strokeWidth = max(1.0, r * 0.4),
        );
      }
    }
    // Countdown to the next switch.
    final left = 1 - (_time % interval) / interval;
    canvas.drawRect(
      Rect.fromLTWH(panel.left, panel.top + size.x * 0.03, panel.width * left, max(1.5, size.x * 0.05)),
      Paint()..color = const Color(0xCCFFFFFF),
    );
  }
}

/// A saw sliding back and forth across lanes [fromLane]..[toLane] on a rail
/// (eased, so it lingers at the ends). Kills only the lane it's over at the
/// instant the row reaches the player.
class SweepSawComponent extends HazardComponent {
  SweepSawComponent({
    required this.fromLane,
    required this.toLane,
    required this.period,
    required super.spawnDistance,
  }) : super(lane: fromLane);

  final int fromLane;
  final int toLane;
  final double period;
  double _t = 0;

  /// Fractional lane index the saw is over right now.
  double get lanePosition => fromLane + (toLane - fromLane) * (0.5 - 0.5 * cos(2 * pi * _t / period));

  @override
  double get laneOffsetNow => (lanePosition - kOuterLaneOffset) / kOuterLaneOffset;

  @override
  bool hits(int playerLane) => (playerLane - lanePosition).abs() < 0.55;

  @override
  void update(double dt) {
    _t += dt;
    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    if (size.x >= 4) {
      // Rail across the span, at the saw's base — telegraphs its range.
      final p = game.projection;
      final y = groundLocalY - size.x * 0.1;
      final x0 = p.screenXAt(fromLane.laneOffset, depth) - position.x + size.x / 2;
      final x1 = p.screenXAt(toLane.laneOffset, depth) - position.x + size.x / 2;
      final rail = Paint()
        ..color = const Color(0xFF4B5563)
        ..strokeWidth = max(2.0, size.x * 0.1)
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(x0, y), Offset(x1, y), rail);
      final stripes = Paint()
        ..color = const Color(0xFFFFC233)
        ..strokeWidth = max(1.0, size.x * 0.04);
      canvas.drawLine(Offset(x0, y), Offset(x1, y), stripes);
    }
    super.render(canvas);
  }
}

/// A gap in the bridge over one lane, [HoleContent.length] long and
/// centered on its row's distance. Fatal for as long as it's passing under
/// the player and the player's lane is this one — including sliding across
/// it mid lane-change. Drawn on the road surface (just above the road
/// layer): sky showing through, with the bridge's cut face at the far end.
class HoleComponent extends PositionComponent with HasGameReference<NumberMasterGame> {
  HoleComponent({required this.lane, required double spawnDistance})
    : depth = spawnDistance,
      super(priority: Layers.road + 1);

  final int lane;

  /// Distance from the player to the hole's center.
  double depth;
  bool _killed = false;

  static const double _halfLength = HoleContent.length / 2;

  /// Just inside the lane dividers (lanes are 2/(kLaneCount-1) apart in
  /// normalized offset).
  static double get _halfWidth => 0.92 / (kLaneCount - 1);

  @override
  void update(double dt) {
    super.update(dt);
    depth -= game.trackSpeed * dt;
    final near = depth - _halfLength;
    final far = depth + _halfLength;
    if (!_killed && near <= 0 && far >= 0 && game.player.currentLane == lane) {
      _killed = true;
      game.fallIntoHole();
    }
    if (far < -4) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final p = game.projection;
    final near = max(depth - _halfLength, -4.0);
    final far = depth + _halfLength;
    if (far <= near) return;

    Offset pt(double laneOffset, double d) {
      final s = p.roadScaleAt(d);
      return Offset(p.screenCenterX + laneOffset * p.maxLaneOffsetPx * s, p.horizonY + (p.groundY - p.horizonY) * s);
    }

    final c = lane.laneOffset;
    final nl = pt(c - _halfWidth, near), nr = pt(c + _halfWidth, near);
    final fl = pt(c - _halfWidth, far), fr = pt(c + _halfWidth, far);
    final hole = Path()
      ..moveTo(nl.dx, nl.dy)
      ..lineTo(nr.dx, nr.dy)
      ..lineTo(fr.dx, fr.dy)
      ..lineTo(fl.dx, fl.dy)
      ..close();
    canvas.drawPath(
      hole,
      Paint()..shader = Gradient.linear(Offset(0, fl.dy), Offset(0, nl.dy), const [Color(0xFF7FC3F0), Color(0xFFCDEBFB)]),
    );
    // The bridge's cut face at the far edge, facing the camera.
    canvas.save();
    canvas.clipPath(hole);
    final t = 26 * p.roadScaleAt(far);
    canvas.drawPath(
      Path()
        ..moveTo(fl.dx, fl.dy)
        ..lineTo(fr.dx, fr.dy)
        ..lineTo(fr.dx, fr.dy + t)
        ..lineTo(fl.dx, fl.dy + t)
        ..close(),
      Paint()..color = AppPalette.roadUnderside,
    );
    canvas.restore();
    // Hazard-striped rim so it reads as "danger", not a road marking.
    final rim = Paint()
      ..color = AppPalette.curbRed
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.5, 4 * p.roadScaleAt(depth));
    canvas.drawPath(hole, rim);
  }
}
