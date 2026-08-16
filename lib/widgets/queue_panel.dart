import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/player_controller.dart';
import '../state/settings_controller.dart';
import '../theme/acorn_palette.dart';
import '../theme/neu_style.dart';
import 'neu_icon_button.dart';
import 'song_artwork.dart';

/// Bottom sheet listing the play queue, with drag-to-reorder and remove.
abstract final class QueuePanel {
  static Future<void> open(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => const _QueueSheet(),
    );
  }
}

class _QueueSheet extends StatelessWidget {
  const _QueueSheet();

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerController>();
    final palette = context.palette;
    final height = MediaQuery.sizeOf(context).height * 0.62;

    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: palette.surfaceGradient,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(NeuStyle.radiusCard),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.t('queue'),
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
          Expanded(
            child: player.queue.isEmpty
                ? Center(
                    child: Text(
                      context.t('nothingPlaying'),
                      style: context.styleListSubtitle,
                    ),
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 20),
                    itemCount: player.queue.length,
                    onReorderItem: player.reorder,
                    itemBuilder: (context, index) {
                      final song = player.queue[index];
                      final active = index == player.index;
                      return ListTile(
                        key: ValueKey('${song.id}-$index'),
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
                          style: context.styleListTitle.copyWith(
                            color: active
                                ? palette.accent
                                : palette.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.styleListSubtitle,
                        ),
                        trailing: IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: palette.icon,
                          ),
                          onPressed: () => player.removeAt(index),
                        ),
                        onTap: () => player.playAt(index),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
