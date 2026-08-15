import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/song.dart';
import '../state/library_controller.dart';
import '../state/player_controller.dart';
import '../state/settings_controller.dart';
import '../theme/acorn_palette.dart';
import '../theme/app_colors.dart';
import '../widgets/action_sheet.dart';
import '../widgets/album_carousel.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/home_indicator.dart';
import '../widgets/neu_icon_button.dart';
import '../widgets/playback_modes.dart';
import '../widgets/progress_bar.dart';
import '../widgets/volume_dial.dart';

const _designHeight = 844.0;
const _wideBreakpoint = 600.0;
const _phoneContentMaxWidth = 560.0;
const _desktopContentMaxWidth = 980.0;

/// Vertical rhythm of the reference design, scaled down in shorter windows.
const _gapTop = 34.0;
const _gapCover = 52.0;
const _gapDetails = 46.0;
const _gapProgress = 50.0;
const _gapTransport = 26.0;
const _gapBottom = 10.0;
const _coverHeight = 280.0;

/// Combined height of the rows that never shrink: app bar, track details, seek
/// bar, transport and the home pill. The cover gets whatever is left.
const _fixedRowsHeight = 226.0;

/// Full player: cover carousel, track details, seek bar and transport.
class NowPlayingScreen extends StatelessWidget {
  const NowPlayingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerController>();
    final library = context.watch<LibraryController>();
    final song = player.current;

    return Scaffold(
      backgroundColor: context.palette.background,
      body: SafeArea(
        child: song == null
            ? Center(
                child: Text(
                  context.t('nothingPlaying'),
                  style: context.styleTrackArtist,
                ),
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  LayoutBuilder(
                    builder: (context, box) {
                      // Every gap keeps its phone proportion: at the 844 design
                      // height the layout is unchanged, shorter windows tighten up.
                      final scale = (box.maxHeight / _designHeight).clamp(0.5, 1.0);
                      final wide = box.maxWidth >= _wideBreakpoint;
                      final gaps =
                          (_gapTop +
                                  _gapCover +
                                  _gapDetails +
                                  _gapProgress +
                                  _gapTransport) *
                              scale +
                          _gapBottom;
                      final maxCover = wide ? 380.0 : _coverHeight * scale;
                      final coverHeight =
                          (box.maxHeight -
                                  _fixedRowsHeight -
                                  gaps -
                                  (wide ? 0 : 128))
                              .clamp(120.0, maxCover);
                      final contentWidth = wide
                          ? math.min(box.maxWidth * 0.82, _desktopContentMaxWidth)
                          : _phoneContentMaxWidth;

                      return Center(
                        child: SizedBox(
                          width: contentWidth,
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              22,
                              _gapTop * scale,
                              22,
                              _gapBottom,
                            ),
                            child: Column(
                              children: [
                                AppTopBar(
                                  title: library.title,
                                  onBack: () => Navigator.of(context).maybePop(),
                                  onMore: () => _showMenu(context, library, song),
                                ),
                                SizedBox(height: _gapCover * scale),
                                _Cover(
                                  clip: wide,
                                  child: AlbumCarousel(
                                    songs: player.queue,
                                    currentIndex: player.index,
                                    onIndexChanged: player.playAt,
                                    height: coverHeight,
                                    wide: wide,
                                    isPlaying: player.isPlaying,
                                    progress: player.progress,
                                  ),
                                ),
                                SizedBox(height: _gapDetails * scale),
                                _TrackDetails(
                                  song: song,
                                  isLiked: library.isLiked(song),
                                  onToggleLike: () => library.toggleLike(song),
                                  onClose: () => Navigator.of(context).maybePop(),
                                ),
                                SizedBox(height: _gapProgress * scale),
                                TrackProgressBar(
                                  position: player.position,
                                  duration: player.duration,
                                  onSeek: player.seek,
                                  seed: song.id,
                                  isPlaying: player.isPlaying,
                                ),
                                const Spacer(),
                                PlaybackModeBar(
                                  repeat: player.repeat,
                                  shuffle: player.shuffle,
                                  speed: player.speed,
                                  onToggleRepeat: player.toggleRepeat,
                                  onToggleShuffle: player.toggleShuffle,
                                  onCycleSpeed: player.cycleSpeed,
                                ),
                                SizedBox(height: 16 * scale),
                                _TransportControls(
                                  isPlaying: player.isPlaying,
                                  onPrevious: player.previous,
                                  onTogglePlay: player.togglePlay,
                                  onNext: player.next,
                                  volume: player.volume,
                                  onVolume: player.setVolume,
                                  onToggleMute: player.toggleMute,
                                  wide: wide,
                                ),
                                SizedBox(height: _gapTransport * scale),
                                if (!wide) const HomeIndicator(),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const _TitleBarShade(),
                ],
              ),
      ),
    );
  }

  void _showMenu(BuildContext context, LibraryController library, Song song) {
    showActionSheet(
      context,
      title: song.title,
      items: [
        ActionSheetItem(
          icon: library.isLiked(song)
              ? Icons.favorite_border
              : Icons.favorite_rounded,
          label: library.isLiked(song)
              ? context.t('removeFromFavorites')
              : context.t('addToFavorites'),
          onTap: () => library.toggleLike(song),
        ),
        for (final playlist in library.playlists)
          ActionSheetItem(
            icon: Icons.playlist_add_rounded,
            label: context.t('addTo', {'name': playlist.name}),
            onTap: () => library.addToPlaylist(playlist.id, song),
          ),
      ],
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.clip, required this.child});

  final bool clip;
  final Widget child;

  @override
  Widget build(BuildContext context) => clip ? ClipRect(child: child) : child;
}

/// Same inward falloff the library well uses under the desktop caption bar.
class _TitleBarShade extends StatelessWidget {
  const _TitleBarShade();

  static const _spread = 32.0;
  static const _shadow = Color(0x991C1C1C);
  static const _clear = Color(0x001C1C1C);

  @override
  Widget build(BuildContext context) {
    return const Positioned(
      left: 0,
      right: 0,
      top: 0,
      height: _spread,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_shadow, _clear],
            ),
          ),
        ),
      ),
    );
  }
}

class _TrackDetails extends StatelessWidget {
  const _TrackDetails({
    required this.song,
    required this.isLiked,
    required this.onToggleLike,
    required this.onClose,
  });

  final Song song;
  final bool isLiked;
  final VoidCallback onToggleLike;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        NeuIconButton(
          icon: isLiked ? Icons.favorite_rounded : Icons.favorite_border,
          size: 38,
          iconSize: 18,
          iconColor: AppColors.accent,
          onPressed: onToggleLike,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Column(
              children: [
                Text(
                  song.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: context.styleTrackTitle,
                ),
                const SizedBox(height: 4),
                Text(
                  song.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: context.styleTrackArtist,
                ),
              ],
            ),
          ),
        ),
        NeuIconButton(
          icon: Icons.close,
          size: 34,
          iconSize: 16,
          depth: 4,
          blur: 8,
          onPressed: onClose,
        ),
      ],
    );
  }
}

class _TransportControls extends StatelessWidget {
  const _TransportControls({
    required this.isPlaying,
    required this.onPrevious,
    required this.onTogglePlay,
    required this.onNext,
    required this.volume,
    required this.onVolume,
    required this.onToggleMute,
    required this.wide,
  });

  final bool isPlaying;
  final VoidCallback onPrevious;
  final VoidCallback onTogglePlay;
  final VoidCallback onNext;
  final double volume;
  final ValueChanged<double> onVolume;
  final VoidCallback onToggleMute;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final buttons = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        NeuIconButton(
          icon: Icons.skip_previous_rounded,
          size: 48,
          iconSize: 22,
          onPressed: onPrevious,
        ),
        const SizedBox(width: 26),
        NeuIconButton(
          icon: isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          size: 68,
          iconSize: 32,
          depth: 7,
          blur: 16,
          fill: AppColors.accent,
          iconColor: AppColors.textPrimary,
          glowColor: AppColors.accent,
          onPressed: onTogglePlay,
        ),
        const SizedBox(width: 26),
        NeuIconButton(
          icon: Icons.skip_next_rounded,
          size: 48,
          iconSize: 22,
          onPressed: onNext,
        ),
      ],
    );

    final dial = VolumeDial(
      value: volume,
      onChanged: onVolume,
      onToggleMute: onToggleMute,
      size: wide ? 112 : 84,
    );

    if (!wide) {
      return Column(
        children: [
          buttons,
          const SizedBox(height: 18),
          dial,
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        buttons,
        const SizedBox(width: 36),
        dial,
      ],
    );
  }
}
