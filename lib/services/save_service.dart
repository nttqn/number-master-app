import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../game/cosmetics.dart';
import '../game/economy.dart';

/// Persists progress across app restarts: highest unlocked level, the best
/// (largest) final number reached per level, and the shop economy (coin
/// balance + upgrade levels).
///
/// The economy fields are cached in memory after the first [loadEconomy]
/// call (fired once, unawaited, from `main()`) so the rest of the app can
/// read `coins`/`startNumberBonus`/`incomeMultiplier` synchronously instead
/// of threading `Future`s through the game-start path — same "safe
/// defaults, non-blocking" pattern as [AdsService]/[SoundService].
class SaveService {
  SaveService._();
  static final SaveService instance = SaveService._();

  static const _unlockedLevelKey = 'nm_unlocked_level';
  static const _bestNumberPrefix = 'nm_best_number_';
  static const _coinsKey = 'nm_coins';
  static const _startNumberLevelKey = 'nm_start_number_level';
  static const _incomeLevelKey = 'nm_income_level';

  static const _ownedSkinsKey = 'nm_owned_skins';
  static const _selectedSkinKey = 'nm_selected_skin';
  static const _ownedTrailsKey = 'nm_owned_trails';
  static const _selectedTrailKey = 'nm_selected_trail';

  final ValueNotifier<int> coinsNotifier = ValueNotifier(0);
  final ValueNotifier<int> startNumberLevelNotifier = ValueNotifier(0);
  final ValueNotifier<int> incomeLevelNotifier = ValueNotifier(0);

  /// Highest unlocked level, cached for the shop's per-item unlock gates.
  final ValueNotifier<int> unlockedLevelNotifier = ValueNotifier(1);

  /// Cosmetics. Owned sets always include the free defaults.
  final ValueNotifier<Set<PlayerSkin>> ownedSkinsNotifier = ValueNotifier({PlayerSkin.cube});
  final ValueNotifier<PlayerSkin> selectedSkinNotifier = ValueNotifier(PlayerSkin.cube);
  final ValueNotifier<Set<PlayerTrail>> ownedTrailsNotifier = ValueNotifier({PlayerTrail.none});
  final ValueNotifier<PlayerTrail> selectedTrailNotifier = ValueNotifier(PlayerTrail.none);

  PlayerSkin get selectedSkin => selectedSkinNotifier.value;
  PlayerTrail get selectedTrail => selectedTrailNotifier.value;

  bool _economyLoaded = false;

  int get coins => coinsNotifier.value;
  int get startNumberLevel => startNumberLevelNotifier.value;
  int get incomeLevel => incomeLevelNotifier.value;
  int get startNumberBonus => Economy.startNumberBonus(startNumberLevel);
  double get incomeMultiplier => Economy.incomeMultiplier(incomeLevel);

  Future<void> loadEconomy() async {
    if (_economyLoaded) return;
    _economyLoaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      coinsNotifier.value = prefs.getInt(_coinsKey) ?? 0;
      startNumberLevelNotifier.value = prefs.getInt(_startNumberLevelKey) ?? 0;
      incomeLevelNotifier.value = prefs.getInt(_incomeLevelKey) ?? 0;
      unlockedLevelNotifier.value = prefs.getInt(_unlockedLevelKey) ?? 1;
      ownedSkinsNotifier.value = {
        PlayerSkin.cube,
        ...?prefs.getStringList(_ownedSkinsKey)?.map(PlayerSkin.byName),
      };
      ownedTrailsNotifier.value = {
        PlayerTrail.none,
        ...?prefs.getStringList(_ownedTrailsKey)?.map(PlayerTrail.byName),
      };
      final skin = PlayerSkin.byName(prefs.getString(_selectedSkinKey));
      selectedSkinNotifier.value = ownedSkinsNotifier.value.contains(skin) ? skin : PlayerSkin.cube;
      final trail = PlayerTrail.byName(prefs.getString(_selectedTrailKey));
      selectedTrailNotifier.value = ownedTrailsNotifier.value.contains(trail) ? trail : PlayerTrail.none;
    } catch (_) {}
  }

  Future<void> _persistCosmetics() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_ownedSkinsKey, ownedSkinsNotifier.value.map((s) => s.name).toList());
      await prefs.setString(_selectedSkinKey, selectedSkin.name);
      await prefs.setStringList(_ownedTrailsKey, ownedTrailsNotifier.value.map((t) => t.name).toList());
      await prefs.setString(_selectedTrailKey, selectedTrail.name);
    } catch (_) {}
  }

  /// Buys [skin] (if affordable and unlocked) and equips it. Returns
  /// whether it was bought.
  Future<bool> buySkin(PlayerSkin skin) async {
    await loadEconomy();
    if (ownedSkinsNotifier.value.contains(skin)) return false;
    if (coins < skin.price || unlockedLevelNotifier.value < skin.unlockLevel) return false;
    coinsNotifier.value -= skin.price;
    ownedSkinsNotifier.value = {...ownedSkinsNotifier.value, skin};
    selectedSkinNotifier.value = skin;
    unawaited(_persistEconomy());
    unawaited(_persistCosmetics());
    return true;
  }

  void selectSkin(PlayerSkin skin) {
    if (!ownedSkinsNotifier.value.contains(skin)) return;
    selectedSkinNotifier.value = skin;
    unawaited(_persistCosmetics());
  }

  Future<bool> buyTrail(PlayerTrail trail) async {
    await loadEconomy();
    if (ownedTrailsNotifier.value.contains(trail)) return false;
    if (coins < trail.price || unlockedLevelNotifier.value < trail.unlockLevel) return false;
    coinsNotifier.value -= trail.price;
    ownedTrailsNotifier.value = {...ownedTrailsNotifier.value, trail};
    selectedTrailNotifier.value = trail;
    unawaited(_persistEconomy());
    unawaited(_persistCosmetics());
    return true;
  }

  void selectTrail(PlayerTrail trail) {
    if (!ownedTrailsNotifier.value.contains(trail)) return;
    selectedTrailNotifier.value = trail;
    unawaited(_persistCosmetics());
  }

  /// Flat coin grant — the rewarded-ad "x2" on level complete pays the
  /// run's coins a second time through this.
  Future<void> addCoins(int amount) async {
    await loadEconomy();
    coinsNotifier.value += amount;
    unawaited(_persistEconomy());
  }

  Future<void> _persistEconomy() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_coinsKey, coinsNotifier.value);
      await prefs.setInt(_startNumberLevelKey, startNumberLevelNotifier.value);
      await prefs.setInt(_incomeLevelKey, incomeLevelNotifier.value);
    } catch (_) {}
  }

  /// Awards coins for a finished run (win or lose) based on [finalNumber]
  /// and the current income multiplier, times the bonus staircase's
  /// [bonusMultiplier] on a level clear.
  Future<void> awardCoins(int finalNumber, {int bonusMultiplier = 1}) async {
    await loadEconomy();
    coinsNotifier.value += Economy.coinsForRun(finalNumber, incomeMultiplier) * bonusMultiplier;
    unawaited(_persistEconomy());
  }

  /// Returns true if the upgrade was purchased (false if not enough coins).
  Future<bool> buyStartNumberUpgrade() async {
    await loadEconomy();
    final cost = Economy.startNumberCost(startNumberLevel);
    if (coins < cost) return false;
    coinsNotifier.value -= cost;
    startNumberLevelNotifier.value += 1;
    unawaited(_persistEconomy());
    return true;
  }

  Future<bool> buyIncomeUpgrade() async {
    await loadEconomy();
    final cost = Economy.incomeCost(incomeLevel);
    if (coins < cost) return false;
    coinsNotifier.value -= cost;
    incomeLevelNotifier.value += 1;
    unawaited(_persistEconomy());
    return true;
  }

  Future<int> getUnlockedLevel() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_unlockedLevelKey) ?? 1;
    } catch (_) {
      return 1;
    }
  }

  Future<void> unlockLevel(int level) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = prefs.getInt(_unlockedLevelKey) ?? 1;
      if (level > current) {
        await prefs.setInt(_unlockedLevelKey, level);
        unlockedLevelNotifier.value = level;
      }
    } catch (_) {}
  }

  Future<int> getBestNumber(int level) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt('$_bestNumberPrefix$level') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> recordBestNumber(int level, int finalNumber) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_bestNumberPrefix$level';
      final current = prefs.getInt(key) ?? 0;
      if (finalNumber > current) {
        await prefs.setInt(key, finalNumber);
      }
    } catch (_) {}
  }
}
