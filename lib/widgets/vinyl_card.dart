import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/song.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/neu_style.dart';
import 'neu_container.dart';

/// Shared vinyl face used by the library grid and the Now Playing slider.
class VinylCard extends StatefulWidget {
  const VinylCard({
    super.key,
    required this.song,
    required this.isActive,
    required this.isPlaying,
    this.progress = 0,
  });

  final Song song;
  final bool isActive;
  final bool isPlaying;

  /// 0–1 playback progress drawn on the outer platter ring.
  final double progress;

  @override
  State<VinylCard> createState() => _VinylCardState();
}

class _VinylCardState extends State<VinylCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  );

  @override
  void initState() {
    super.initState();
    if (widget.isPlaying && widget.isActive) _spin.repeat();
  }

  @override
  void didUpdateWidget(VinylCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final shouldSpin = widget.isActive && widget.isPlaying;
    if (shouldSpin && !_spin.isAnimating) {
      _spin.repeat();
    } else if (!shouldSpin && _spin.isAnimating) {
      _spin.stop();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.isActive;
    return NeuContainer(
      radius: NeuStyle.radiusCard,
      depth: active ? 3 : 7,
      blur: active ? 10 : 18,
      padding: const EdgeInsets.fromLTRB(11, 11, 11, 11),
      glow: active
          ? NeuStyle.glow(AppColors.accent, blur: 22, opacity: 0.6)
          : null,
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: _Platter(
                  spin: _spin,
                  active: active,
                  progress: widget.progress,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _Nameplate(song: widget.song, active: active),
        ],
      ),
    );
  }
}

/// Sunken record with a raised hub; spins while this track is playing.
class _Platter extends StatelessWidget {
  const _Platter({
    required this.spin,
    required this.active,
    required this.progress,
  });

  final Animation<double> spin;
  final bool active;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return NeuContainer(
      sunken: true,
      circle: true,
      depth: 4,
      blur: 10,
      child: LayoutBuilder(
        builder: (context, box) {
          final size = box.biggest.shortestSide;
          final hub = (size * 0.42).clamp(48.0, 72.0);
          return Stack(
            alignment: Alignment.center,
            children: [
              RotationTransition(
                turns: spin,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: Size.square(size),
                      painter: _GroovePainter(active: active),
                    ),
                    NeuContainer(
                      circle: true,
                      width: hub,
                      height: hub,
                      depth: 5,
                      blur: 11,
                      glow: active
                          ? NeuStyle.glow(
                              AppColors.accent,
                              blur: 16,
                              opacity: 0.55,
                            )
                          : null,
                      child: Center(
                        child: Icon(
                          Icons.music_note_rounded,
                          size: hub * 0.42,
                          color: active ? AppColors.accent : AppColors.icon,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IgnorePointer(
                child: CustomPaint(
                  size: Size.square(size),
                  painter: _ProgressRingPainter(
                    progress: progress,
                    active: active,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Recessed caption: title, artist and duration.
class _Nameplate extends StatelessWidget {
  const _Nameplate({required this.song, required this.active});

  final Song song;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return NeuContainer(
      sunken: true,
      radius: 14,
      depth: 2,
      blur: 5,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            song.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.listTitle.copyWith(
              fontSize: 13,
              color: active ? AppColors.accent : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Expanded(
                child: Text(
                  song.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.listSubtitle,
                ),
              ),
              if (song.duration > Duration.zero) ...[
                const SizedBox(width: 6),
                Text(
                  _formatDuration(song.duration),
                  style: AppTextStyles.time.copyWith(fontSize: 10),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Outer platter ring: dim track plus the played arc.
class _ProgressRingPainter extends CustomPainter {
  const _ProgressRingPainter({
    required this.progress,
    required this.active,
  });

  final double progress;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    if (!active) return;

    const stroke = 3.4;
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - stroke / 2 - 1;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = AppColors.accent.withValues(alpha: 0.22);
    canvas.drawCircle(center, radius, track);

    final sweep = 2 * math.pi * progress.clamp(0.0, 1.0);
    if (sweep <= 0) return;

    final fill = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = AppColors.accent;
    canvas.drawArc(rect, -math.pi / 2, sweep, false, fill);
  }

  @override
  bool shouldRepaint(_ProgressRingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.active != active;
}

/// Fine concentric grooves on the platter.
class _GroovePainter extends CustomPainter {
  const _GroovePainter({required this.active});

  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxR = size.shortestSide / 2 - 6;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 0; i < 7; i++) {
      final t = (i + 1) / 8;
      paint.color = (active ? AppColors.accent : AppColors.shadowDark)
          .withValues(alpha: active ? 0.10 : 0.22);
      canvas.drawCircle(center, maxR * t, paint);
    }
  }

  @override
  bool shouldRepaint(_GroovePainter oldDelegate) =>
      oldDelegate.active != active;
}

/// Formats 3:05 from a duration.
String _formatDuration(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
