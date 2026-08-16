import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/database.dart';
import '../models/song.dart';
import '../state/library_controller.dart';
import '../state/player_controller.dart';
import '../state/settings_controller.dart';
import '../theme/acorn_palette.dart';
import '../widgets/action_sheet.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/mini_player.dart';
import '../widgets/neu_container.dart';
import '../widgets/neu_icon_button.dart';
import '../widgets/add_songs_panel.dart';
import '../widgets/queue_panel.dart';
import '../widgets/settings_panel.dart';
import '../widgets/song_grid_card.dart';
import '../widgets/song_tile.dart';
import '../widgets/vertical_tab_rail.dart';
import 'now_playing_screen.dart';

const _contentMaxWidth = 1000.0;
const _wideBreakpoint = 600.0;

/// Labels for the side rail, matching [LibraryTab] order.
List<String> _tabLabels(BuildContext context) => [
  context.t('artists'),
  context.t('playlists'),
  context.t('songs'),
  context.t('favorites'),
];

/// Browsing screen: sideways tabs, the track list and the mini player.
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryController>();
    final player = context.watch<PlayerController>();
    final wide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;
    final labels = _tabLabels(context);

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
}

/// Asks for a name and creates a playlist.
Future<void> _createPlaylist(
  BuildContext context,
  LibraryController library,
) async {
  final name = await showNamePrompt(context, title: context.t('newPlaylist'));
  if (name == null || name.isEmpty) return;
  await library.createPlaylist(name);
}

/// Opens the side panel that adds library tracks to the opened playlist.
void _openAddSongs(BuildContext context, LibraryController library) {
  final playlistId = library.selectedPlaylistId;
  if (playlistId == null) return;
  AddSongsPanel.open(context, playlistId);
}

/// Picks how the current song list is ordered.
void _showSortMenu(BuildContext context, LibraryController library) {
  showActionSheet(
    context,
    title: context.t('sortBy'),
    items: [
      for (final sort in LibrarySort.values)
        ActionSheetItem(
          icon: library.sort == sort
              ? Icons.check_rounded
              : Icons.sort_rounded,
          label: context.t(switch (sort) {
            LibrarySort.title => 'sortTitle',
            LibrarySort.artist => 'sortArtist',
            LibrarySort.album => 'sortAlbum',
            LibrarySort.duration => 'sortDuration',
            LibrarySort.recent => 'sortRecent',
            LibrarySort.played => 'sortPlayed',
          }),
          onTap: () => library.setSort(sort),
        ),
    ],
  );
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

  /// Sort/grid on song views; a create button on the playlists list.
  Widget? _trailing(BuildContext context, LibraryController library) {
    final buttons = <Widget>[
      if (library.tab == LibraryTab.playlists &&
          library.selectedPlaylistId == null)
        NeuIconButton(
          icon: Icons.add_rounded,
          iconSize: 18,
          onPressed: () => _createPlaylist(context, library),
        ),
      if (library.tab == LibraryTab.playlists &&
          library.selectedPlaylistId != null)
        NeuIconButton(
          icon: Icons.playlist_add_rounded,
          iconSize: 18,
          onPressed: () => _openAddSongs(context, library),
        ),
      if (library.view == LibraryView.songs) ...[
        NeuIconButton(
          icon: Icons.sort_rounded,
          iconSize: 18,
          onPressed: () => _showSortMenu(context, library),
        ),
        NeuIconButton(
          icon: library.gridSongs
              ? Icons.view_list_rounded
              : Icons.grid_view_rounded,
          iconSize: 18,
          onPressed: library.toggleSongLayout,
        ),
      ],
    ];
    if (buttons.isEmpty) return null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < buttons.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          buttons[i],
        ],
      ],
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
                          trailing: _trailing(context, library),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.fromLTRB(28, 2, 28, 6),
                        child: Center(
                          child: SizedBox(
                            width: 360,
                            child: _SongSearchField(),
                          ),
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
                        trailing: _trailing(context, library),
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          VerticalTabRail(
                            labels: _tabLabels(context),
                            selectedIndex: library.tab.index,
                            onSelected: (index) =>
                                library.selectTab(LibraryTab.values[index]),
                            onSettings: () => SettingsPanel.open(context),
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    8,
                                    2,
                                    16,
                                    8,
                                  ),
                                  child: Center(
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 360,
                                      ),
                                      child: const _SongSearchField(),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: _Body(
                                    library: library,
                                    player: player,
                                  ),
                                ),
                              ],
                            ),
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
            onQueue: () => QueuePanel.open(context),
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

/// Sunken field that filters the current song list as the user types.
class _SongSearchField extends StatefulWidget {
  const _SongSearchField();

  @override
  State<_SongSearchField> createState() => _SongSearchFieldState();
}

class _SongSearchFieldState extends State<_SongSearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: context.read<LibraryController>().query,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Pushes the typed text into the library filter.
  void _handleChanged(String value) {
    context.read<LibraryController>().setQuery(value);
    setState(() {});
  }

  /// Clears both the field and the live filter.
  void _handleClear() {
    _controller.clear();
    context.read<LibraryController>().setQuery('');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return NeuContainer(
      sunken: true,
      radius: 16,
      depth: 2,
      blur: 6,
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 17, color: palette.icon),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _controller,
              onChanged: _handleChanged,
              onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
              onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
              style: context.styleMiniLabel.copyWith(
                color: palette.textPrimary,
                fontSize: 13,
              ),
              cursorColor: palette.accent,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: context.t('searchHint'),
                hintStyle: context.styleMiniLabel.copyWith(fontSize: 13),
              ),
            ),
          ),
          if (_controller.text.isNotEmpty)
            GestureDetector(
              onTap: _handleClear,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: palette.textSecondary,
                ),
              ),
            ),
        ],
      ),
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
      case LibraryStatus.scanning:
        return _ScanProgress(library: library);
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
          LibraryView.playlists => _PlaylistList(library: library),
          LibraryView.artists => _ArtistList(library: library),
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
      if (library.query.trim().isNotEmpty) {
        return _Notice(message: context.t('noSearchResults'));
      }
      if (library.selectedPlaylistId != null) {
        return _Notice(
          message: context.t('emptyPlaylist'),
          actionLabel: context.t('addSongs'),
          actionIcon: Icons.playlist_add_rounded,
          onAction: () => _openAddSongs(context, library),
        );
      }
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
          : library.selectedPlaylistId != null
          ? ReorderableListView.builder(
              key: const ValueKey('playlist'),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.only(right: 20, top: 4, bottom: 20),
              itemCount: songs.length,
              onReorderItem: library.reorderPlaylistSongs,
              itemBuilder: (context, index) {
                final song = songs[index];
                return SongTile(
                  key: ValueKey(song.id),
                  song: song,
                  isActive: player.current == song,
                  isPlaying: player.isPlaying,
                  onTap: () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    player.playQueue(songs, index);
                  },
                  onMore: () => _showSongMenu(context, song),
                );
              },
            )
          : ListView.builder(
              key: const ValueKey('list'),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.only(right: 20, top: 4, bottom: 20),
              itemCount: songs.length,
              itemBuilder: (context, index) {
                final song = songs[index];
                return SongTile(
                  song: song,
                  isActive: player.current == song,
                  isPlaying: player.isPlaying,
                  onTap: () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    player.playQueue(songs, index);
                  },
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
          icon: Icons.playlist_play_rounded,
          label: context.t('playNext'),
          onTap: () => player.playNext(song),
        ),
        ActionSheetItem(
          icon: Icons.queue_music_rounded,
          label: context.t('addToQueue'),
          onTap: () => player.addToQueue(song),
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
        if (library.selectedPlaylistId != null)
          ActionSheetItem(
            icon: Icons.remove_circle_outline_rounded,
            label: context.t('removeFromPlaylist'),
            onTap: () => library.removeFromPlaylist(
              library.selectedPlaylistId!,
              song,
            ),
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
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
          onTap: () {
            FocusManager.instance.primaryFocus?.unfocus();
            player.playQueue(songs, index);
          },
          onMore: () => onMore(song),
        );
      },
    );
  }
}

class _PlaylistList extends StatelessWidget {
  const _PlaylistList({required this.library});

  final LibraryController library;

  @override
  Widget build(BuildContext context) {
    final playlists = library.visiblePlaylists;
    if (playlists.isEmpty) {
      final searching = library.query.trim().isNotEmpty;
      return _Notice(
        message: searching
            ? context.t('noSearchResults')
            : context.t('noPlaylists'),
        actionLabel: searching ? null : context.t('newPlaylist'),
        actionIcon: Icons.add_rounded,
        onAction: searching ? null : () => _createPlaylist(context, library),
      );
    }

    return ListView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(right: 20, top: 4, bottom: 20),
      itemCount: playlists.length,
      itemBuilder: (context, index) => _CollectionRow(
        title: playlists[index].name,
        subtitle: context.t('songsCount', {
          'count': '${library.playlistCount(playlists[index].id)}',
        }),
        onTap: () => library.openPlaylist(playlists[index].id),
        onLongPress: () => _showPlaylistMenu(context, library, playlists[index]),
      ),
    );
  }
}

class _ArtistList extends StatelessWidget {
  const _ArtistList({required this.library});

  final LibraryController library;

  @override
  Widget build(BuildContext context) {
    final artists = library.visibleArtists;
    if (artists.isEmpty) {
      return _Notice(
        message: library.query.trim().isNotEmpty
            ? context.t('noSearchResults')
            : context.t('noArtists'),
      );
    }
    return ListView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(right: 20, top: 4, bottom: 20),
      itemCount: artists.length,
      itemBuilder: (context, index) => _CollectionRow(
        title: artists[index],
        subtitle: context.t('songsCount', {
          'count': '${library.songCountForArtist(artists[index])}',
        }),
        onTap: () => library.openArtist(artists[index]),
      ),
    );
  }
}

/// Lets the user rename or delete a playlist.
void _showPlaylistMenu(
  BuildContext context,
  LibraryController library,
  Playlist playlist,
) {
  showActionSheet(
    context,
    title: playlist.name,
    items: [
      ActionSheetItem(
        icon: Icons.edit_rounded,
        label: context.t('renamePlaylist'),
        onTap: () async {
          final name = await showNamePrompt(
            context,
            title: context.t('renamePlaylist'),
          );
          if (name == null || name.isEmpty) return;
          await library.renamePlaylist(playlist.id, name);
        },
      ),
      ActionSheetItem(
        icon: Icons.delete_outline_rounded,
        label: context.t('deletePlaylist'),
        onTap: () => library.deletePlaylist(playlist.id),
      ),
    ],
  );
}

class _ScanProgress extends StatelessWidget {
  const _ScanProgress({required this.library});

  final LibraryController library;

  @override
  Widget build(BuildContext context) {
    final total = library.scanTotal;
    final label = total == 0
        ? context.t('scanning')
        : '${context.t('scanning')} ${library.scanDone} / $total';
    return _Notice(
      message: label,
      actionLabel: context.t('cancelScan'),
      actionIcon: Icons.close_rounded,
      onAction: library.cancelScan,
    );
  }
}

class _CollectionRow extends StatelessWidget {
  const _CollectionRow({
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.onLongPress,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
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
