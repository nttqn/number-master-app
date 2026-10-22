import 'dart:math';
import 'dart:ui';

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';

import '../models/gate_operation.dart';
import '../models/lane.dart';
import '../services/sound_service.dart';
import '../theme/palette.dart';
import 'components/floating_text.dart';
import 'components/player_component.dart';
import 'components/trail_component.dart';
import 'components/wall_break_effect.dart';
import 'components/wall_component.dart';
import 'game_state.dart';
import 'level_runtime.dart';
import 'projection.dart';
import 'spawner/level_generator.dart';
import 'spawner/spawn_row.dart';
import 'world/road_component.dart';

/// Draw-order layers. Track entities sort themselves by distance inside
/// the band between road and player (see TrackEntity/FullWidthBlock), so
/// nearer things are always drawn over farther ones.
class Layers {
  Layers._();
  static const int road = -1000000;
  static const int player = 1000;
  static const int effects = 2000;

  static int forDepth(double depth) => -depth.round();
}

/// One level attempt. A fresh instance is created per attempt (retry or
/// next-level) by GameScreen rather than mutated in place — simpler than
/// resetting internal state, and cheap since Flame components are
/// lightweight.
class NumberMasterGame extends FlameGame {
  NumberMasterGame({
    required this.level,
    this.seed,
    this.startNumberBonus = 0,
    required this.onGameOver,
    required this.onLevelComplete,
    required this.onRequestRetry,
    required this.onRequestNextLevel,
    required this.onRequestQuit,
  });

  final int level;
  final int? seed;

  /// From the shop's "Start Number" upgrade — added to the player's
  /// starting number (normally 1) at the beginning of every run. Purely a
  /// head start: the level generator's own fairness/feasibility math
  /// always assumes a start of 1, which stays a valid (conservative) lower
  /// bound regardless of this bonus — a higher start can only make a level
  /// easier, never invalidate the guarantee that it's beatable.
  final int startNumberBonus;
  final void Function(int level, int finalNumber) onGameOver;

  /// [bonusNumber] is the number carried out of the wall sequence (what
  /// coins are based on), [multiplier] the highest bonus step reached.
  final void Function(int level, int bonusNumber, int multiplier) onLevelComplete;
  final VoidCallback onRequestRetry;
  final VoidCallback onRequestNextLevel;
  final VoidCallback onRequestQuit;

  late Projection projection;
  late PlayerComponent player;
  GeneratedLevel? generatedLevel;
  LevelRuntime? runtime;

  /// Current world scroll speed (distance units/sec). FlameGame already
  /// owns a `world` property (its root component container), so this is
  /// deliberately a plain field rather than a nested "TrackWorld" object.
  double trackSpeed = 6.0;

  /// Total world distance scrolled so far — drives the road's scrolling
  /// stripes/posts.
  double scrolled = 0;

  final ValueNotifier<GameState> stateNotifier = ValueNotifier(GameState.levelIntro);
  final ValueNotifier<int> numberNotifier = ValueNotifier(1);
  final ValueNotifier<int> wallsRemainingNotifier = ValueNotifier(0);
  final ValueNotifier<int> multiplierNotifier = ValueNotifier(1);

  /// The number the player walked out of the wall sequence with — coins
  /// are paid on this times the bonus multiplier, even though climbing the
  /// staircase spends the number itself down.
  int bonusNumber = 0;

  GameState? _pausedFrom;
  double _completeCountdown = -1;

  final Random _rnd = Random();
  double _shakeTime = 0;
  double _shakeMagnitude = 0;
  Offset _shakeOffset = Offset.zero;

  @override
  Future<void> onLoad() async {
    projection = Projection(screenWidth: size.x, screenHeight: size.y);
    await add(RoadComponent()..priority = Layers.road);
    player = PlayerComponent()..priority = Layers.player;
    await add(player);
    await add(TrailComponent()..priority = Layers.player - 1);
    _startLevel();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    projection = Projection(screenWidth: size.x, screenHeight: size.y);
  }

  void _startLevel() {
    generatedLevel = LevelGenerator.generate(level, seed: seed);
    trackSpeed = generatedLevel!.trackSpeed;
    runtime = LevelRuntime(this, generatedLevel!);
    player.number = 1 + startNumberBonus;
    player.currentLane = (kLaneCount - 1) ~/ 2;
    numberNotifier.value = player.number;
    wallsRemainingNotifier.value = generatedLevel!.walls.length;
    stateNotifier.value = GameState.levelIntro;
    overlays.add('levelIntro');
    pauseEngine();
  }

  void beginRunning() {
    overlays.remove('levelIntro');
    stateNotifier.value = GameState.running;
    resumeEngine();
  }

  bool get _isMoving {
    final s = stateNotifier.value;
    return s == GameState.running || s == GameState.wallSequence || s == GameState.bonusStairs;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_isMoving) {
      scrolled += trackSpeed * dt;
      runtime?.update(dt);
    }
    if (_completeCountdown >= 0) {
      _completeCountdown -= dt;
      if (_completeCountdown < 0) _completeLevel();
    }
    if (_shakeTime > 0) {
      _shakeTime -= dt;
      final m = _shakeMagnitude * (_shakeTime.clamp(0.0, 0.3) / 0.3);
      _shakeOffset = Offset((_rnd.nextDouble() * 2 - 1) * m, (_rnd.nextDouble() * 2 - 1) * m);
    } else {
      _shakeOffset = Offset.zero;
    }
  }

  @override
  void render(Canvas canvas) {
    if (_shakeOffset == Offset.zero) {
      super.render(canvas);
      return;
    }
    canvas.save();
    canvas.translate(_shakeOffset.dx, _shakeOffset.dy);
    super.render(canvas);
    canvas.restore();
  }

  void shake(double magnitude) {
    _shakeMagnitude = _shakeTime > 0 ? max(_shakeMagnitude, magnitude) : magnitude;
    _shakeTime = 0.3;
  }

  bool get _canSteer => stateNotifier.value == GameState.running || stateNotifier.value == GameState.wallSequence;

  /// Called continuously while a drag is in progress — the player follows
  /// the finger 1:1 rather than jumping lanes once some threshold is
  /// crossed.
  void handleDragUpdate(double deltaX) {
    if (!_canSteer) return;
    player.followDrag(deltaX);
  }

  /// Called when the finger lifts — eases into the nearest lane's center.
  void handleDragEnd() {
    if (!_canSteer) return;
    player.snapToNearestLane();
  }

  Vector2 get _aboveHead => player.position - Vector2(0, player.size.y * 0.9);

  void _popText(String text, Color color, {double fontSize = 30}) {
    add(FloatingText(text: text, color: color, position: _aboveHead, fontSize: fontSize)..priority = Layers.effects);
  }

  void _burst(Vector2 at, double scale, Color color) {
    add(WallBreakEffect(position: at, scale: scale, color: color)..priority = Layers.effects);
  }

  void applyGate(GateOperation op, int value, {required Vector2 at, required Color color}) {
    player.number = op.apply(player.number, value);
    numberNotifier.value = player.number;
    player.pulse();
    _burst(at, 0.6, color);
    _popText(op.label(value), color);
    if (!op.isBeneficialColor) shake(4);
    SoundService.instance.play(op.isBeneficialColor ? SfxEvent.scoreUp : SfxEvent.scoreDown);
  }

  void absorbNumber(int value, {required Vector2 at}) {
    player.number += value;
    numberNotifier.value = player.number;
    player.pulse();
    _burst(at, 0.45, AppPalette.friendlyNumber);
    _popText('+$value', AppPalette.friendlyNumber);
    SoundService.instance.play(SfxEvent.scoreUp);
  }

  void enterWallSequence() {
    stateNotifier.value = GameState.wallSequence;
  }

  void resolveWall(WallComponent wall) {
    if (player.number >= wall.value) {
      player.number -= wall.value;
      numberNotifier.value = player.number;
      wallsRemainingNotifier.value = wallsRemainingNotifier.value - 1;
      player.pulse();
      SoundService.instance.play(SfxEvent.wallHit);
      // Dividing by the un-scaled height recovers the perspective scale at
      // the instant it broke, so the shard burst is sized to match how
      // big/close the wall looked.
      _burst(wall.absoluteCenter, wall.size.y / wall.baseHeight, AppPalette.wallFill);
      _popText('-${wall.value}', AppPalette.wallFill);
      shake(9);
      wall.removeFromParent();
      if (wallsRemainingNotifier.value <= 0) {
        _enterBonusStairs();
      }
    } else {
      triggerGameOver();
    }
  }

  void _enterBonusStairs() {
    bonusNumber = player.number;
    multiplierNotifier.value = 1;
    stateNotifier.value = GameState.bonusStairs;
    // Center the player so the staircase reads as climbed head-on.
    player.currentLane = (kLaneCount - 1) ~/ 2;
    player.snapToNearestLane();
  }

  void resolveStairStep(StairStepComponent step) {
    if (stateNotifier.value != GameState.bonusStairs) return;
    if (player.number >= step.cost) {
      player.number -= step.cost;
      numberNotifier.value = player.number;
      multiplierNotifier.value = step.multiplier;
      player.pulse();
      SoundService.instance.play(SfxEvent.wallHit);
      _burst(step.absoluteCenter, step.size.y / step.baseHeight, step.color);
      _popText('x${step.multiplier}', step.color, fontSize: 30 + step.multiplier * 2.0);
      shake(4 + step.multiplier * 0.8);
      step.removeFromParent();
      if (step.multiplier >= LevelRuntime.maxMultiplier) _finishBonus();
    } else {
      // Out of number: stop dead in front of this step.
      shake(6);
      _finishBonus();
    }
  }

  void _finishBonus() {
    trackSpeed = 0;
    stateNotifier.value = GameState.bonusDone;
    _completeCountdown = 0.9;
  }

  void _completeLevel() {
    if (stateNotifier.value == GameState.levelComplete) return;
    stateNotifier.value = GameState.levelComplete;
    overlays.add('levelComplete');
    pauseEngine();
    SoundService.instance.play(SfxEvent.levelComplete);
    onLevelComplete(level, bonusNumber, multiplierNotifier.value);
  }

  void triggerGameOver() {
    if (stateNotifier.value == GameState.gameOver) return;
    stateNotifier.value = GameState.gameOver;
    overlays.add('gameOver');
    pauseEngine();
    SoundService.instance.play(SfxEvent.gameOver);
    onGameOver(level, player.number);
  }

  void pauseForBackButton() {
    final s = stateNotifier.value;
    if (s == GameState.running || s == GameState.wallSequence || s == GameState.bonusStairs) {
      _pausedFrom = s;
      stateNotifier.value = GameState.paused;
      overlays.add('pause');
      pauseEngine();
    }
  }

  void resumeFromPause() {
    if (stateNotifier.value == GameState.paused) {
      overlays.remove('pause');
      stateNotifier.value = _pausedFrom ?? GameState.running;
      resumeEngine();
    }
  }
}
