import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';

/// Light and dark neumorphic palettes, attached as a [ThemeExtension].
@immutable
class AcornPalette extends ThemeExtension<AcornPalette> {
  const AcornPalette({
    required this.background,
    required this.surface,
    required this.shadowDark,
    required this.shadowLight,
    required this.accent,
    required this.textPrimary,
    required this.textSecondary,
    required this.icon,
    required this.trackInactive,
    required this.surfaceGradient,
    required this.sunkenGradient,
  });

  final Color background;
  final Color surface;
  final Color shadowDark;
  final Color shadowLight;
  final Color accent;
  final Color textPrimary;
  final Color textSecondary;
  final Color icon;
  final Color trackInactive;
  final LinearGradient surfaceGradient;
  final LinearGradient sunkenGradient;

  static const dark = AcornPalette(
    background: AppColors.background,
    surface: AppColors.surface,
    shadowDark: AppColors.shadowDark,
    shadowLight: AppColors.shadowLight,
    accent: AppColors.accent,
    textPrimary: AppColors.textPrimary,
    textSecondary: AppColors.textSecondary,
    icon: AppColors.icon,
    trackInactive: AppColors.trackInactive,
    surfaceGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF333333), Color(0xFF272727)],
    ),
    sunkenGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF262626), Color(0xFF323232)],
    ),
  );

  static const light = AcornPalette(
    background: Color(0xFFE4E4E4),
    surface: Color(0xFFE8E8E8),
    shadowDark: Color(0xFFB8B8B8),
    shadowLight: Color(0xFFFFFFFF),
    accent: AppColors.accent,
    textPrimary: Color(0xFF1A1A1A),
    textSecondary: Color(0xFF6A6A6A),
    icon: Color(0xFF3A3A3A),
    trackInactive: Color(0xFF9A9A9A),
    surfaceGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFF2F2F2), Color(0xFFD8D8D8)],
    ),
    sunkenGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFD4D4D4), Color(0xFFEFEFEF)],
    ),
  );

  @override
  AcornPalette copyWith({
    Color? background,
    Color? surface,
    Color? shadowDark,
    Color? shadowLight,
    Color? accent,
    Color? textPrimary,
    Color? textSecondary,
    Color? icon,
    Color? trackInactive,
    LinearGradient? surfaceGradient,
    LinearGradient? sunkenGradient,
  }) {
    return AcornPalette(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      shadowDark: shadowDark ?? this.shadowDark,
      shadowLight: shadowLight ?? this.shadowLight,
      accent: accent ?? this.accent,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      icon: icon ?? this.icon,
      trackInactive: trackInactive ?? this.trackInactive,
      surfaceGradient: surfaceGradient ?? this.surfaceGradient,
      sunkenGradient: sunkenGradient ?? this.sunkenGradient,
    );
  }

  @override
  AcornPalette lerp(ThemeExtension<AcornPalette>? other, double t) {
    if (other is! AcornPalette) return this;
    return AcornPalette(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      shadowDark: Color.lerp(shadowDark, other.shadowDark, t)!,
      shadowLight: Color.lerp(shadowLight, other.shadowLight, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      icon: Color.lerp(icon, other.icon, t)!,
      trackInactive: Color.lerp(trackInactive, other.trackInactive, t)!,
      surfaceGradient: t < 0.5 ? surfaceGradient : other.surfaceGradient,
      sunkenGradient: t < 0.5 ? sunkenGradient : other.sunkenGradient,
    );
  }
}

/// Palette and themed type styles from the nearest [Theme].
extension AcornThemeContext on BuildContext {
  AcornPalette get palette =>
      Theme.of(this).extension<AcornPalette>() ?? AcornPalette.dark;

  TextStyle get styleAppBarTitle =>
      AppTextStyles.appBarTitle.copyWith(color: palette.textPrimary);

  TextStyle get styleTrackTitle =>
      AppTextStyles.trackTitle.copyWith(color: palette.textPrimary);

  TextStyle get styleTrackArtist =>
      AppTextStyles.trackArtist.copyWith(color: palette.textSecondary);

  TextStyle get styleListTitle =>
      AppTextStyles.listTitle.copyWith(color: palette.textPrimary);

  TextStyle get styleListSubtitle =>
      AppTextStyles.listSubtitle.copyWith(color: palette.textSecondary);

  TextStyle get styleTime =>
      AppTextStyles.time.copyWith(color: palette.textSecondary);

  TextStyle get styleMiniLabel =>
      AppTextStyles.miniLabel.copyWith(color: palette.textSecondary);
}
