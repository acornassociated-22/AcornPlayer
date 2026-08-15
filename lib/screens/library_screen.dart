import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/song.dart';
import '../state/library_controller.dart';
import '../state/player_controller.dart';
import '../state/settings_controller.dart';
import '../theme/acorn_palette.dart';
import '../widgets/action_sheet.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/mini_player.dart';
import '../widgets/neu_icon_button.dart';
import '../widgets/settings_panel.dart';
import '../widgets/song_grid_card.dart';
import '../widgets/song_tile.dart';
import '../widgets/vertical_tab_rail.dart';
import 'now_playing_screen.dart';

const _contentMaxWidth = 1000.0;
const _wideBreakpoint = 600.0;

/// Browsing screen: sideways tabs, the track list and the mini player.
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryController>();
    final player = context.watch<PlayerController>();
    final wide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;
    final labels = [
      context.t('albums'),
      context.t('playlists'),
      context.t('songs'),
      context.t('favorites'),
    ];

    final main = _LibraryMain(
      library: library,
      player: player,
      wide: wide,
      onMenu: () => _showMenu(context, library),
    );

    return Scaffold(
      backgroundColor: wide
          ? context.palette.surface
          : context.palette.background,
      body: SafeArea(
        bottom: false,
        left: !wide,
        child: wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  VerticalTabRail(
                    labels: labels,
                    selectedIndex: library.tab.index,
                    onSelected: (index) =>
                        library.selectTab(LibraryTab.values[index]),
                    onSettings: () => SettingsPanel.open(context),
                    dock: true,
                  ),
                  Expanded(child: main),
                ],
              )
            : main,
      ),
    );
  }

  void _showMenu(BuildContext context, LibraryController library) {
    showActionSheet(
      context,
      title: context.t('library'),
      items: [
        ActionSheetItem(
          icon: Icons.playlist_add_rounded,
          label: context.t('newPlaylist'),
          onTap: () => _createPlaylist(context, library),
        ),
        ActionSheetItem(
          icon: Icons.refresh_rounded,
          label: context.t('rescanLibrary'),
          onTap: library.refresh,
        ),
        ActionSheetItem(
          icon: Icons.folder_open_rounded,
          label: context.t('changeMusicFolder'),
          onTap: library.pickFolder,
        ),
      ],
    );
  }

  Future<void> _createPlaylist(
    BuildContext context,
    LibraryController library,
  ) async {
    final name = await showNamePrompt(context, title: context.t('newPlaylist'));
    if (name == null || name.isEmpty) return;
    await library.createPlaylist(name);
  }
}

class _LibraryMain extends StatelessWidget {
  const _LibraryMain({
    required this.library,
    required this.player,
    required this.wide,
    required this.onMenu,
  });

  final LibraryController library;
  final PlayerController player;
  final bool wide;
  final VoidCallback onMenu;

  /// List/grid toggle, only on song views.
  Widget? _layoutToggle(LibraryController library) {
    if (library.view != LibraryView.songs) return null;
    return NeuIconButton(
      icon: library.gridSongs
          ? Icons.view_list_rounded
          : Icons.grid_view_rounded,
      iconSize: 18,
      onPressed: library.toggleSongLayout,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: wide
              ? _ChromeWell(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(28, 18, 28, 6),
                        child: AppTopBar(
                          title: library.titleFor(context.strings),
                          onBack: library.canGoBack ? library.goBack : null,
                          onMore: onMenu,
                          trailing: _layoutToggle(library),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: _contentMaxWidth,
                            ),
                            child: _Body(library: library, player: player),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 34, 22, 6),
                      child: AppTopBar(
                        title: library.titleFor(context.strings),
                        onBack: library.canGoBack ? library.goBack : null,
                        onMore: onMenu,
                        trailing: _layoutToggle(library),
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          VerticalTabRail(
                            labels: [
                              context.t('albums'),
                              context.t('playlists'),
                              context.t('songs'),
                              context.t('favorites'),
                            ],
                            selectedIndex: library.tab.index,
                            onSelected: (index) =>
                                library.selectTab(LibraryTab.values[index]),
                            onSettings: () => SettingsPanel.open(context),
                          ),
                          Expanded(
                            child: _Body(library: library, player: player),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
        if (player.hasTrack)
          MiniPlayer(
            song: player.current!,
            isPlaying: player.isPlaying,
            onTogglePlay: player.togglePlay,
            onPrevious: player.previous,
            onNext: player.next,
            position: player.position,
            duration: player.duration,
            onSeek: player.seek,
            volume: player.volume,
            onVolume: player.setVolume,
            onToggleMute: player.toggleMute,
            repeat: player.repeat,
            shuffle: player.shuffle,
            onToggleRepeat: player.toggleRepeat,
            onToggleShuffle: player.toggleShuffle,
            speed: player.speed,
            onCycleSpeed: player.cycleSpeed,
            embedded: wide,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NowPlayingScreen()),
            ),
          ),
      ],
    );
  }
}

/// List well inset into the U-shaped chrome. Shadows fall inward from the
/// title bar (down), the dock (right) and the player bar (up).
class _ChromeWell extends StatelessWidget {
  const _ChromeWell({required this.child});

  final Widget child;

  static const _spread = 32.0;
  static const _shadow = Color(0x991C1C1C);
  static const _clear = Color(0x001C1C1C);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ColoredBox(color: context.palette.background, child: const SizedBox.expand()),
        child,
        const Positioned(
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
        ),
        const Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: _spread,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [_shadow, _clear]),
              ),
            ),
          ),
        ),
        const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: _spread,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [_shadow, _clear],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.library, required this.player});

  final LibraryController library;
  final PlayerController player;

  @override
  Widget build(BuildContext context) {
    switch (library.status) {
      case LibraryStatus.loading:
        return Center(
          child: CircularProgressIndicator(color: context.palette.accent),
        );
      case LibraryStatus.needsPermission:
        return _Notice(
          message: context.t('needsPermission'),
          actionLabel: context.t('grantAccess'),
          actionIcon: Icons.lock_open_rounded,
          onAction: library.initialise,
        );
      case LibraryStatus.needsFolder:
        return _Notice(
          message: context.t('needsFolder'),
          actionLabel: context.t('chooseFolder'),
          onAction: library.pickFolder,
        );
      case LibraryStatus.ready:
        return switch (library.view) {
          LibraryView.songs => _SongList(library: library, player: player),
          LibraryView.albums => _AlbumList(library: library),
          LibraryView.playlists => _PlaylistList(library: library),
        };
    }
  }
}

class _SongList extends StatelessWidget {
  const _SongList({required this.library, required this.player});

  final LibraryController library;
  final PlayerController player;

  @override
  Widget build(BuildContext context) {
    final songs = library.visibleSongs;
    if (songs.isEmpty) {
      return _Notice(
        message: library.tab == LibraryTab.favorites || library.likedOnly
            ? context.t('noFavorites')
            : context.t('noAudio'),
        actionLabel: library.tab == LibraryTab.favorites || library.likedOnly
            ? null
            : context.t('chooseFolder'),
        onAction: library.tab == LibraryTab.favorites || library.likedOnly
            ? null
            : library.pickFolder,
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(animation),
            child: child,
          ),
        );
      },
      child: library.gridSongs
          ? _SongGrid(
              key: const ValueKey('grid'),
              songs: songs,
              player: player,
              onMore: (song) => _showSongMenu(context, song),
            )
          : ListView.builder(
              key: const ValueKey('list'),
              padding: const EdgeInsets.only(right: 20, top: 4, bottom: 20),
              itemCount: songs.length,
              itemBuilder: (context, index) {
                final song = songs[index];
                return SongTile(
                  song: song,
                  isActive: player.current == song,
                  isPlaying: player.isPlaying,
                  onTap: () => player.playQueue(songs, index),
                  onMore: () => _showSongMenu(context, song),
                );
              },
            ),
    );
  }

  void _showSongMenu(BuildContext context, Song song) {
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

class _SongGrid extends StatelessWidget {
  const _SongGrid({
    super.key,
    required this.songs,
    required this.player,
    required this.onMore,
  });

  final List<Song> songs;
  final PlayerController player;
  final ValueChanged<Song> onMore;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 10, 22, 22),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: wide ? 4 : 2,
        mainAxisSpacing: 18,
        crossAxisSpacing: 16,
        childAspectRatio: 0.72,
      ),
      itemCount: songs.length,
      itemBuilder: (context, index) {
        final song = songs[index];
        return SongGridCard(
          song: song,
          isActive: player.current == song,
          isPlaying: player.isPlaying,
          progress: player.current == song ? player.progress : 0,
          onTap: () => player.playQueue(songs, index),
          onMore: () => onMore(song),
        );
      },
    );
  }
}

class _AlbumList extends StatelessWidget {
  const _AlbumList({required this.library});

  final LibraryController library;

  @override
  Widget build(BuildContext context) {
    final albums = library.albums;
    if (albums.isEmpty) {
      return _Notice(message: context.t('noAlbums'));
    }

    return ListView.builder(
      padding: const EdgeInsets.only(right: 20, top: 4, bottom: 20),
      itemCount: albums.length,
      itemBuilder: (context, index) => _CollectionRow(
        title: albums[index],
        subtitle: context.t('songsCount', {
          'count': '${library.songCountInAlbum(albums[index])}',
        }),
        onTap: () => library.openAlbum(albums[index]),
      ),
    );
  }
}

class _PlaylistList extends StatelessWidget {
  const _PlaylistList({required this.library});

  final LibraryController library;

  @override
  Widget build(BuildContext context) {
    final playlists = library.playlists;
    if (playlists.isEmpty) {
      return _Notice(message: context.t('noPlaylists'));
    }

    return ListView.builder(
      padding: const EdgeInsets.only(right: 20, top: 4, bottom: 20),
      itemCount: playlists.length,
      itemBuilder: (context, index) => _CollectionRow(
        title: playlists[index].name,
        subtitle: context.t('playlist'),
        onTap: () => library.openPlaylist(playlists[index].id),
      ),
    );
  }
}

class _CollectionRow extends StatelessWidget {
  const _CollectionRow({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 17),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.styleListTitle,
                  ),
                  const SizedBox(height: 3),
                  Text(subtitle, style: context.styleListSubtitle),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: context.palette.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.message,
    this.actionLabel,
    this.onAction,
    this.actionIcon = Icons.folder_open_rounded,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData actionIcon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 28, 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.styleListSubtitle,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              GestureDetector(
                onTap: onAction,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    NeuIconButton(icon: actionIcon),
                    const SizedBox(width: 12),
                    Text(actionLabel!, style: context.styleListTitle),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
