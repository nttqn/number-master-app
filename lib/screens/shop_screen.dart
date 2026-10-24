import 'package:flutter/material.dart';

import '../game/components/trail_component.dart';
import '../game/cosmetics.dart';
import '../game/economy.dart';
import '../game/skin_painter.dart';
import '../services/save_service.dart';
import '../services/sound_service.dart';
import '../theme/palette.dart';

class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final save = SaveService.instance;
    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text('SHOP', style: TextStyle(fontWeight: FontWeight.w900)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            SoundService.instance.play(SfxEvent.menuBack);
            Navigator.of(context).pop();
          },
        ),
        actions: [
          ValueListenableBuilder<int>(
            valueListenable: save.coinsNotifier,
            builder: (context, coins, _) => Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Row(
                children: [
                  const Icon(Icons.attach_money, color: Colors.amberAccent, size: 24),
                  Text('$coins', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            const _SectionTitle('UPGRADES'),
            Row(
              children: [
                Expanded(
                  child: _UpgradeCard(
                    title: 'START NUMBER',
                    icon: Icons.trending_up,
                    levelNotifier: save.startNumberLevelNotifier,
                    effectLabel: (level) =>
                        '${1 + Economy.startNumberBonus(level)} » ${1 + Economy.startNumberBonus(level + 1)}',
                    cost: Economy.startNumberCost,
                    onBuy: save.buyStartNumberUpgrade,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _UpgradeCard(
                    title: 'INCOME',
                    icon: Icons.savings,
                    levelNotifier: save.incomeLevelNotifier,
                    effectLabel: (level) =>
                        'x${Economy.incomeMultiplier(level).toStringAsFixed(1)} » x${Economy.incomeMultiplier(level + 1).toStringAsFixed(1)}',
                    cost: Economy.incomeCost,
                    onBuy: save.buyIncomeUpgrade,
                  ),
                ),
              ],
            ),
            const _SectionTitle('SKINS'),
            _ItemGrid(
              children: [
                for (final skin in PlayerSkin.values)
                  ValueListenableBuilder<Set<PlayerSkin>>(
                    valueListenable: save.ownedSkinsNotifier,
                    builder: (context, owned, _) => ValueListenableBuilder<PlayerSkin>(
                      valueListenable: save.selectedSkinNotifier,
                      builder: (context, selected, _) => _ItemCard(
                        label: skin.label,
                        price: skin.price,
                        unlockLevel: skin.unlockLevel,
                        owned: owned.contains(skin),
                        selected: selected == skin,
                        preview: CustomPaint(painter: _SkinPreviewPainter(skin)),
                        onBuy: () => save.buySkin(skin),
                        onSelect: () => save.selectSkin(skin),
                      ),
                    ),
                  ),
              ],
            ),
            const _SectionTitle('TRAILS'),
            _ItemGrid(
              columns: 4,
              children: [
                for (final trail in PlayerTrail.values)
                  ValueListenableBuilder<Set<PlayerTrail>>(
                    valueListenable: save.ownedTrailsNotifier,
                    builder: (context, owned, _) => ValueListenableBuilder<PlayerTrail>(
                      valueListenable: save.selectedTrailNotifier,
                      builder: (context, selected, _) => _ItemCard(
                        label: trail.label,
                        price: trail.price,
                        unlockLevel: trail.unlockLevel,
                        owned: owned.contains(trail),
                        selected: selected == trail,
                        preview: CustomPaint(painter: _TrailPreviewPainter(trail)),
                        onBuy: () => save.buyTrail(trail),
                        onSelect: () => save.selectTrail(trail),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 10, left: 2),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
          shadows: [Shadow(color: Colors.black26, blurRadius: 4)],
        ),
      ),
    );
  }
}

class _ItemGrid extends StatelessWidget {
  const _ItemGrid({required this.children, this.columns = 3});
  final List<Widget> children;
  final int columns;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: columns,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: columns == 3 ? 0.72 : 0.56,
      children: children,
    );
  }
}

/// One cosmetic: preview, name, and a single action button whose state is
/// IN USE / USE / locked until level N / price (disabled when unaffordable).
class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.label,
    required this.price,
    required this.unlockLevel,
    required this.owned,
    required this.selected,
    required this.preview,
    required this.onBuy,
    required this.onSelect,
  });

  final String label;
  final int price;
  final int unlockLevel;
  final bool owned;
  final bool selected;
  final Widget preview;
  final Future<bool> Function() onBuy;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final save = SaveService.instance;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: selected ? Colors.white.withValues(alpha: 0.32) : Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: selected ? Colors.amberAccent : Colors.transparent, width: 3),
      ),
      child: Column(
        children: [
          // A childless CustomPaint sizes itself to zero width here unless
          // forced to fill.
          Expanded(child: SizedBox.expand(child: preview)),
          // Scales down instead of wrapping in the narrow 4-column grid.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            height: 32,
            child: ValueListenableBuilder<int>(
              valueListenable: save.unlockedLevelNotifier,
              builder: (context, unlocked, _) => ValueListenableBuilder<int>(
                valueListenable: save.coinsNotifier,
                builder: (context, coins, _) {
                  if (selected) return _pill('IN USE', const Color(0xFF10B981), null);
                  if (owned) {
                    return _pill('USE', const Color(0xFF3D8BFF), () {
                      SoundService.instance.play(SfxEvent.menuConfirm);
                      onSelect();
                    });
                  }
                  if (unlocked < unlockLevel) {
                    return _pill('LV $unlockLevel', const Color(0xFF64748B), null, icon: Icons.lock);
                  }
                  final affordable = coins >= price;
                  return _pill(
                    '$price',
                    affordable ? const Color(0xFFFF8A3D) : const Color(0xFF94A3B8),
                    affordable
                        ? () {
                            SoundService.instance.play(SfxEvent.menuConfirm);
                            onBuy();
                          }
                        : null,
                    icon: Icons.attach_money,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(String text, Color color, VoidCallback? onTap, {IconData? icon}) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) Icon(icon, color: Colors.white, size: 15),
            Text(text, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

class _SkinPreviewPainter extends CustomPainter {
  _SkinPreviewPainter(this.skin);
  final PlayerSkin skin;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.shortestSide * 0.85;
    canvas.save();
    canvas.translate((size.width - w) / 2, (size.height - w) / 2 + w * 0.05);
    final ground = w * 0.85;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w / 2, ground), width: w * 0.9, height: w * 0.18),
      Paint()..color = const Color(0x33000000),
    );
    // 16 shows a mid-tier body color rather than the starting green.
    paintPlayerSkin(canvas, w: w, ground: ground, hop: 0, skin: skin, number: 16);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SkinPreviewPainter old) => old.skin != skin;
}

class _TrailPreviewPainter extends CustomPainter {
  _TrailPreviewPainter(this.trail);
  final PlayerTrail trail;

  @override
  void paint(Canvas canvas, Size size) => paintTrailPreview(canvas, size, trail);

  @override
  bool shouldRepaint(_TrailPreviewPainter old) => old.trail != trail;
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
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
                  Icon(icon, color: Colors.white, size: 20),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      title,
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(effectLabel(level), style: const TextStyle(color: Colors.white, fontSize: 16)),
              const SizedBox(height: 10),
              ValueListenableBuilder<int>(
                valueListenable: SaveService.instance.coinsNotifier,
                builder: (context, coins, _) {
                  final canAfford = coins >= nextCost;
                  return SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
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
