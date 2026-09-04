import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';

import '../models/gate_operation.dart';
import '../models/lane.dart';
import '../services/sound_service.dart';
import '../theme/palette.dart';
import 'components/player_component.dart';
import 'components/wall_break_effect.dart';
import 'components/wall_component.dart';
import 'game_state.dart';
import 'level_runtime.dart';
import 'projection.dart';
import 'spawner/level_generator.dart';
import 'spawner/spawn_row.dart';
import 'world/road_component.dart';

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
  final void Function(int level, int leftoverNumber) onLevelComplete;
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

  final ValueNotifier<GameState> stateNotifier = ValueNotifier(GameState.levelIntro);
  final ValueNotifier<int> numberNotifier = ValueNotifier(1);
  final ValueNotifier<int> wallsRemainingNotifier = ValueNotifier(0);

  GameState? _pausedFrom;

  @override
  Future<void> onLoad() async {
    projection = Projection(screenWidth: size.x, screenHeight: size.y);
    await add(RoadComponent()..priority = -10);
    player = PlayerComponent()..priority = 5;
    await add(player);
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

  @override
  void update(double dt) {
    super.update(dt);
    final s = stateNotifier.value;
    if (s == GameState.running || s == GameState.wallSequence) {
      runtime?.update(dt);
    }
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

  void applyGate(GateOperation op, int value) {
    player.number = op.apply(player.number, value);
    numberNotifier.value = player.number;
    player.pulse();
    SoundService.instance.play(op.isBeneficialColor ? SfxEvent.scoreUp : SfxEvent.scoreDown);
  }

  void absorbNumber(int value) {
    player.number += value;
    numberNotifier.value = player.number;
    player.pulse();
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
      // The un-scaled wall is 150 tall (WallComponent.update); dividing by
      // that recovers the perspective scale at the instant it broke, so
      // the shard burst is sized to match how big/close the wall looked.
      add(
        WallBreakEffect(
          position: wall.position.clone(),
          scale: wall.size.y / 150.0,
          color: AppPalette.wallFill,
        ),
      );
      wall.removeFromParent();
      if (wallsRemainingNotifier.value <= 0) {
        _completeLevel();
      }
    } else {
      triggerGameOver();
    }
  }

  void _completeLevel() {
    if (stateNotifier.value == GameState.levelComplete) return;
    stateNotifier.value = GameState.levelComplete;
    overlays.add('levelComplete');
    pauseEngine();
    SoundService.instance.play(SfxEvent.levelComplete);
    onLevelComplete(level, player.number);
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
    if (s == GameState.running || s == GameState.wallSequence) {
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
