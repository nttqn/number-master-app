import 'package:flutter/material.dart';

import '../game/number_master_game.dart';

class GameOverOverlay extends StatelessWidget {
  const GameOverOverlay({super.key, required this.game});

  final NumberMasterGame game;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black87,
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
