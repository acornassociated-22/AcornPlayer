import 'package:flutter/material.dart';

import '../models/song.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/neu_style.dart';
import 'neu_container.dart';
import 'waveform_indicator.dart';

/// List row for one track. The active row is lifted into a soft card and shows
/// an equaliser, matching the reference design.
class SongTile extends StatelessWidget {
  const SongTile({
    super.key,
    required this.song,
    required this.isActive,
    required this.isPlaying,
    required this.onTap,
    this.onMore,
  });

  final Song song;
  final bool isActive;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      children: [
        if (isActive) ...[
          WaveformIndicator(animate: isPlaying),
          const SizedBox(width: 14),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                song.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.listTitle,
              ),
              const SizedBox(height: 3),
              Text(
                song.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.listSubtitle,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _MoreButton(onTap: onMore),
      ],
    );

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: isActive
            ? NeuContainer(
                radius: NeuStyle.radiusTile,
                depth: 4,
                blur: 9,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: content,
              )
            : Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: content,
              ),
      ),
    );
  }
}

class _MoreButton extends StatelessWidget {
  const _MoreButton({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: const SizedBox(
        width: 28,
        height: 28,
        child: Icon(Icons.more_horiz, size: 20, color: AppColors.icon),
      ),
    );
  }
}
