// Store-screenshot entry point — stages one scene per URL query, for
// tool/store_shots.js to capture. Not part of the shipped app.
//
//   flutter build web --release -t lib/shots.dart -o build/shots
//
// Query parameters:
//   s        menu | shop | play            (default play)
//   level    level to play                 (default 1)
//   seed     level seed                    (default = level)
//   skip     seconds of play to fast-forward before the shot
//   start    starting-number bonus (big = clears every wall)
//   skin     PlayerSkin name, trail = PlayerTrail name
//   coins, unlocked  shown balance / highest unlocked level
//   number   force the player's number after skipping (HUD flavor)
//   focus    sweep | cycling | hole: after skipping, keep going until one
//            is a couple of rows ahead
import 'dart:async';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'game/components/gate_component.dart';
import 'game/components/hazard_component.dart';
import 'game/components/loose_number_component.dart';
import 'game/components/moving_obstacles.dart';
import 'game/components/track_entity.dart';
import 'game/cosmetics.dart';
import 'game/number_master_game.dart';
import 'models/lane.dart';
import 'screens/game_screen.dart';
import 'screens/shop_screen.dart';
import 'services/ads_service.dart';
import 'services/save_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final q = Uri.base.queryParameters;
  int intParam(String k, int fallback) => int.tryParse(q[k] ?? '') ?? fallback;

  final save = SaveService.instance;
  await save.loadEconomy();
  save.coinsNotifier.value = intParam('coins', 12840);
  save.unlockedLevelNotifier.value = intParam('unlocked', 14);
  final skin = PlayerSkin.byName(q['skin']);
  final trail = PlayerTrail.byName(q['trail']);
  save.ownedSkinsNotifier.value = {PlayerSkin.cube, PlayerSkin.ball, PlayerSkin.candy, skin};
  save.selectedSkinNotifier.value = skin;
  save.ownedTrailsNotifier.value = {PlayerTrail.none, PlayerTrail.sparkle, trail};
  save.selectedTrailNotifier.value = trail;
  // The x2 offer only shows when an ad is loaded — never on web.
  AdsService.instance.rewardedReady.value = true;

  final scene = q['s'] ?? 'play';
  if (scene == 'menu') {
    runApp(const NumberMasterApp());
    _ready();
    return;
  }
  final theme = ThemeData(colorSchemeSeed: const Color(0xFF3B82F6), useMaterial3: true, brightness: Brightness.dark);
  if (scene == 'shop') {
    runApp(MaterialApp(debugShowCheckedModeBanner: false, theme: theme, home: const ShopScreen()));
    _ready();
    return;
  }

  final level = intParam('level', 1);
  // GameScreen reads the start bonus from the save's upgrade level.
  save.startNumberLevelNotifier.value = intParam('start', 0);
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: GameScreen(
        startLevel: level,
        onGameCreated: (game) => unawaited(_stage(game, q)),
      ),
    ),
  );
}

Future<void> _stage(NumberMasterGame game, Map<String, String> q) async {
  game.invincible = true;
  await game.loaded;
  await Future<void>.delayed(const Duration(milliseconds: 400));
  await game.add(_Autopilot());
  final skip = double.tryParse(q['skip'] ?? '') ?? 0;
  if (skip <= 0) {
    _ready(); // leave the level-intro banner up
    return;
  }
  game.beginRunning();
  // Real frames would advance it too, at wall-clock speed; only the
  // fast-forward below should move it until the shot is staged.
  game.pauseEngine();
  // FlameGame.update on the root runs the whole tree (lifecycle + every
  // child), like the real game loop does each frame. Yield to microtasks
  // between frames: Flame processes adds/removals in order and waits on
  // any component whose onLoad is async (FloatingText, WallBreakEffect) —
  // in a tight synchronous loop those futures never complete, so every
  // later add and removal stalls (rows stop spawning, passed rows never
  // despawn). A microtask is enough and far faster than a timer.
  for (int i = 0; i < (skip * 60).round(); i++) {
    game.update(1 / 60);
    await Future<void>.microtask(() {});
  }
  // Keep going until the requested obstacle is a few rows ahead, nicely
  // in frame (up to 40 more seconds).
  final focus = q['focus'];
  if (focus != null) {
    // A little farther than ideal: the real game keeps running for the
    // ~0.4s between staging and the shutter (~5 world units).
    bool inFrame(double depth) => depth > 13 && depth < 16;
    bool found() => switch (focus) {
      'sweep' => game.children.whereType<SweepSawComponent>().any((e) => inFrame(e.depth)),
      'cycling' => game.children.whereType<CyclingGateComponent>().any((e) => inFrame(e.depth)),
      'hole' => game.children.whereType<HoleComponent>().any((e) => inFrame(e.depth)),
      _ => true,
    };
    for (int i = 0; i < 40 * 60 && !found(); i++) {
      game.update(1 / 60);
      await Future<void>.microtask(() {});
    }
  }
  final number = int.tryParse(q['number'] ?? '');
  if (number != null) {
    game.player.number = number;
    game.numberNotifier.value = number;
  }
  // Overlays (level complete) pause the engine themselves; otherwise let
  // effects animate for the settle time before the shutter.
  if (game.overlays.activeOverlays.isEmpty) game.resumeEngine();
  _ready();
}

/// tool/store_shots.js waits for this console line before the shutter.
void _ready() {
  // ignore: avoid_print
  print('SHOT_READY');
}

/// Steers toward the best lane of the next row, like a decent player:
/// avoids saws (including where a sliding saw will be), holes and bigger
/// loose numbers, prefers the gate or number that grows the most.
class _Autopilot extends Component with HasGameReference<NumberMasterGame> {
  TrackEntity? _decidedFor;

  @override
  void update(double dt) {
    super.update(dt);
    final entities = game.children.whereType<TrackEntity>().where((e) => !e.resolved && e.depth > 2.2).toList();
    if (entities.isEmpty) return;
    entities.sort((a, b) => a.depth.compareTo(b.depth));
    final nearest = entities.first;
    // Decide once per row, when it comes within reach.
    if (nearest.depth > 9 || identical(nearest, _decidedFor)) return;
    _decidedFor = nearest;
    final row = entities.where((e) => (e.depth - nearest.depth).abs() < 1).toList();
    final n = game.player.number;
    final scores = List<double>.filled(kLaneCount, n.toDouble());
    for (final e in row) {
      switch (e) {
        case SweepSawComponent():
          // Stay out of a sliding saw's span when there's any other way.
          for (int l = e.fromLane; l <= e.toLane; l++) {
            scores[l] -= 1e9;
          }
        case HazardComponent():
          scores[e.lane] = -1e12;
        case GateComponent():
          scores[e.lane] = e.op.apply(n, e.value).toDouble() + (e is CyclingGateComponent ? 0 : 0.5);
        case LooseNumberComponent():
          scores[e.lane] = e.value < n ? (n + e.value).toDouble() : -1e12;
      }
    }
    for (final hole in game.children.whereType<HoleComponent>()) {
      if ((hole.depth - nearest.depth).abs() < 6) scores[hole.lane] = -1e12;
    }
    int best = game.player.currentLane;
    for (int l = 0; l < kLaneCount; l++) {
      if (scores[l] > scores[best]) best = l;
    }
    game.player.currentLane = best;
    game.player.snapToNearestLane();
  }
}
