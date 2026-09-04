/// Shrinks a desired font size so text of [textLength] characters stays
/// within [maxWidth] — pure arithmetic, not a measure-and-retry loop,
/// since this runs inside `render()` every frame for potentially many
/// on-screen entities at once. `0.62` is a rough average glyph-width-to-
/// font-size ratio for bold digits/symbols; it's an approximation, not a
/// pixel-exact fit, which is why every call site still leaves some
/// padding in [maxWidth] rather than sizing to the exact box edge.
double fitFontSize({required int textLength, required double desiredFontSize, required double maxWidth}) {
  if (textLength <= 0 || maxWidth <= 0) return desiredFontSize;
  final estimatedWidth = textLength * desiredFontSize * 0.62;
  if (estimatedWidth <= maxWidth) return desiredFontSize;
  return desiredFontSize * (maxWidth / estimatedWidth);
}
