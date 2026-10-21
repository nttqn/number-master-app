import 'package:flutter/material.dart';

import '../game/economy.dart';
import '../game/number_master_game.dart';
import '../screens/shop_screen.dart';
import '../services/save_service.dart';
import '../services/sound_service.dart';
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
              'BONUS x${game.multiplierNotifier.value}',
              style: TextStyle(
                color: AppPalette.stairColors[(game.multiplierNotifier.value - 2).clamp(0, AppPalette.stairColors.length - 1)],
                fontSize: 40,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Number: ${game.bonusNumber}',
              style: const TextStyle(color: Colors.white70, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              '+${Economy.coinsForRun(game.bonusNumber, SaveService.instance.incomeMultiplier) * game.multiplierNotifier.value} coins',
              style: const TextStyle(color: Colors.amberAccent, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                SoundService.instance.play(SfxEvent.menuConfirm);
                game.onRequestNextLevel();
              },
              child: const Text('Next Level'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                SoundService.instance.play(SfxEvent.menuConfirm);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ShopScreen()),
                );
              },
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
              icon: const Icon(Icons.storefront),
              label: const Text('Shop'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                SoundService.instance.play(SfxEvent.menuBack);
                game.onRequestQuit();
              },
              child: const Text('Quit to Menu', style: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
      ),
    );
  }
}
