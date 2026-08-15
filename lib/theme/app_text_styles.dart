import 'package:flutter/painting.dart';

import 'app_colors.dart';

/// Typography of the reference design. Sizes assume the 390x844 design frame.
abstract final class AppTextStyles {
  static const appBarTitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: 0.2,
  );

  static const trackTitle = TextStyle(
    fontSize: 19,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: 0.2,
  );

  static const trackArtist = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static const listTitle = TextStyle(
    fontSize: 14.5,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static const listSubtitle = TextStyle(
    fontSize: 11.5,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static const time = TextStyle(
    fontSize: 11.5,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  static const railLabel = TextStyle(
    fontSize: 12.5,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
  );

  static const miniLabel = TextStyle(
    fontSize: 10.5,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );
}
