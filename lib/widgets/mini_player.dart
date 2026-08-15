import 'package:flutter/material.dart';

import '../models/song.dart';
import '../state/settings_controller.dart';
import '../theme/acorn_palette.dart';
import '../theme/app_colors.dart';
import '../theme/neu_style.dart';
import '../state/player_controller.dart';
import 'home_indicator.dart';
import 'neu_icon_button.dart';
import 'playback_modes.dart';
import 'progress_bar.dart';
import 'song_artwork.dart';
import 'volume_dial.dart';

/// Bottom bar showing the current track. Narrow windows get a single play
/// button, wider ones get the full previous / play / next row.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({
    super.key,
    required this.song,
    required this.isPlaying,
    required this.onTogglePlay,
    required this.onTap,
    required this.position,
    required this.duration,
    required this.onSeek,
    required this.volume,
    required this.onVolume,
    required this.onToggleMute,
    this.onPrevious,
    this.onNext,
    this.repeat = QueueRepeat.off,
    this.shuffle = false,
    this.onToggleRepeat,
    this.onToggleShuffle,
    this.speed = 1,
    this.onCycleSpeed,
    this.embedded = false,
  });

  /// Below this width the bar stays in its compact, phone-sized form.
  static const double _wideBreakpoint = 600;

  final Song song;
  final bool isPlaying;
  final VoidCallback onTogglePlay;
  final VoidCallback onTap;
  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;
  final double volume;
  final ValueChanged<double> onVolume;
  final VoidCallback onToggleMute;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final QueueRepeat repeat;
  final bool shuffle;
  final VoidCallback? onToggleRepeat;
  final VoidCallback? onToggleShuffle;
  final double speed;
  final VoidCallback? onCycleSpeed;

  /// Painted by the desktop chrome; skip a second background.
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;
    final wave = TrackProgressBar(
      position: position,
      duration: duration,
      onSeek: onSeek,
      seed: song.id,
      isPlaying: isPlaying,
      compact: true,
    );

    return Container(
      decoration: embedded
          ? null
          : NeuStyle.dockPanel(
              shadowOffset: const Offset(0, -6),
              palette: context.palette,
            ).copyWith(
              borderRadius: isWide
                  ? null
                  : const BorderRadius.vertical(
                      top: Radius.circular(NeuStyle.radiusCard),
                    ),
            ),
      padding: isWide
          ? const EdgeInsets.fromLTRB(24, 12, 24, 12)
          : const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: onTap,
                child: SizedBox(
                  width: 54,
                  height: 54,
                  child: SongArtwork(song: song, radius: 12, iconSize: 22),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: GestureDetector(
                  onTap: onTap,
                  behavior: HitTestBehavior.opaque,
                  child: _TrackLabel(song: song),
                ),
              ),
              const SizedBox(width: 12),
              if (isWide &&
                  onToggleRepeat != null &&
                  onToggleShuffle != null &&
                  onCycleSpeed != null) ...[
                PlaybackModeBar(
                  repeat: repeat,
                  shuffle: shuffle,
                  speed: speed,
                  onToggleRepeat: onToggleRepeat!,
                  onToggleShuffle: onToggleShuffle!,
                  onCycleSpeed: onCycleSpeed!,
                  compact: true,
                ),
                const SizedBox(width: 12),
              ],
              if (isWide && onPrevious != null) ...[
                NeuIconButton(
                  icon: Icons.skip_previous_rounded,
                  size: 40,
                  iconSize: 19,
                  onPressed: onPrevious,
                ),
                const SizedBox(width: 12),
              ],
              NeuIconButton(
                icon: isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                size: 46,
                iconSize: 22,
                fill: AppColors.accent,
                iconColor: AppColors.textPrimary,
                glowColor: AppColors.accent,
                onPressed: onTogglePlay,
              ),
              if (isWide && onNext != null) ...[
                const SizedBox(width: 12),
                NeuIconButton(
                  icon: Icons.skip_next_rounded,
                  size: 40,
                  iconSize: 19,
                  onPressed: onNext,
                ),
              ],
              const SizedBox(width: 14),
              VolumeDial(
                value: volume,
                onChanged: onVolume,
                onToggleMute: onToggleMute,
                size: isWide ? 76 : 64,
              ),
            ],
          ),
          const SizedBox(height: 10),
          wave,
          if (!isWide) ...[const SizedBox(height: 10), const HomeIndicator()],
        ],
      ),
    );
  }
}

class _TrackLabel extends StatelessWidget {
  const _TrackLabel({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.t('nowPlaying'), style: context.styleMiniLabel),
        const SizedBox(height: 5),
        Text(
          song.artist,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.styleListTitle,
        ),
        const SizedBox(height: 2),
        Text(
          song.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.styleListSubtitle,
        ),
      ],
    );
  }
}
