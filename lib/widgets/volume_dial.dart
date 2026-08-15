import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/acorn_palette.dart';

/// Rotary volume knob: a sunken ring with a glowing arc. The centre ticks
/// through the percentage as the value changes.
class VolumeDial extends StatelessWidget {
  const VolumeDial({
    super.key,
    required this.value,
    required this.onChanged,
    this.onToggleMute,
    this.size = 96,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final VoidCallback? onToggleMute;
  final double size;

  static const _start = 3 * math.pi / 4;
  static const _sweep = 3 * math.pi / 2;

  void handlePan(Offset local) {
    final center = Offset(size / 2, size / 2);
    final vector = local - center;
    if (vector.distance < 4) return;

    var relative = math.atan2(vector.dy, vector.dx) - _start;
    while (relative < 0) {
      relative += 2 * math.pi;
    }
    while (relative >= 2 * math.pi) {
      relative -= 2 * math.pi;
    }

    if (relative > _sweep) {
      onChanged(relative > _sweep + (2 * math.pi - _sweep) / 2 ? 0 : 1);
      return;
    }
    onChanged((relative / _sweep).clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggleMute,
      onPanUpdate: (details) => handlePan(details.localPosition),
      onPanDown: (details) => handlePan(details.localPosition),
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: value.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        builder: (context, animated, _) {
          final percent = (animated * 100).round();
          final muted = percent == 0;
          return SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: Size.square(size),
                  painter: _DialPainter(
                    value: animated,
                    palette: context.palette,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      muted
                          ? Icons.volume_off_rounded
                          : percent < 40
                          ? Icons.volume_down_rounded
                          : Icons.volume_up_rounded,
                      size: size * 0.16,
                      color: muted
                          ? context.palette.textSecondary
                          : context.palette.icon,
                    ),
                    const SizedBox(height: 2),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 180),
                      style: context.styleListTitle.copyWith(
                        fontSize: size * 0.2,
                        fontWeight: FontWeight.w700,
                        color: muted
                            ? context.palette.textSecondary
                            : context.palette.textPrimary,
                      ),
                      child: Text('$percent%'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  const _DialPainter({required this.value, required this.palette});

  final double value;
  final AcornPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final stroke = (size.width * 0.085).clamp(6.0, 10.0);
    final radius = size.width / 2 - stroke - 2;
    const start = VolumeDial._start;
    const sweep = VolumeDial._sweep;

    canvas.drawCircle(
      center,
      radius + stroke * 0.7,
      Paint()
        ..shader = palette.sunkenGradient.createShader(
          Rect.fromCircle(center: center, radius: radius + stroke * 0.7),
        ),
    );

    final track = Paint()
      ..color = palette.trackInactive.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    final active = Paint()
      ..color = palette.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    final glow = Paint()
      ..color = palette.accent.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke + 4
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      sweep,
      false,
      track,
    );

    if (value > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep * value,
        false,
        glow,
      );
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep * value,
        false,
        active,
      );
    }

    final thumbAngle = start + sweep * value;
    final thumb = Offset(
      center.dx + radius * math.cos(thumbAngle),
      center.dy + radius * math.sin(thumbAngle),
    );
    final thumbR = stroke * 0.85;
    canvas.drawCircle(
      thumb,
      thumbR + 3,
      Paint()
        ..color = palette.accent.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawCircle(thumb, thumbR, Paint()..color = palette.textPrimary);
  }

  @override
  bool shouldRepaint(_DialPainter old) =>
      old.value != value || old.palette != palette;
}
