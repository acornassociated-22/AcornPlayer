import 'package:flutter/material.dart';

import '../state/player_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'neu_container.dart';

/// Recessed neumorphic well of tappable labels. Selected items glow red;
/// they never lift into a button.
class PlaybackModeBar extends StatelessWidget {
  const PlaybackModeBar({
    super.key,
    required this.repeat,
    required this.shuffle,
    required this.speed,
    required this.onToggleRepeat,
    required this.onToggleShuffle,
    required this.onCycleSpeed,
    this.compact = false,
  });

  final QueueRepeat repeat;
  final bool shuffle;
  final double speed;
  final VoidCallback onToggleRepeat;
  final VoidCallback onToggleShuffle;
  final VoidCallback onCycleSpeed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return NeuContainer(
      sunken: true,
      radius: compact ? 18 : 22,
      depth: 3,
      blur: 8,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 14,
        vertical: compact ? 6 : 8,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModeLabel(
            icon: repeat == QueueRepeat.one
                ? Icons.repeat_one_rounded
                : Icons.repeat_rounded,
            label: switch (repeat) {
              QueueRepeat.off => 'Repeat',
              QueueRepeat.all => 'Repeat all',
              QueueRepeat.one => 'Repeat one',
            },
            active: repeat != QueueRepeat.off,
            compact: compact,
            onTap: onToggleRepeat,
          ),
          SizedBox(width: compact ? 12 : 18),
          _ModeLabel(
            icon: Icons.shuffle_rounded,
            label: 'Shuffle',
            active: shuffle,
            compact: compact,
            onTap: onToggleShuffle,
          ),
          SizedBox(width: compact ? 12 : 18),
          _ModeLabel(
            icon: Icons.speed_rounded,
            label: speed == 1 ? 'Speed' : '${_speedLabel(speed)} speed',
            active: speed != 1,
            compact: compact,
            onTap: onCycleSpeed,
          ),
        ],
      ),
    );
  }
}

class _ModeLabel extends StatelessWidget {
  const _ModeLabel({
    required this.icon,
    required this.label,
    required this.active,
    required this.compact,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.accent : AppColors.textSecondary;
    final style = (compact ? AppTextStyles.miniLabel : AppTextStyles.time)
        .copyWith(
          color: color,
          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          letterSpacing: 0.2,
          shadows: active
              ? [
                  Shadow(
                    color: AppColors.accent.withValues(alpha: 0.85),
                    blurRadius: 12,
                  ),
                ]
              : null,
        );

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 2 : 4,
          vertical: compact ? 4 : 6,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: compact ? 14 : 16, color: color),
            SizedBox(width: compact ? 5 : 7),
            Text(label, style: style),
          ],
        ),
      ),
    );
  }
}

/// Formats 1.25 as `1.25×` and 2.0 as `2×`.
String _speedLabel(double speed) {
  final text = speed == speed.roundToDouble()
      ? speed.toStringAsFixed(0)
      : speed.toString();
  return '$text×';
}
