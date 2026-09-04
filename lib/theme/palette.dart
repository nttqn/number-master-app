import 'package:flutter/material.dart';

/// Shared colors for the menu, in-game road, and overlays — kept in one
/// place since a consistent bright/playful look (matching the reference
/// screenshot: light sky, white road, plain bold number text) means tuning
/// the same handful of tones everywhere, not just one screen.
class AppPalette {
  AppPalette._();

  static const Color skyTop = Color(0xFF3E9BE0);
  static const Color skyBottom = Color(0xFFBFE6FA);
  static const Color background = skyTop;
  static const Color roadSurface = Color(0xFFF4F6F9);
  static const Color roadStripe = Color(0xFFE2E7ED);
  static const Color laneDivider = Color(0xFFC3CBD6);

  static const Color enemyNumber = Color(0xFFE0293E);
  static const Color friendlyNumber = Color(0xFF2D6CDF);
  static const Color wallFill = Color(0xFFE0299E);

  static const Color overlayScrim = Color(0xE6132548);
  static const Color overlayScrimLight = Color(0x99132548);

  /// The main-menu START button — a warm gradient so it pops against the
  /// blue sky background instead of blending into it.
  static const Color ctaGradientStart = Color(0xFFFFD23F);
  static const Color ctaGradientEnd = Color(0xFFFF5F1F);
}
