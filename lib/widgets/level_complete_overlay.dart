import 'package:flutter/material.dart';

import '../game/number_master_game.dart';
import '../screens/shop_screen.dart';
import '../services/ads_service.dart';
import '../services/save_service.dart';
import '../services/sound_service.dart';
import '../theme/palette.dart';

class LevelCompleteOverlay extends StatefulWidget {
  const LevelCompleteOverlay({super.key, required this.game});

  final NumberMasterGame game;

  @override
  State<LevelCompleteOverlay> createState() => _LevelCompleteOverlayState();
}

class _LevelCompleteOverlayState extends State<LevelCompleteOverlay> {
  /// The x2 offer is one-shot per level clear.
  bool _doubled = false;
  bool _adShowing = false;

  NumberMasterGame get game => widget.game;

  int get _earned => SaveService.instance.coinsForRun(
    level: game.level,
    finalNumber: game.bonusNumber,
    cleared: true,
    bonusMultiplier: game.multiplierNotifier.value,
  );

  void _watchAdForDouble() {
    setState(() => _adShowing = true);
    final bonus = _earned;
    AdsService.instance.showRewarded(
      // The run's coins were already paid by GameScreen; watching the ad
      // pays the same amount once more.
      onReward: () {
        SaveService.instance.addCoins(bonus);
        if (mounted) setState(() => _doubled = true);
      },
      onDone: () {
        if (mounted) setState(() => _adShowing = false);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final multiplier = game.multiplierNotifier.value;
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
              'BONUS x$multiplier',
              style: TextStyle(
                color: AppPalette.stairColors[(multiplier - 2).clamp(0, AppPalette.stairColors.length - 1)],
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
              _doubled ? '+${_earned * 2} coins (x2!)' : '+$_earned coins',
              style: const TextStyle(color: Colors.amberAccent, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ValueListenableBuilder<bool>(
              valueListenable: AdsService.instance.rewardedReady,
              builder: (context, ready, _) {
                if (_doubled || _earned <= 0 || (!ready && !_adShowing)) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _DoubleCoinsButton(onPressed: _adShowing ? null : _watchAdForDouble),
                );
              },
            ),
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

/// Bright green pill: "▶ x2 COINS" — the rewarded-ad offer.
class _DoubleCoinsButton extends StatelessWidget {
  const _DoubleCoinsButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onPressed == null ? 0.6 : 1,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF34D399), Color(0xFF059669)]),
          borderRadius: BorderRadius.circular(30),
          boxShadow: const [BoxShadow(color: Color(0x6610B981), blurRadius: 12, offset: Offset(0, 4))],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(30),
            onTap: onPressed,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_circle_fill, color: Colors.white),
                  SizedBox(width: 8),
                  Text('x2 COINS', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
