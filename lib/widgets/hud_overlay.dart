import 'package:flutter/material.dart';

import '../game/game_state.dart';
import '../game/number_master_game.dart';
import '../screens/shop_screen.dart';
import '../services/save_service.dart';

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
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                ValueListenableBuilder<int>(
                  valueListenable: SaveService.instance.coinsNotifier,
                  builder: (context, coins, _) => Row(
                    children: [
                      const Icon(Icons.attach_money, color: Colors.amberAccent, size: 20),
                      Text(
                        '$coins',
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.storefront, color: Colors.white, size: 24),
                  onPressed: () {
                    game.pauseForBackButton();
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ShopScreen()));
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
