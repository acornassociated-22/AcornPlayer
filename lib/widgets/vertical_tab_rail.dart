import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'neu_container.dart';

/// Sideways tab strip. On narrow screens it is a floating pill; on wide screens
/// it becomes a full-height dock pinned to the left edge.
class VerticalTabRail extends StatelessWidget {
  const VerticalTabRail({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    this.dock = false,
    this.width = 46,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// Ubuntu-style dock: full height, flush with the left edge.
  final bool dock;
  final double width;

  static const double dockWidth = 72;

  @override
  Widget build(BuildContext context) {
    if (dock) return _DockRail(labels: labels, selectedIndex: selectedIndex, onSelected: onSelected);

    return Padding(
      padding: const EdgeInsets.only(left: 10, right: 4),
      child: NeuContainer(
        width: width,
        radius: width / 2,
        depth: 7,
        blur: 22,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 10, top: 4),
              child: _AppMark(size: 28),
            ),
            for (var index = 0; index < labels.length; index++)
              _RailTab(
                label: labels[index],
                isSelected: index == selectedIndex,
                onTap: () => onSelected(index),
              ),
          ],
        ),
      ),
    );
  }
}

class _DockRail extends StatelessWidget {
  const _DockRail({
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    // Fill comes from the shared desktop chrome; this is only the tab column.
    return SizedBox(
      width: VerticalTabRail.dockWidth,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 18, bottom: 12),
            child: _AppMark(size: 40),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var index = 0; index < labels.length; index++)
                  _RailTab(
                    label: labels[index],
                    isSelected: index == selectedIndex,
                    onTap: () => onSelected(index),
                    dock: true,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Rounded app mark used at the top of the rail.
class _AppMark extends StatelessWidget {
  const _AppMark({this.size = 36});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: Image.asset(
        'promo/app_icon.png',
        width: size,
        height: size,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}

class _RailTab extends StatelessWidget {
  const _RailTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.dock = false,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool dock;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: dock ? 28 : 22),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (dock)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: isSelected ? 3 : 0,
                height: isSelected ? 38 : 0,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            RotatedBox(
              quarterTurns: 3,
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: DefaultTextStyle.of(context).style.merge(
                  AppTextStyles.railLabel.copyWith(
                    color: isSelected
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                    fontSize: dock ? 13 : null,
                  ),
                ),
                child: Text(label),
              ),
            ),
            if (!dock) ...[
              const SizedBox(width: 6),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 2.5,
                height: isSelected ? 34 : 0,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
