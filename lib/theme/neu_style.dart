import 'package:flutter/painting.dart';

import 'app_colors.dart';

/// Shared radii and shadow recipes for the soft-UI (neumorphic) look.
abstract final class NeuStyle {
  static const double radiusCard = 24;
  static const double radiusFrame = 44;
  static const double radiusTile = 18;

  /// Raised element: dark shadow bottom-right, light highlight top-left.
  static List<BoxShadow> raised({double depth = 6, double blur = 14}) => [
    BoxShadow(
      color: AppColors.shadowDark,
      offset: Offset(depth, depth),
      blurRadius: blur,
    ),
    BoxShadow(
      color: AppColors.shadowLight,
      offset: Offset(-depth, -depth),
      blurRadius: blur,
    ),
  ];

  /// Pressed element: the light source flips so the surface reads as sunken.
  static List<BoxShadow> sunken({double depth = 3, double blur = 6}) => [
    BoxShadow(
      color: AppColors.shadowLight,
      offset: Offset(depth, depth),
      blurRadius: blur,
    ),
    BoxShadow(
      color: AppColors.shadowDark,
      offset: Offset(-depth, -depth),
      blurRadius: blur,
    ),
  ];

  /// Shared fill of the left dock and the bottom player bar.
  static const Color dockFill = Color(0xFF2E2E2E);

  static const BorderSide dockDivider = BorderSide(
    color: Color(0x591C1C1C),
  );

  /// Soft shadow along one edge, lifting a dock off the page.
  /// Default casts to the right; pass [offset] `(0, -6)` for a top edge.
  static List<BoxShadow> dockEdge({
    double blur = 28,
    Offset offset = const Offset(6, 0),
  }) => [
    BoxShadow(
      color: AppColors.shadowDark.withValues(alpha: 0.75),
      offset: offset,
      blurRadius: blur,
      spreadRadius: 2,
    ),
    BoxShadow(
      color: AppColors.shadowLight.withValues(alpha: 0.06),
      offset: Offset(-offset.dx * 0.33, -offset.dy * 0.33),
      blurRadius: blur * 0.35,
    ),
  ];

  /// Left rail and bottom bar share this so they read as one piece.
  static BoxDecoration dockPanel({required Offset shadowOffset}) =>
      BoxDecoration(
        color: dockFill,
        boxShadow: dockEdge(offset: shadowOffset),
        border: Border(
          right: shadowOffset.dx > 0 ? dockDivider : BorderSide.none,
          top: shadowOffset.dy < 0 ? dockDivider : BorderSide.none,
          bottom: shadowOffset.dy > 0 ? dockDivider : BorderSide.none,
        ),
      );

  /// Two-layer coloured halo: a tight core plus a wide bloom.
  static List<BoxShadow> glow(
    Color color, {
    double blur = 24,
    double spread = 0,
    double opacity = 1,
  }) => [
    BoxShadow(
      color: color.withValues(alpha: 0.65 * opacity),
      blurRadius: blur * 0.4,
      spreadRadius: spread,
    ),
    BoxShadow(
      color: color.withValues(alpha: 0.40 * opacity),
      blurRadius: blur,
      spreadRadius: spread,
    ),
  ];

  /// Subtle diagonal sheen that gives flat surfaces volume.
  static const LinearGradient surfaceGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF333333), Color(0xFF272727)],
  );

  static const LinearGradient sunkenGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF262626), Color(0xFF323232)],
  );
}
