import 'package:flutter/material.dart';

import '../services/lyrics_service.dart';
import '../theme/acorn_palette.dart';

/// Scrollable lyrics, highlighting the current line when they are synced.
class LyricsView extends StatelessWidget {
  const LyricsView({
    super.key,
    required this.lyrics,
    required this.position,
  });

  final Lyrics lyrics;
  final Duration position;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final current = lyrics.indexAt(position);
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      itemCount: lyrics.lines.length,
      itemBuilder: (context, index) {
        final active = lyrics.isSynced && index == current;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            lyrics.lines[index].text,
            textAlign: TextAlign.center,
            style: (active ? context.styleListTitle : context.styleListSubtitle)
                .copyWith(
                  color: active ? palette.accent : palette.textSecondary,
                  fontSize: active ? 16 : 14,
                ),
          ),
        );
      },
    );
  }
}
