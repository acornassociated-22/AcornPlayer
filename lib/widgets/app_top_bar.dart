import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'neu_icon_button.dart';

/// Shared header: round back button, centred title, round overflow button.
class AppTopBar extends StatelessWidget {
  const AppTopBar({
    super.key,
    required this.title,
    this.onBack,
    this.onMore,
    this.trailing,
  });

  final String title;
  final VoidCallback? onBack;
  final VoidCallback? onMore;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        NeuIconButton(
          icon: Icons.chevron_left,
          iconSize: 24,
          onPressed: onBack,
        ),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.appBarTitle,
          ),
        ),
        if (trailing != null) ...[
          trailing!,
          const SizedBox(width: 10),
        ],
        NeuIconButton(
          icon: Icons.more_horiz,
          iconSize: 20,
          iconColor: AppColors.icon,
          onPressed: onMore,
        ),
      ],
    );
  }
}
