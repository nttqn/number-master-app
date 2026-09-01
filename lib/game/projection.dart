/// Pure math for the 2.5D pseudo-3D perspective effect: everything in the
/// world is positioned by a single scalar "distance" (how far ahead of the
/// player it is, decreasing over time), fed through here to get a screen
/// position and scale. No Flame/Flutter imports on purpose — this is the
/// riskiest, least-precedented part of the whole game, so it's kept
/// independently unit-testable (see test/projection_test.dart).
///
/// The scaling curve is the classic inverse-distance pseudo-3D trick:
/// scale = k / (d + k), which is 1.0 at d=0 (right in front of the player)
/// and asymptotically approaches 0 as d grows, giving the "grows out of the
/// vanishing point" look. The same scale factor drives both the Y position
/// (far things sit near the horizon, near things sit at ground level) and
/// the lane X-spread (far lanes converge toward screen center), which is
/// what produces a converging road without drawing real 3D geometry.
class Projection {
  const Projection({
    required this.screenWidth,
    required this.screenHeight,
    this.horizonFraction = 0.30,
    this.groundFraction = 0.86,
    this.cameraDepth = 7.0,
    this.laneSpreadFraction = 0.32,
    this.minRenderScale = 0.06,
  });

  final double screenWidth;
  final double screenHeight;

  /// Fraction of screen height where the vanishing point sits.
  final double horizonFraction;

  /// Fraction of screen height where the player (d=0) sits.
  final double groundFraction;

  /// Controls how quickly things grow as they approach — smaller values
  /// make the approach feel faster/steeper.
  final double cameraDepth;

  /// Half-width, as a fraction of screen width, between the outer lanes
  /// at d=0.
  final double laneSpreadFraction;

  /// Floor so far-away entities don't shrink to an invisible/zero size.
  final double minRenderScale;

  double get horizonY => screenHeight * horizonFraction;
  double get groundY => screenHeight * groundFraction;
  double get screenCenterX => screenWidth / 2;
  double get maxLaneOffsetPx => screenWidth * laneSpreadFraction;

  /// Perspective scale factor at [distance], clamped to [0, 1] with a
  /// floor of [minRenderScale].
  double scaleAt(double distance) {
    final d = distance < 0 ? 0.0 : distance;
    final raw = cameraDepth / (d + cameraDepth);
    return raw.clamp(minRenderScale, 1.0);
  }

  double screenYAt(double distance) {
    final s = scaleAt(distance);
    return horizonY + (groundY - horizonY) * s;
  }

  /// [laneOffset] is -1 (left), 0 (middle), or 1 (right).
  double screenXAt(double laneOffset, double distance) {
    final s = scaleAt(distance);
    return screenCenterX + laneOffset * maxLaneOffsetPx * s;
  }

  /// Scales a base (d=0, full-size) render dimension down for [distance].
  double renderSizeAt(double distance, double baseSize) {
    return baseSize * scaleAt(distance);
  }
}
