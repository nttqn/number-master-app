const int kLaneCount = 5;

/// Half-width, in lane-units, between the two outermost lanes — always
/// normalizes the outermost lanes to exactly ±1 regardless of [kLaneCount],
/// which is what lets [Projection] (and anything tuned against its output,
/// like the road's edge margin in [RoadComponent]) stay completely
/// unaware of how many lanes there actually are.
double get kOuterLaneOffset => (kLaneCount - 1) / 2.0;

/// Lanes are indexed 0 (leftmost) .. kLaneCount-1 (rightmost). This helper
/// maps that to the normalized [-1, 1] offset [Projection.screenXAt]
/// expects, centered so the middle lane (or middle *pair*, for an even
/// count) sits at/near 0.
extension LaneOffset on int {
  double get laneOffset => (this - kOuterLaneOffset) / kOuterLaneOffset;
}
