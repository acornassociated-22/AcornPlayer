import 'package:flutter/painting.dart';

/// Palette taken from the reference neumorphic design.
abstract final class AppColors {
  /// Backdrop behind the phone frame on desktop.
  static const canvas = Color(0xFF2E2E2E);

  /// Body of the phone / full screen background on mobile.
  static const background = Color(0xFF2A2A2A);

  /// Raised panels, cards and buttons.
  static const surface = Color(0xFF2E2E2E);

  /// Bottom-right shadow of every neumorphic element.
  static const shadowDark = Color(0xFF1C1C1C);

  /// Top-left highlight of every neumorphic element.
  static const shadowLight = Color(0xFF383838);

  static const accent = Color(0xFFE51023);

  /// Glow around the centred album cover in the carousel. Swap this for
  /// `Color(0xFF5CD8F0)` to get the cyan look of the carousel reference.
  static const carouselGlow = accent;

  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFF8A8A8A);
  static const icon = Color(0xFFD6D6D6);

  /// Remaining part of the progress bar.
  static const trackInactive = Color(0xFFC4C4C4);
}
