import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/song.dart';
import '../services/artwork_cache.dart';
import '../theme/neu_style.dart';

/// Cover art for [song], falling back to the red-halo mark plus a note when
/// the file carries no picture.
class SongArtwork extends StatelessWidget {
  const SongArtwork({
    super.key,
    required this.song,
    this.radius = NeuStyle.radiusCard,
    this.iconSize = 40,
  });

  final Song song;
  final double radius;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: FutureBuilder<Uint8List?>(
        future: context.read<ArtworkCache>().load(song),
        builder: (context, snapshot) {
          final bytes = snapshot.data;
          if (bytes == null) return _Placeholder(iconSize: iconSize);
          return Image.memory(
            bytes,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            gaplessPlayback: true,
            errorBuilder: (context, _, _) => _Placeholder(iconSize: iconSize),
          );
        },
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.iconSize});

  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'promo/cover_fallback.png',
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
        ),
        ColoredBox(color: Colors.black.withValues(alpha: 0.28)),
        Center(
          child: Icon(
            Icons.music_note_rounded,
            size: iconSize,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
