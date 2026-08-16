import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/settings_controller.dart';
import '../theme/acorn_palette.dart';
import '../theme/app_text_styles.dart';
import 'neu_container.dart';
import 'neu_icon_button.dart';

/// Sideways tab strip. On narrow screens it is a floating pill; on wide screens
/// it becomes a full-height dock pinned to the left edge.
class VerticalTabRail extends StatelessWidget {
  const VerticalTabRail({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    this.onSettings,
    this.dock = false,
    this.width = 46,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback? onSettings;

  /// Ubuntu-style dock: full height, flush with the left edge.
  final bool dock;
  final double width;

  static const double dockWidth = 72;

  @override
  Widget build(BuildContext context) {
    if (dock) {
      return _DockRail(
        labels: labels,
        selectedIndex: selectedIndex,
        onSelected: onSelected,
        onSettings: onSettings,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(left: 10, right: 4),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height - 180,
        ),
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
              Flexible(
                child: _CenteredTabList(
                  labels: labels,
                  selectedIndex: selectedIndex,
                  onSelected: onSelected,
                ),
              ),
              if (onSettings != null) ...[
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: _ThemeSlider(compact: true),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: NeuIconButton(
                    icon: Icons.settings_rounded,
                    size: 36,
                    iconSize: 18,
                    onPressed: onSettings,
                  ),
                ),
              ],
            ],
          ),
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
    this.onSettings,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback? onSettings;

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
            child: _CenteredTabList(
              labels: labels,
              selectedIndex: selectedIndex,
              onSelected: onSelected,
              dock: true,
            ),
          ),
          if (onSettings != null) ...[
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: _ThemeSlider(),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: NeuIconButton(
                icon: Icons.settings_rounded,
                iconSize: 20,
                onPressed: onSettings,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Compact Light/Dark switch that sits just above the settings gear.
class _ThemeSlider extends StatelessWidget {
  const _ThemeSlider({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = compact ? 36.0 : 40.0;
    final height = compact ? 20.0 : 22.0;
    final thumb = height - 4;

    return GestureDetector(
      onTap: () => settings.toggleLightDark(
        MediaQuery.platformBrightnessOf(context),
      ),
      child: NeuContainer(
        sunken: true,
        width: width,
        height: height,
        radius: height / 2,
        depth: 3,
        blur: 6,
        padding: const EdgeInsets.all(2),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: isDark ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: thumb,
            height: thumb,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: context.palette.surfaceGradient,
              boxShadow: [
                BoxShadow(
                  color: context.palette.shadowDark.withValues(alpha: 0.35),
                  blurRadius: 3,
                  offset: const Offset(1, 1),
                ),
              ],
            ),
            child: Icon(
              isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              size: compact ? 10 : 11,
              color: context.palette.accent,
            ),
          ),
        ),
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

/// Tab labels sit in the middle of the rail; they still scroll if they overflow.
class _CenteredTabList extends StatelessWidget {
  const _CenteredTabList({
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    this.dock = false,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool dock;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var index = 0; index < labels.length; index++)
                  _RailTab(
                    label: labels[index],
                    isSelected: index == selectedIndex,
                    onTap: () => onSelected(index),
                    dock: dock,
                  ),
              ],
            ),
          ),
        );
      },
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
    final bar = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: dock ? 3 : 2.5,
      height: isSelected ? (dock ? 38 : 34) : 0,
      decoration: BoxDecoration(
        color: context.palette.accent,
        borderRadius: BorderRadius.circular(2),
      ),
    );

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: dock ? 14 : 12),
        child: SizedBox(
          width: double.infinity,
          child: Stack(
            alignment: Alignment.center,
            children: [
              RotatedBox(
                quarterTurns: 3,
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: DefaultTextStyle.of(context).style.merge(
                    AppTextStyles.railLabel.copyWith(
                      color: isSelected
                          ? context.palette.textPrimary
                          : context.palette.textSecondary,
                      fontSize: dock ? 13 : null,
                    ),
                  ),
                  child: Text(label),
                ),
              ),
              Positioned(
                left: dock ? 8 : null,
                right: dock ? null : 4,
                child: bar,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
