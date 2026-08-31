import 'package:flutter/material.dart';

import '../game/economy.dart';
import '../game/number_master_game.dart';
import '../services/save_service.dart';
import '../theme/palette.dart';

class GameOverOverlay extends StatelessWidget {
  const GameOverOverlay({super.key, required this.game});

  final NumberMasterGame game;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppPalette.overlayScrim,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'GAME OVER',
              style: TextStyle(color: Colors.redAccent, fontSize: 40, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Level ${game.level} · Final number: ${game.player.number}',
              style: const TextStyle(color: Colors.white70, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              '+${Economy.coinsForRun(game.player.number, SaveService.instance.incomeMultiplier)} coins',
              style: const TextStyle(color: Colors.amberAccent, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: game.onRequestRetry, child: const Text('Retry')),
            const SizedBox(height: 12),
            TextButton(
              onPressed: game.onRequestQuit,
              child: const Text('Quit to Menu', style: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
      ),
    );
  }
}
