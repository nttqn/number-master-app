/// Shop cosmetics: purely visual, bought with coins. Each item becomes
/// buyable once the player has unlocked [unlockLevel], so the catalog
/// reveals itself gradually instead of showing everything priced out of
/// reach on day one.
enum PlayerSkin {
  cube('Cube', 0, 1),
  ball('Ball', 1000, 1),
  candy('Candy', 2500, 3),
  wood('Wood', 4000, 5),
  slime('Slime', 7000, 8),
  gem('Gem', 15000, 12);

  const PlayerSkin(this.label, this.price, this.unlockLevel);
  final String label;
  final int price;
  final int unlockLevel;

  static PlayerSkin byName(String? name) =>
      PlayerSkin.values.firstWhere((s) => s.name == name, orElse: () => PlayerSkin.cube);
}

enum PlayerTrail {
  none('None', 0, 1),
  sparkle('Sparkle', 1500, 2),
  rainbow('Rainbow', 5000, 6),
  fire('Fire', 10000, 10);

  const PlayerTrail(this.label, this.price, this.unlockLevel);
  final String label;
  final int price;
  final int unlockLevel;

  static PlayerTrail byName(String? name) =>
      PlayerTrail.values.firstWhere((t) => t.name == name, orElse: () => PlayerTrail.none);
}
