import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';

import '../models/gate_operation.dart';
import '../models/lane.dart';
import '../services/sound_service.dart';
import 'components/player_component.dart';
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
    required this.onGameOver,
    required this.onLevelComplete,
    required this.onRequestRetry,
    required this.onRequestNextLevel,
    required this.onRequestQuit,
  });

  final int level;
  final int? seed;
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
    player.number = 1;
    player.currentLane = 1;
    numberNotifier.value = 1;
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

  void movePlayerLane(int delta) {
    if (stateNotifier.value != GameState.running && stateNotifier.value != GameState.wallSequence) return;
    final target = (player.currentLane + delta).clamp(0, kLaneCount - 1);
    if (target != player.currentLane) {
      player.moveToLane(target);
      SoundService.instance.play(SfxEvent.swipe);
    }
  }

  void applyGate(GateOperation op, int value) {
    player.number = op.apply(player.number, value);
    numberNotifier.value = player.number;
    player.pulse();
    SoundService.instance.play(op.isBeneficialColor ? SfxEvent.gateGood : SfxEvent.gateBad);
  }

  void absorbNumber(int value) {
    player.number += value;
    numberNotifier.value = player.number;
    player.pulse();
    SoundService.instance.play(SfxEvent.absorb);
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
      SoundService.instance.play(SfxEvent.wallBreak);
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
    SoundService.instance.play(SfxEvent.death);
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
