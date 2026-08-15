import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// WhatsApp / Signal style seek bar: a waveform that fills as the track plays,
/// with a glass reflection underneath.
class TrackProgressBar extends StatefulWidget {
  const TrackProgressBar({
    super.key,
    required this.position,
    required this.duration,
    required this.onSeek,
    this.seed = '',
    this.isPlaying = false,
    this.compact = false,
  });

  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;

  /// Stable per-track key so each song keeps its own wave shape.
  final String seed;
  final bool isPlaying;

  /// Shorter wave, used in the bottom player bar.
  final bool compact;

  @override
  State<TrackProgressBar> createState() => _TrackProgressBarState();
}

class _TrackProgressBarState extends State<TrackProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    if (widget.isPlaying) _pulse.repeat();
  }

  @override
  void didUpdateWidget(TrackProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !_pulse.isAnimating) {
      _pulse.repeat();
    } else if (!widget.isPlaying && _pulse.isAnimating) {
      _pulse.stop();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void handleSeek(Offset local, double width) {
    final total = widget.duration.inMilliseconds;
    if (total <= 0 || width <= 0) return;
    final t = (local.dx / width).clamp(0.0, 1.0);
    widget.onSeek(Duration(milliseconds: (total * t).round()));
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.duration.inMilliseconds.toDouble();
    final progress = total <= 0
        ? 0.0
        : (widget.position.inMilliseconds / total).clamp(0.0, 1.0);

    final waveHeight = widget.compact ? 36.0 : 56.0;
    final times = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(formatDuration(widget.position), style: AppTextStyles.time),
        Text(formatDuration(widget.duration), style: AppTextStyles.time),
      ],
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: waveHeight,
          child: LayoutBuilder(
            builder: (context, box) {
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) =>
                    handleSeek(details.localPosition, box.maxWidth),
                onHorizontalDragUpdate: (details) =>
                    handleSeek(details.localPosition, box.maxWidth),
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, _) => CustomPaint(
                    size: Size(box.maxWidth, waveHeight),
                    painter: _WavePainter(
                      samples: waveformSamples(widget.seed),
                      progress: progress,
                      pulse: widget.isPlaying ? _pulse.value : 0,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (!widget.compact) Padding(padding: const EdgeInsets.only(top: 6), child: times),
      ],
    );
  }
}

const _sampleCount = 64;

/// Builds a deterministic envelope so the same track always looks the same.
List<double> waveformSamples(String seed) {
  var hash = seed.hashCode == 0 ? 1 : seed.hashCode;
  final samples = <double>[];
  for (var i = 0; i < _sampleCount; i++) {
    hash = (1103515245 * hash + 12345) & 0x7fffffff;
    final noise = (hash % 1000) / 1000;
    final envelope = math.sin((i + 0.5) / _sampleCount * math.pi);
    samples.add(
      (0.18 + 0.82 * noise * (0.28 + 0.72 * envelope)).clamp(0.16, 1.0),
    );
  }
  return samples;
}

class _WavePainter extends CustomPainter {
  const _WavePainter({
    required this.samples,
    required this.progress,
    required this.pulse,
  });

  final List<double> samples;
  final double progress;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    const barWidth = 3.0;
    const gap = 2.4;
    final stride = barWidth + gap;
    final count = math.max(8, ((size.width + gap) / stride).floor());
    final waveHeight = size.height * 0.58;
    final mirrorHeight = size.height * 0.34;
    final glassY = waveHeight + 2;

    for (var i = 0; i < count; i++) {
      final t = (i + 0.5) / count;
      final sample = _sampleAt(t);
      final live = _liveGain(t);
      final h = waveHeight * sample * live;
      final x = i * stride;
      final played = t <= progress;
      final color = played ? AppColors.accent : AppColors.trackInactive;

      final bar = RRect.fromLTRBR(
        x,
        waveHeight - h,
        x + barWidth,
        waveHeight,
        const Radius.circular(1.6),
      );
      canvas.drawRRect(bar, Paint()..color = color);

      // Glass reflection: flipped, fading as it goes down.
      final fade = lerpDouble(0.38, 0.04, sample)!;
      final rh = mirrorHeight * sample * live * 0.85;
      final mirror = RRect.fromLTRBR(
        x,
        glassY,
        x + barWidth,
        glassY + rh,
        const Radius.circular(1.6),
      );
      canvas.drawRRect(
        mirror,
        Paint()..color = color.withValues(alpha: fade),
      );
    }

    // Thin highlight where the wave meets the glass.
    canvas.drawRect(
      Rect.fromLTWH(0, glassY - 0.6, size.width, 1.1),
      Paint()..color = const Color(0x33FFFFFF),
    );
  }

  double _sampleAt(double t) {
    final pos = t * (samples.length - 1);
    final i = pos.floor().clamp(0, samples.length - 2);
    return lerpDouble(samples[i], samples[i + 1], pos - i)!;
  }

  /// Raises and lowers bars around the playhead so the wave "breathes".
  double _liveGain(double t) {
    if (pulse <= 0) return 1;
    final distance = (t - progress).abs();
    final near = (1 - (distance / 0.18).clamp(0.0, 1.0));
    final wobble = 0.5 + 0.5 * math.sin(pulse * 2 * math.pi + t * 18);
    return 1 + near * 0.28 * (wobble * 2 - 1);
  }

  @override
  bool shouldRepaint(_WavePainter old) =>
      old.progress != progress ||
      old.pulse != pulse ||
      old.samples != samples;
}

/// Formats as `m:ss`, or `h:mm:ss` for tracks over an hour.
String formatDuration(Duration duration) {
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (duration.inHours > 0) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    return '${duration.inHours}:$minutes:$seconds';
  }
  return '${duration.inMinutes}:$seconds';
}
