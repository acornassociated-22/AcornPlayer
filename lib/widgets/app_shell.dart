import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../services/app_platform.dart';
import '../theme/acorn_palette.dart';
import 'desktop_playback_shortcuts.dart';
import 'desktop_title_bar.dart';

/// Mobile renders the screens full bleed; desktop puts the very same screens in
/// a frameless window under our own caption bar.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!AppPlatform.isDesktop) return child;

    // Material gives the caption bar above the navigator a real text style.
    final window = Material(
      color: context.palette.surface,
      child: Column(
        children: [const DesktopTitleBar(), Expanded(child: child)],
      ),
    );

    final framed = AppPlatform.needsResizeHandles
        ? DragToResizeArea(child: window)
        : window;
    return DesktopPlaybackShortcuts(child: framed);
  }
}
