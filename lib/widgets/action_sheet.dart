import 'package:flutter/material.dart';

import '../state/settings_controller.dart';
import '../theme/acorn_palette.dart';
import '../theme/neu_style.dart';

class ActionSheetItem {
  const ActionSheetItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

/// Soft-UI bottom sheet used by every overflow menu in the app.
Future<void> showActionSheet(
  BuildContext context, {
  required String title,
  required List<ActionSheetItem> items,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final palette = sheetContext.palette;
      return Container(
        decoration: BoxDecoration(
          gradient: palette.surfaceGradient,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(NeuStyle.radiusCard),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: sheetContext.styleAppBarTitle,
            ),
            const SizedBox(height: 14),
            for (final item in items)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  item.onTap();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  child: Row(
                    children: [
                      Icon(item.icon, size: 19, color: palette.icon),
                      const SizedBox(width: 14),
                      Text(item.label, style: sheetContext.styleListTitle),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

/// Single-field prompt, used for naming a new playlist.
Future<String?> showNamePrompt(
  BuildContext context, {
  required String title,
}) {
  final controller = TextEditingController();
  final palette = context.palette;

  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: dialogContext.palette.surface,
      title: Text(title, style: dialogContext.styleAppBarTitle),
      content: TextField(
        controller: controller,
        autofocus: true,
        style: dialogContext.styleListTitle,
        cursorColor: palette.accent,
        decoration: InputDecoration(
          hintText: dialogContext.t('name'),
          hintStyle: dialogContext.styleListSubtitle,
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: palette.accent),
          ),
        ),
        onSubmitted: (value) => Navigator.of(dialogContext).pop(value.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(
            dialogContext.t('cancel'),
            style: TextStyle(color: dialogContext.palette.textSecondary),
          ),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(dialogContext).pop(controller.text.trim()),
          child: Text(
            dialogContext.t('create'),
            style: TextStyle(color: dialogContext.palette.accent),
          ),
        ),
      ],
    ),
  );
}
