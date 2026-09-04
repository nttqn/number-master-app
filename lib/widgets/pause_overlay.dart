import 'package:flutter/material.dart';

import '../game/number_master_game.dart';
import '../screens/shop_screen.dart';
import '../services/sound_service.dart';
import '../theme/palette.dart';

class PauseOverlay extends StatelessWidget {
  const PauseOverlay({super.key, required this.game});

  final NumberMasterGame game;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppPalette.overlayScrim,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('PAUSED', style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                SoundService.instance.play(SfxEvent.menuBack);
                game.resumeFromPause();
              },
              child: const Text('Resume'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                SoundService.instance.play(SfxEvent.menuConfirm);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ShopScreen()),
                );
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppPalette.menuTextAccent,
                side: const BorderSide(color: AppPalette.menuTextAccent, width: 2),
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              icon: const Icon(Icons.storefront),
              label: const Text('Shop'),
            ),
            const SizedBox(height: 12),
            ValueListenableBuilder<bool>(
              valueListenable: SoundService.instance.enabledNotifier,
              builder: (context, enabled, _) => TextButton.icon(
                onPressed: SoundService.instance.toggleEnabled,
                icon: Icon(enabled ? Icons.volume_up : Icons.volume_off, color: AppPalette.menuTextAccent),
                label: Text(
                  enabled ? 'Sound On' : 'Sound Off',
                  style: const TextStyle(color: AppPalette.menuTextAccent, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
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
