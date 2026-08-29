import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../game/number_master_game.dart';
import '../services/ads_service.dart';
import '../services/save_service.dart';
import '../widgets/game_over_overlay.dart';
import '../widgets/hud_overlay.dart';
import '../widgets/level_banner_overlay.dart';
import '../widgets/level_complete_overlay.dart';
import '../widgets/pause_overlay.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.startLevel});

  final int startLevel;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late int _level;
  int _attempt = 0;
  late NumberMasterGame _game;
  BannerAd? _bannerAd;
  bool _bannerLoaded = false;

  @override
  void initState() {
    super.initState();
    _level = widget.startLevel;
    _game = _buildGame();
    _bannerAd = AdsService.instance.createBannerAd(onLoaded: () {
      if (mounted) setState(() => _bannerLoaded = true);
    });
  }

  NumberMasterGame _buildGame() {
    return NumberMasterGame(
      level: _level,
      onGameOver: (level, finalNumber) {
        unawaited(SaveService.instance.recordBestNumber(level, finalNumber));
        AdsService.instance.maybeShowInterstitial();
      },
      onLevelComplete: (level, leftover) {
        unawaited(SaveService.instance.recordBestNumber(level, leftover));
        unawaited(SaveService.instance.unlockLevel(level + 1));
        AdsService.instance.maybeShowInterstitial();
      },
      onRequestRetry: _retry,
      onRequestNextLevel: _nextLevel,
      onRequestQuit: () => Navigator.of(context).pop(),
    );
  }

  void _retry() {
    setState(() {
      _attempt++;
      _game = _buildGame();
    });
  }

  void _nextLevel() {
    setState(() {
      _level++;
      _attempt = 0;
      _game = _buildGame();
    });
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _game.pauseForBackButton();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Column(
          children: [
            Expanded(
              child: Stack(
                key: ValueKey('screen-$_level-$_attempt'),
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragEnd: (details) {
                      final v = details.primaryVelocity ?? 0;
                      if (v > 200) {
                        _game.movePlayerLane(1);
                      } else if (v < -200) {
                        _game.movePlayerLane(-1);
                      }
                    },
                    child: GameWidget(
                      key: ValueKey('game-$_level-$_attempt'),
                      game: _game,
                      overlayBuilderMap: {
                        'levelIntro': (context, game) => LevelBannerOverlay(
                          level: (game as NumberMasterGame).level,
                          onDone: game.beginRunning,
                        ),
                        'pause': (context, game) => PauseOverlay(game: game as NumberMasterGame),
                        'gameOver': (context, game) => GameOverOverlay(game: game as NumberMasterGame),
                        'levelComplete': (context, game) => LevelCompleteOverlay(game: game as NumberMasterGame),
                      },
                    ),
                  ),
                  HudOverlay(game: _game),
                ],
              ),
            ),
            if (_bannerAd != null && _bannerLoaded)
              SizedBox(
                width: _bannerAd!.size.width.toDouble(),
                height: _bannerAd!.size.height.toDouble(),
                child: AdWidget(ad: _bannerAd!),
              ),
          ],
        ),
      ),
    );
  }
}
