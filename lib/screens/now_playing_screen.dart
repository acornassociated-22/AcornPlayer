import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/song.dart';
import '../services/lyrics_service.dart';
import '../state/library_controller.dart';
import '../state/player_controller.dart';
import '../state/settings_controller.dart';
import '../theme/acorn_palette.dart';
import '../theme/app_colors.dart';
import '../widgets/action_sheet.dart';
import '../widgets/album_carousel.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/lyrics_view.dart';
import '../widgets/neu_icon_button.dart';
import '../widgets/playback_modes.dart';
import '../widgets/progress_bar.dart';
import '../widgets/queue_panel.dart';
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

/// Full player: cover carousel, track details, seek bar and transport.
class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  final _lyricsService = LyricsService();
  String? _lyricsSongId;
  Lyrics? _lyrics;
  bool _showLyrics = false;

  /// Loads lyrics whenever the current track changes.
  Future<void> _loadLyrics(Song? song) async {
    if (song == null || song.id == _lyricsSongId) return;
    _lyricsSongId = song.id;
    final lyrics = await _lyricsService.load(song);
    if (!mounted || _lyricsSongId != song.id) return;
    setState(() {
      _lyrics = lyrics;
      if (lyrics == null) _showLyrics = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerController>();
    final library = context.watch<LibraryController>();
    final song = player.current;
    _loadLyrics(song);

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
                      final scale = (box.maxHeight / _designHeight).clamp(0.4, 1.0);
                      final gapScale = scale < 0.8 ? scale * 0.7 : scale;
                      final wide = box.maxWidth >= _wideBreakpoint;
                      final maxCover = wide ? 380.0 : _coverHeight * scale;
                      final contentWidth = wide
                          ? math.min(box.maxWidth * 0.82, _desktopContentMaxWidth)
                          : _phoneContentMaxWidth;

                      return Center(
                        child: SizedBox(
                          width: contentWidth,
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              22,
                              _gapTop * gapScale,
                              22,
                              _gapBottom,
                            ),
                            child: Column(
                              children: [
                                AppTopBar(
                                  title: library.title,
                                  onBack: () => Navigator.of(context).maybePop(),
                                  trailing: NeuIconButton(
                                    icon: Icons.queue_music_rounded,
                                    iconSize: 18,
                                    onPressed: () => QueuePanel.open(context),
                                  ),
                                  onMore: () => _showMenu(
                                    context,
                                    library,
                                    player,
                                    song,
                                  ),
                                ),
                                SizedBox(height: _gapCover * gapScale),
                                Flexible(
                                  child: LayoutBuilder(
                                    builder: (context, coverBox) {
                                      final coverHeight = coverBox.maxHeight
                                          .clamp(80.0, maxCover);
                                      return _Cover(
                                        clip: wide,
                                        child: _showLyrics && _lyrics != null
                                            ? LyricsView(
                                                lyrics: _lyrics!,
                                                position: player.position,
                                              )
                                            : AlbumCarousel(
                                                songs: player.queue,
                                                currentIndex: player.index,
                                                onIndexChanged: player.playAt,
                                                height: coverHeight,
                                                wide: wide,
                                                isPlaying: player.isPlaying,
                                                progress: player.progress,
                                              ),
                                      );
                                    },
                                  ),
                                ),
                                SizedBox(height: _gapDetails * gapScale),
                                _TrackDetails(
                                  song: song,
                                  isLiked: library.isLiked(song),
                                  onToggleLike: () => library.toggleLike(song),
                                  onClose: () => Navigator.of(context).maybePop(),
                                ),
                                SizedBox(height: _gapProgress * gapScale),
                                TrackProgressBar(
                                  position: player.position,
                                  duration: player.duration,
                                  onSeek: player.seek,
                                  seed: song.id,
                                  isPlaying: player.isPlaying,
                                ),
                                SizedBox(height: 12 * gapScale),
                                PlaybackModeBar(
                                  repeat: player.repeat,
                                  shuffle: player.shuffle,
                                  speed: player.speed,
                                  onToggleRepeat: player.toggleRepeat,
                                  onToggleShuffle: player.toggleShuffle,
                                  onCycleSpeed: player.cycleSpeed,
                                ),
                                SizedBox(height: 12 * gapScale),
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
                                if (wide)
                                  SizedBox(height: _gapTransport * gapScale),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  if (MediaQuery.sizeOf(context).width >= _wideBreakpoint)
                    const _TitleBarShade(),
                ],
              ),
      ),
    );
  }

  void _showMenu(
    BuildContext context,
    LibraryController library,
    PlayerController player,
    Song song,
  ) {
    showActionSheet(
      context,
      title: song.title,
      items: [
        if (_lyrics != null)
          ActionSheetItem(
            icon: Icons.lyrics_outlined,
            label: _showLyrics ? context.t('showCover') : context.t('lyrics'),
            onTap: () => setState(() => _showLyrics = !_showLyrics),
          ),
        ActionSheetItem(
          icon: Icons.bedtime_outlined,
          label: player.sleep == SleepMode.off
              ? context.t('sleepTimer')
              : context.t('sleepOff'),
          onTap: () => _showSleepMenu(context, player),
        ),
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

  void _showSleepMenu(BuildContext context, PlayerController player) {
    showActionSheet(
      context,
      title: context.t('sleepTimer'),
      items: [
        ActionSheetItem(
          icon: Icons.timer_outlined,
          label: context.t('sleep15'),
          onTap: () => player.setSleep(SleepMode.minutes15),
        ),
        ActionSheetItem(
          icon: Icons.timer_outlined,
          label: context.t('sleep30'),
          onTap: () => player.setSleep(SleepMode.minutes30),
        ),
        ActionSheetItem(
          icon: Icons.timer_outlined,
          label: context.t('sleep60'),
          onTap: () => player.setSleep(SleepMode.minutes60),
        ),
        ActionSheetItem(
          icon: Icons.skip_next_outlined,
          label: context.t('sleepEndOfTrack'),
          onTap: () => player.setSleep(SleepMode.endOfTrack),
        ),
        ActionSheetItem(
          icon: Icons.timer_off_outlined,
          label: context.t('sleepOff'),
          onTap: () => player.setSleep(SleepMode.off),
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
