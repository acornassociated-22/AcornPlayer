import 'package:flutter/widgets.dart';

import '../theme/acorn_palette.dart';
import '../theme/neu_style.dart';

/// Soft-UI surface: a flat panel lifted off the background by a dark shadow on
/// one side and a light highlight on the other.
class NeuContainer extends StatelessWidget {
  const NeuContainer({
    super.key,
    this.child,
    this.radius = NeuStyle.radiusCard,
    this.depth = 6,
    this.blur = 14,
    this.padding,
    this.width,
    this.height,
    this.color,
    this.sunken = false,
    this.circle = false,
    this.glow,
    this.gradient = true,
  });

  final Widget? child;
  final double radius;
  final double depth;
  final double blur;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final Color? color;

  /// Flips the light source so the surface reads as pressed into the page.
  final bool sunken;
  final bool circle;
  final List<BoxShadow>? glow;

  /// Diagonal sheen. Turn off when the child already fills the surface.
  final bool gradient;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: gradient ? null : (color ?? palette.surface),
        gradient: gradient
            ? (sunken ? palette.sunkenGradient : palette.surfaceGradient)
            : null,
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(radius),
        boxShadow: [
          if (sunken)
            ...NeuStyle.sunken(depth: depth, blur: blur, palette: palette)
          else
            ...NeuStyle.raised(depth: depth, blur: blur, palette: palette),
          ...?glow,
        ],
      ),
      child: child,
    );
  }
}
