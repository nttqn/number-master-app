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

  /// Coins awarded for a run that ended with [finalNumber] (win or lose —
  /// losing still rewards partial progress, matching the genre's usual
  /// "always earn something" design so a bad run isn't a dead end).
  static int coinsForRun(int finalNumber, double incomeMultiplier) {
    return (finalNumber * 5 * incomeMultiplier).round();
  }
}
