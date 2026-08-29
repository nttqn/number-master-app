import 'package:flutter/material.dart';

import '../game/game_state.dart';
import '../game/number_master_game.dart';

/// Always-on HUD (player number, level/wall-progress label, pause button)
/// — a plain Flutter widget stacked over the GameWidget rather than a
/// Flame overlay, since it needs to stay visible during normal play
/// instead of being a blocking full-screen state.
class HudOverlay extends StatelessWidget {
  const HudOverlay({super.key, required this.game});

  final NumberMasterGame game;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconButton(
              icon: const Icon(Icons.pause_circle_filled, color: Colors.white, size: 32),
              onPressed: game.pauseForBackButton,
            ),
            Expanded(
              child: Column(
                children: [
                  ValueListenableBuilder<int>(
                    valueListenable: game.numberNotifier,
                    builder: (context, number, _) => Text(
                      '$number',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                      ),
                    ),
                  ),
                  ValueListenableBuilder<GameState>(
                    valueListenable: game.stateNotifier,
                    builder: (context, state, _) => ValueListenableBuilder<int>(
                      valueListenable: game.wallsRemainingNotifier,
                      builder: (context, walls, __) => Text(
                        state == GameState.wallSequence
                            ? 'Break through! $walls wall${walls == 1 ? '' : 's'} left'
                            : 'Level ${game.level}',
                        style: TextStyle(
                          color: state == GameState.wallSequence ? Colors.amberAccent : Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 40),
          ],
        ),
      ),
    );
  }
}
