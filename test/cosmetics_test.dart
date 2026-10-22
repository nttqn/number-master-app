import 'package:flutter_test/flutter_test.dart';
import 'package:number_master/game/cosmetics.dart';

void main() {
  test('free defaults cost nothing and are available from level 1', () {
    expect(PlayerSkin.cube.price, 0);
    expect(PlayerSkin.cube.unlockLevel, 1);
    expect(PlayerTrail.none.price, 0);
    expect(PlayerTrail.none.unlockLevel, 1);
  });

  test('unknown or missing saved names fall back to the defaults', () {
    expect(PlayerSkin.byName(null), PlayerSkin.cube);
    expect(PlayerSkin.byName('removed_skin'), PlayerSkin.cube);
    expect(PlayerTrail.byName(null), PlayerTrail.none);
    expect(PlayerTrail.byName('nope'), PlayerTrail.none);
  });

  test('saved names round-trip', () {
    for (final s in PlayerSkin.values) {
      expect(PlayerSkin.byName(s.name), s);
    }
    for (final t in PlayerTrail.values) {
      expect(PlayerTrail.byName(t.name), t);
    }
  });

  test('catalog prices and unlock levels never decrease down the list', () {
    for (final list in [PlayerSkin.values, PlayerTrail.values]) {
      for (int i = 1; i < list.length; i++) {
        final prev = list[i - 1] as dynamic, cur = list[i] as dynamic;
        expect(cur.price as int, greaterThanOrEqualTo(prev.price as int));
        expect(cur.unlockLevel as int, greaterThanOrEqualTo(prev.unlockLevel as int));
      }
    }
  });
}
