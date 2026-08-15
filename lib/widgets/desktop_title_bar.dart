import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../theme/acorn_palette.dart';
import '../theme/app_colors.dart';
import 'neu_icon_button.dart';

/// Caption bar of the frameless desktop window: drags the window, double-tap
/// maximises it and the round buttons replace the system ones.
class DesktopTitleBar extends StatelessWidget {
  const DesktopTitleBar({super.key});

  static const double height = 48;

  @override
  Widget build(BuildContext context) {
    return DragToMoveArea(
      child: SizedBox(
        height: height,
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.asset(
                    'promo/app_icon.png',
                    width: 22,
                    height: 22,
                    filterQuality: FilterQuality.high,
                  ),
                ),
                const SizedBox(width: 10),
                Text('Acorn Player', style: context.styleMiniLabel),
                const Spacer(),
                NeuIconButton(
                  icon: Icons.remove_rounded,
                  size: 26,
                  iconSize: 14,
                  depth: 3,
                  blur: 7,
                  onPressed: windowManager.minimize,
                ),
                const SizedBox(width: 10),
                NeuIconButton(
                  icon: Icons.crop_square_rounded,
                  size: 26,
                  iconSize: 12,
                  depth: 3,
                  blur: 7,
                  onPressed: handleToggleMaximize,
                ),
                const SizedBox(width: 10),
                NeuIconButton(
                  icon: Icons.close_rounded,
                  size: 26,
                  iconSize: 14,
                  depth: 3,
                  blur: 7,
                  iconColor: AppColors.accent,
                  onPressed: windowManager.close,
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Restores a maximised window, maximises a restored one.
  Future<void> handleToggleMaximize() async {
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
      return;
    }
    await windowManager.maximize();
  }
}
