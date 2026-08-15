import 'package:flutter/material.dart';

import '../theme/acorn_palette.dart';
import '../theme/neu_style.dart';

/// Round soft-UI button. Presses shorten the shadow so the button sinks in.
class NeuIconButton extends StatefulWidget {
  const NeuIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.size = 44,
    this.iconSize = 20,
    this.depth = 5,
    this.blur = 10,
    this.iconColor,
    this.fill,
    this.glowColor,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;
  final double depth;
  final double blur;
  final Color? iconColor;

  /// Solid background instead of the neumorphic sheen (used by the play button).
  final Color? fill;
  final Color? glowColor;

  @override
  State<NeuIconButton> createState() => _NeuIconButtonState();
}

class _NeuIconButtonState extends State<NeuIconButton> {
  bool _pressed = false;

  void handleTapDown(TapDownDetails _) => setState(() => _pressed = true);

  void handleTapCancel() => setState(() => _pressed = false);

  void handleTapUp(TapUpDetails _) => setState(() => _pressed = false);

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final depth = _pressed ? widget.depth * 0.4 : widget.depth;
    final glow = widget.glowColor;

    return GestureDetector(
      onTapDown: widget.onPressed == null ? null : handleTapDown,
      onTapUp: widget.onPressed == null ? null : handleTapUp,
      onTapCancel: widget.onPressed == null ? null : handleTapCancel,
      onTap: widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.fill,
          gradient: widget.fill == null ? palette.surfaceGradient : null,
          boxShadow: [
            ...NeuStyle.raised(depth: depth, blur: widget.blur, palette: palette),
            if (glow != null)
              ...NeuStyle.glow(glow, blur: widget.size * 0.55, spread: -2),
          ],
        ),
        child: Center(
          child: Icon(
            widget.icon,
            size: widget.iconSize,
            color: widget.iconColor ?? palette.icon,
          ),
        ),
      ),
    );
  }
}
