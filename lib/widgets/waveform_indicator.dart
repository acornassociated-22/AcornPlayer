import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Small equaliser that marks the row currently playing.
class WaveformIndicator extends StatefulWidget {
  const WaveformIndicator({
    super.key,
    this.animate = true,
    this.color = AppColors.accent,
    this.size = 18,
    this.barCount = 5,
  });

  final bool animate;
  final Color color;
  final double size;
  final int barCount;

  @override
  State<WaveformIndicator> createState() => _WaveformIndicatorState();
}

class _WaveformIndicatorState extends State<WaveformIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _controller.repeat();
  }

  @override
  void didUpdateWidget(WaveformIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.animate && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final barWidth = widget.size / (widget.barCount * 2 - 1);

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(widget.barCount, (index) {
            final phase = _controller.value * 2 * math.pi + index * 0.9;
            final level = widget.animate ? 0.55 + 0.45 * math.sin(phase) : 0.4;
            return Container(
              width: barWidth,
              height: widget.size * level.clamp(0.18, 1.0),
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(barWidth),
              ),
            );
          }),
        ),
      ),
    );
  }
}
