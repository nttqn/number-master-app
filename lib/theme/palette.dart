import 'package:flutter/material.dart';

/// Shared colors for the menu, in-game road, and overlays — kept in one
/// place since "make it brighter" means tuning the same handful of
/// background tones consistently everywhere, not just one screen.
class AppPalette {
  AppPalette._();

  static const Color background = Color(0xFF24447D);
  static const Color roadSurface = Color(0xFF5D82C4);
  static const Color laneDivider = Color(0x99FFFFFF);
  static const Color overlayScrim = Color(0xE6132548);
  static const Color overlayScrimLight = Color(0x99132548);
}
