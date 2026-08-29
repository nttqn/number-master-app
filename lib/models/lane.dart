/// Lanes are indexed 0 (left), 1 (middle), 2 (right). This helper maps that
/// to the -1/0/1 offset the projection math uses.
extension LaneOffset on int {
  double get laneOffset => (this - 1).toDouble();
}

const int kLaneCount = 3;
