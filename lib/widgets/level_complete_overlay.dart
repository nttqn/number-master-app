import 'package:flutter/material.dart';

import '../game/economy.dart';
import '../game/number_master_game.dart';
import '../screens/shop_screen.dart';
import '../services/save_service.dart';
import '../theme/palette.dart';

class LevelCompleteOverlay extends StatelessWidget {
  const LevelCompleteOverlay({super.key, required this.game});

  final NumberMasterGame game;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppPalette.overlayScrim,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'LEVEL ${game.level} COMPLETE!',
              style: const TextStyle(color: Colors.amberAccent, fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Leftover number: ${game.player.number}',
              style: const TextStyle(color: Colors.white70, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              '+${Economy.coinsForRun(game.player.number, SaveService.instance.incomeMultiplier)} coins',
              style: const TextStyle(color: Colors.amberAccent, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: game.onRequestNextLevel, child: const Text('Next Level')),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ShopScreen()),
              ),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
              icon: const Icon(Icons.storefront),
              label: const Text('Shop'),
            ),
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
