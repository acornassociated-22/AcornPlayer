import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/player_controller.dart';
import '../state/settings_controller.dart';
import '../theme/acorn_palette.dart';
import '../theme/neu_style.dart';
import 'neu_icon_button.dart';
import 'song_artwork.dart';

/// Side panel listing the play queue, with drag-to-reorder and remove.
abstract final class QueuePanel {
  static Future<void> open(BuildContext context) {
    return showGeneralDialog<void>(
      context: context,
      barrierLabel: context.t('queue'),
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (dialogContext, animation, secondary) {
        return _QueueSheet(animation: animation);
      },
      transitionBuilder: (context, animation, secondary, child) {
        return child;
      },
    );
  }
}

class _QueueSheet extends StatelessWidget {
  const _QueueSheet({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerController>();
    final palette = context.palette;
    final wide = MediaQuery.sizeOf(context).width >= 600;
    final width = wide
        ? (MediaQuery.sizeOf(context).width * 0.48).clamp(320.0, 440.0)
        : MediaQuery.sizeOf(context).width * 0.86;
    final slide = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

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
              ),
            ),
          ),
        ),
      ),
    );
  }
}
