enum GameState {
  menu,
  levelIntro,
  running,
  wallSequence,

  /// After the last wall: smashing x2..x10 multiplier steps.
  bonusStairs,

  /// Brief beat after the staircase ends, before the level-complete
  /// overlay, so the last smash/stop is visible.
  bonusDone,

  /// Dropping through a hole in the bridge, just before game over.
  falling,
  paused,
  levelComplete,
  gameOver,
}
