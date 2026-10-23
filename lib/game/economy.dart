import 'dart:math';

/// Pure cost/effect curves for the shop upgrades and the coin reward per
/// run — kept separate from [SaveService] (which just persists the
/// resulting levels/balance) so the balance numbers are easy to see and
/// tune in one place.
class Economy {
  Economy._();

  /// Coins needed to go from [currentLevel] to currentLevel + 1.
  static int startNumberCost(int currentLevel) => 500 + currentLevel * 350;

  static int incomeCost(int currentLevel) => 800 + currentLevel * 600;

  /// Added to the player's starting number (1 + this) at [level].
  static int startNumberBonus(int level) => level;

  /// Multiplies coins earned per run at [level].
  static double incomeMultiplier(int level) => 1.0 + level * 0.1;

  /// Coins awarded for a run on [level] that ended with [finalNumber], win
  /// or lose — losing still pays half ([cleared] false), matching the
  /// genre's "always earn something" design so a bad run isn't a dead end.
  ///
  /// Driven mainly by the level; the number only adds logarithmically
  /// (each doubling adds 30% of the base). It used to be linear in the
  /// number, which runs away: multiply gates grow the number
  /// exponentially, coins buy Start Number, a bigger start compounds
  /// through the same gates — a tester had 84 million coins at level 11.
  static int coinsForRun({
    required int level,
    required int finalNumber,
    required double incomeMultiplier,
    bool cleared = true,
  }) {
    final base = 20 + 10 * level;
    final numberFactor = 1 + 0.3 * log(max(1, finalNumber)) / ln2;
    return (base * numberFactor * incomeMultiplier * (cleared ? 1.0 : 0.5)).round();
  }
}
