import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  final ValueNotifier<int> coinsNotifier = ValueNotifier(0);
  final ValueNotifier<int> startNumberLevelNotifier = ValueNotifier(0);
  final ValueNotifier<int> incomeLevelNotifier = ValueNotifier(0);

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
    } catch (_) {}
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
  /// and the current income multiplier.
  Future<void> awardCoins(int finalNumber) async {
    await loadEconomy();
    coinsNotifier.value += Economy.coinsForRun(finalNumber, incomeMultiplier);
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
