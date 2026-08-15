import 'package:flutter/material.dart';

import '../models/song.dart';
import 'vinyl_card.dart';

/// Tappable library cell that uses the shared vinyl card face.
class SongGridCard extends StatefulWidget {
  const SongGridCard({
    super.key,
    required this.song,
    required this.isActive,
    required this.isPlaying,
    this.progress = 0,
    required this.onTap,
    this.onMore,
  });

  final Song song;
  final bool isActive;
  final bool isPlaying;
  final double progress;
  final VoidCallback onTap;
  final VoidCallback? onMore;

  @override
  State<SongGridCard> createState() => _SongGridCardState();
}

class _SongGridCardState extends State<SongGridCard> {
  bool _pressed = false;

  void handleTapDown(TapDownDetails _) => setState(() => _pressed = true);

  void handleTapUp(TapUpDetails _) => setState(() => _pressed = false);

  void handleTapCancel() => setState(() => _pressed = false);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: handleTapDown,
      onTapUp: handleTapUp,
      onTapCancel: handleTapCancel,
      onLongPress: widget.onMore,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: VinylCard(
          song: widget.song,
          isActive: widget.isActive,
          isPlaying: widget.isPlaying,
          progress: widget.progress,
        ),
      ),
    );
  }
}
