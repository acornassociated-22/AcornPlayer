import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/song.dart';
import '../state/library_controller.dart';
import '../state/settings_controller.dart';
import '../theme/acorn_palette.dart';
import '../theme/neu_style.dart';
import 'neu_icon_button.dart';
import 'song_artwork.dart';

/// Side panel that adds library tracks to the opened playlist.
abstract final class AddSongsPanel {
  static Future<void> open(BuildContext context, int playlistId) {
    return showGeneralDialog<void>(
      context: context,
      barrierLabel: context.t('addSongs'),
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (dialogContext, animation, secondary) {
        return _AddSongsSheet(animation: animation, playlistId: playlistId);
      },
      transitionBuilder: (context, animation, secondary, child) {
        return child;
      },
    );
  }
}

class _AddSongsSheet extends StatefulWidget {
  const _AddSongsSheet({required this.animation, required this.playlistId});

  final Animation<double> animation;
  final int playlistId;

  @override
  State<_AddSongsSheet> createState() => _AddSongsSheetState();
}

class _AddSongsSheetState extends State<_AddSongsSheet> {
  String _query = '';

  /// Filters the library by the local search box.
  List<Song> _matches(List<Song> songs) {
    final needle = _query.trim().toLowerCase();
    if (needle.isEmpty) return songs;
    return songs
        .where(
          (song) =>
              song.title.toLowerCase().contains(needle) ||
              song.artist.toLowerCase().contains(needle) ||
              (song.album?.toLowerCase().contains(needle) ?? false),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryController>();
    final palette = context.palette;
    final wide = MediaQuery.sizeOf(context).width >= 600;
    final width = wide
        ? (MediaQuery.sizeOf(context).width * 0.48).clamp(320.0, 440.0)
        : MediaQuery.sizeOf(context).width * 0.86;
    final slide = CurvedAnimation(
      parent: widget.animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final inPlaylist = library.openPlaylistSongIds;
    final songs = _matches(library.allSongs);

    return Material(
      type: MaterialType.transparency,
      child: Align(
        alignment: Alignment.centerRight,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(slide),
          child: SizedBox(
            width: width,
            height: double.infinity,
            child: DecoratedBox(
              decoration: NeuStyle.dockPanel(
                shadowOffset: const Offset(-8, 0),
                palette: palette,
              ),
              child: SafeArea(
                left: false,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              context.t('addSongs'),
                              style: context.styleAppBarTitle,
                            ),
                          ),
                          NeuIconButton(
                            icon: Icons.close_rounded,
                            size: 36,
                            iconSize: 16,
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: TextField(
                        onChanged: (value) => setState(() => _query = value),
                        onTapOutside: (_) =>
                            FocusManager.instance.primaryFocus?.unfocus(),
                        textInputAction: TextInputAction.search,
                        style: context.styleListTitle,
                        cursorColor: palette.accent,
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: context.t('searchHint'),
                          hintStyle: context.styleListSubtitle,
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    Expanded(
                      child: songs.isEmpty
                          ? Center(
                              child: Text(
                                library.allSongs.isEmpty
                                    ? context.t('noAudio')
                                    : context.t('noSearchResults'),
                                style: context.styleListSubtitle,
                              ),
                            )
                          : ListView.builder(
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              padding: const EdgeInsets.fromLTRB(8, 0, 8, 20),
                              itemCount: songs.length,
                              itemBuilder: (context, index) {
                                final song = songs[index];
                                final added = inPlaylist.contains(song.id);
                                return ListTile(
                                  leading: SizedBox(
                                    width: 40,
                                    height: 40,
                                    child: SongArtwork(
                                      song: song,
                                      radius: 8,
                                      iconSize: 16,
                                    ),
                                  ),
                                  title: Text(
                                    song.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.styleListTitle,
                                  ),
                                  subtitle: Text(
                                    song.artist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.styleListSubtitle,
                                  ),
                                  trailing: Icon(
                                    added
                                        ? Icons.check_rounded
                                        : Icons.add_rounded,
                                    color: added
                                        ? palette.accent
                                        : palette.icon,
                                  ),
                                  onTap: added
                                      ? null
                                      : () => library.addToPlaylist(
                                          widget.playlistId,
                                          song,
                                        ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
