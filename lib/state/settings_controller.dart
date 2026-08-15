import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/database.dart';
import '../l10n/app_strings.dart';

const _themeKey = 'theme';
const _localeKey = 'locale';

enum ThemePreference {
  system,
  light,
  dark;

  static ThemePreference parse(String? raw) {
    for (final value in values) {
      if (value.name == raw) return value;
    }
    return ThemePreference.dark;
  }

  ThemeMode get themeMode => switch (this) {
    ThemePreference.system => ThemeMode.system,
    ThemePreference.light => ThemeMode.light,
    ThemePreference.dark => ThemeMode.dark,
  };
}

/// Persisted appearance: theme mode and UI locale.
class SettingsController extends ChangeNotifier {
  SettingsController(this._db);

  final AppDatabase _db;

  ThemePreference _theme = ThemePreference.dark;
  AppLocale _locale = AppLocale.en;

  ThemePreference get theme => _theme;
  AppLocale get locale => _locale;
  ThemeMode get themeMode => _theme.themeMode;
  AppStrings get strings => AppStrings(_locale);

  /// Reads saved theme and locale from the preferences table.
  Future<void> load() async {
    _theme = ThemePreference.parse(await _db.preference(_themeKey));
    _locale = AppLocale.parse(await _db.preference(_localeKey));
    notifyListeners();
  }

  Future<void> setTheme(ThemePreference value) async {
    if (_theme == value) return;
    _theme = value;
    notifyListeners();
    await _db.setPreference(_themeKey, value.name);
  }

  /// Rail slider: Light ↔ Dark. System follows the opposite of [platform].
  Future<void> toggleLightDark(Brightness platform) {
    final resolved = switch (_theme) {
      ThemePreference.light => Brightness.light,
      ThemePreference.dark => Brightness.dark,
      ThemePreference.system => platform,
    };
    return setTheme(
      resolved == Brightness.light
          ? ThemePreference.dark
          : ThemePreference.light,
    );
  }

  Future<void> setLocale(AppLocale value) async {
    if (_locale == value) return;
    _locale = value;
    notifyListeners();
    await _db.setPreference(_localeKey, value.name);
  }
}

/// Resolves a string from [SettingsController], or English if none is provided.
extension AppL10n on BuildContext {
  AppStrings get strings {
    try {
      return Provider.of<SettingsController>(this, listen: true).strings;
    } catch (_) {
      return AppStrings.en;
    }
  }

  String t(String key, [Map<String, String>? args]) {
    if (args == null) return strings[key];
    return strings.format(key, args);
  }
}
