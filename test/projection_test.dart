import 'package:flutter_test/flutter_test.dart';
import 'package:number_master/game/projection.dart';

void main() {
  const projection = Projection(screenWidth: 400, screenHeight: 800);

  test('scale is 1.0 at distance 0', () {
    expect(projection.scaleAt(0), closeTo(1.0, 1e-9));
  });

  test('scale decreases monotonically as distance grows', () {
    double prev = projection.scaleAt(0);
    for (final d in [1.0, 5.0, 10.0, 20.0, 50.0, 100.0]) {
      final s = projection.scaleAt(d);
      expect(s, lessThan(prev));
      prev = s;
    }
  });

  test('scale never drops below the floor', () {
    expect(projection.scaleAt(100000), greaterThanOrEqualTo(projection.minRenderScale));
  });

  test('screenY interpolates from horizon toward ground as distance shrinks', () {
    final farY = projection.screenYAt(1000);
    final nearY = projection.screenYAt(0);
    expect(nearY, projection.groundY);
    expect(farY, lessThan(nearY));
    expect(farY, greaterThanOrEqualTo(projection.horizonY));
  });

  test('lanes converge toward screen center as distance grows', () {
    final farX = projection.screenXAt(1.0, 1000);
    final nearX = projection.screenXAt(1.0, 0);
    expect((farX - projection.screenCenterX).abs(), lessThan((nearX - projection.screenCenterX).abs()));
  });

  test('left/mid/right lanes are mirrored around center at any distance', () {
    for (final d in [0.0, 5.0, 20.0]) {
      final left = projection.screenXAt(-1.0, d);
      final mid = projection.screenXAt(0.0, d);
      final right = projection.screenXAt(1.0, d);
      expect(mid, closeTo(projection.screenCenterX, 1e-9));
      expect(projection.screenCenterX - left, closeTo(right - projection.screenCenterX, 1e-9));
    }
  });
}
