import 'package:flutter_test/flutter_test.dart';
import 'package:number_master/game/economy.dart';

void main() {
  test('startNumberCost increases with level', () {
    double? prev;
    for (final level in [0, 1, 2, 5, 10]) {
      final cost = Economy.startNumberCost(level).toDouble();
      if (prev != null) expect(cost, greaterThan(prev));
      prev = cost;
    }
  });

  test('incomeCost increases with level', () {
    double? prev;
    for (final level in [0, 1, 2, 5, 10]) {
      final cost = Economy.incomeCost(level).toDouble();
      if (prev != null) expect(cost, greaterThan(prev));
      prev = cost;
    }
  });

  test('startNumberBonus is 0 at level 0 and grows by 1 per level', () {
    expect(Economy.startNumberBonus(0), 0);
    expect(Economy.startNumberBonus(1), 1);
    expect(Economy.startNumberBonus(5), 5);
  });

  test('incomeMultiplier is 1.0 at level 0 and grows by 0.1 per level', () {
    expect(Economy.incomeMultiplier(0), closeTo(1.0, 1e-9));
    expect(Economy.incomeMultiplier(1), closeTo(1.1, 1e-9));
    expect(Economy.incomeMultiplier(10), closeTo(2.0, 1e-9));
  });

  int coins(int level, int number, {double income = 1.0, bool cleared = true}) =>
      Economy.coinsForRun(level: level, finalNumber: number, incomeMultiplier: income, cleared: cleared);

  test('coinsForRun: base by level, scaled by income, halved on a loss', () {
    expect(coins(1, 1), 30);
    expect(coins(1, 1, income: 2.0), 60);
    expect(coins(1, 1, cleared: false), 15);
    expect(coins(10, 0), 120); // number below 1 treated as 1
  });

  test('coinsForRun grows only logarithmically with the number', () {
    // Doubling the number adds 30% of the base, never doubles the coins.
    expect(coins(5, 64) - coins(5, 32), closeTo(70 * 0.3, 1));
    // The reported runaway: level 11, number ~444k used to pay ~2.2M
    // coins before the bonus multiplier.
    expect(coins(11, 444538), lessThan(1000));
  });

  test('coinsForRun rises with level at the same number', () {
    expect(coins(20, 100), greaterThan(coins(5, 100)));
  });
}
