import 'package:flutter/material.dart';

import '../game/economy.dart';
import '../services/save_service.dart';
import '../services/sound_service.dart';
import '../theme/palette.dart';

class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('SHOP'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            SoundService.instance.play(SfxEvent.menuBack);
            Navigator.of(context).pop();
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ValueListenableBuilder<int>(
                valueListenable: SaveService.instance.coinsNotifier,
                builder: (context, coins, _) => Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.attach_money, color: Colors.amberAccent, size: 28),
                    Text(
                      '$coins',
                      style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              _UpgradeCard(
                title: 'START NUMBER',
                icon: Icons.trending_up,
                levelNotifier: SaveService.instance.startNumberLevelNotifier,
                effectLabel: (level) => '1 + ${Economy.startNumberBonus(level)}  »  1 + ${Economy.startNumberBonus(level + 1)}',
                cost: (level) => Economy.startNumberCost(level),
                onBuy: SaveService.instance.buyStartNumberUpgrade,
              ),
              const SizedBox(height: 20),
              _UpgradeCard(
                title: 'INCOME',
                icon: Icons.savings,
                levelNotifier: SaveService.instance.incomeLevelNotifier,
                effectLabel: (level) =>
                    'x${Economy.incomeMultiplier(level).toStringAsFixed(1)}  »  x${Economy.incomeMultiplier(level + 1).toStringAsFixed(1)}',
                cost: (level) => Economy.incomeCost(level),
                onBuy: SaveService.instance.buyIncomeUpgrade,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpgradeCard extends StatelessWidget {
  const _UpgradeCard({
    required this.title,
    required this.icon,
    required this.levelNotifier,
    required this.effectLabel,
    required this.cost,
    required this.onBuy,
  });

  final String title;
  final IconData icon;
  final ValueNotifier<int> levelNotifier;
  final String Function(int level) effectLabel;
  final int Function(int level) cost;
  final Future<bool> Function() onBuy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ValueListenableBuilder<int>(
        valueListenable: levelNotifier,
        builder: (context, level, _) {
          final nextCost = cost(level);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              Text(effectLabel(level), style: const TextStyle(color: Colors.white70, fontSize: 15)),
              const SizedBox(height: 12),
              ValueListenableBuilder<int>(
                valueListenable: SaveService.instance.coinsNotifier,
                builder: (context, coins, _) {
                  final canAfford = coins >= nextCost;
                  return ElevatedButton(
                    onPressed: canAfford
                        ? () {
                            SoundService.instance.play(SfxEvent.menuConfirm);
                            onBuy();
                          }
                        : null,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.attach_money, size: 18),
                        Text('$nextCost'),
                      ],
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
