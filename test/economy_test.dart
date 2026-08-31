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

  test('coinsForRun scales with finalNumber and incomeMultiplier', () {
    expect(Economy.coinsForRun(10, 1.0), 50);
    expect(Economy.coinsForRun(10, 2.0), 100);
    expect(Economy.coinsForRun(0, 1.0), 0);
  });
}
