import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
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
    builder: (sheetContext) => Container(
      decoration: BoxDecoration(
        gradient: NeuStyle.surfaceGradient,
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
            style: AppTextStyles.appBarTitle,
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
                    Icon(item.icon, size: 19, color: AppColors.icon),
                    const SizedBox(width: 14),
                    Text(item.label, style: AppTextStyles.listTitle),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

/// Single-field prompt, used for naming a new playlist.
Future<String?> showNamePrompt(
  BuildContext context, {
  required String title,
}) {
  final controller = TextEditingController();

  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(title, style: AppTextStyles.appBarTitle),
      content: TextField(
        controller: controller,
        autofocus: true,
        style: AppTextStyles.listTitle,
        cursorColor: AppColors.accent,
        decoration: const InputDecoration(
          hintText: 'Name',
          hintStyle: AppTextStyles.listSubtitle,
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: AppColors.accent),
          ),
        ),
        onSubmitted: (value) => Navigator.of(dialogContext).pop(value.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text(
            'Cancel',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(dialogContext).pop(controller.text.trim()),
          child: const Text('Create', style: TextStyle(color: AppColors.accent)),
        ),
      ],
    ),
  );
}
