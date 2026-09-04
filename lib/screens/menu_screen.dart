import 'package:flutter/material.dart';

import '../services/save_service.dart';
import '../services/sound_service.dart';
import '../theme/palette.dart';
import 'game_screen.dart';
import 'shop_screen.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  int _unlockedLevel = 1;

  @override
  void initState() {
    super.initState();
    SaveService.instance.getUnlockedLevel().then((level) {
      if (mounted) setState(() => _unlockedLevel = level);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/images/bg.png', fit: BoxFit.cover),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ValueListenableBuilder<int>(
                        valueListenable: SaveService.instance.coinsNotifier,
                        builder: (context, coins, _) => Row(
                          children: [
                            const Icon(Icons.attach_money, color: Colors.amberAccent, size: 22),
                            Text(
                              '$coins',
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  const Text(
                    'NUMBER MASTER',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Run. Merge. Break through.',
                    style: TextStyle(color: Colors.white60, fontSize: 16),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => GameScreen(startLevel: _unlockedLevel)),
                    ),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16)),
                    child: Text('PLAY  (Level $_unlockedLevel)', style: const TextStyle(fontSize: 18)),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ShopScreen()),
                    ),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                    icon: const Icon(Icons.storefront),
                    label: const Text('SHOP'),
                  ),
                  const SizedBox(height: 16),
                  ValueListenableBuilder<bool>(
                    valueListenable: SoundService.instance.enabledNotifier,
                    builder: (context, enabled, _) => TextButton.icon(
                      onPressed: SoundService.instance.toggleEnabled,
                      icon: Icon(enabled ? Icons.volume_up : Icons.volume_off, color: Colors.white70),
                      label: Text(enabled ? 'Sound On' : 'Sound Off', style: const TextStyle(color: Colors.white70)),
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
