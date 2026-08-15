import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'l10n/app_strings.dart';
import 'screens/library_screen.dart';
import 'state/settings_controller.dart';
import 'theme/acorn_palette.dart';
import 'widgets/app_shell.dart';

class AcornApp extends StatelessWidget {
  const AcornApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    return MaterialApp(
      title: 'Acorn Player',
      debugShowCheckedModeBanner: false,
      theme: _theme(AcornPalette.light, Brightness.light),
      darkTheme: _theme(AcornPalette.dark, Brightness.dark),
      themeMode: settings.themeMode,
      locale: settings.locale.flutterLocale,
      supportedLocales: AppLocale.values.map((locale) => locale.flutterLocale),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        // Kurmancî has no Flutter translations, so the built-in widget strings
        // come from English instead of failing to resolve.
        _EnglishFallback<MaterialLocalizations>(
          GlobalMaterialLocalizations.delegate,
        ),
        _EnglishFallback<WidgetsLocalizations>(
          GlobalWidgetsLocalizations.delegate,
        ),
      ],
      builder: (context, child) => Directionality(
        textDirection: settings.locale.isRtl
            ? TextDirection.rtl
            : TextDirection.ltr,
        child: AppShell(child: child ?? const SizedBox()),
      ),
      home: const LibraryScreen(),
    );
  }
}

/// Last-resort delegate: answers any locale with the English translations.
class _EnglishFallback<T> extends LocalizationsDelegate<T> {
  const _EnglishFallback(this.delegate);

  final LocalizationsDelegate<T> delegate;

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<T> load(Locale locale) => delegate.load(const Locale('en'));

  @override
  bool shouldReload(covariant LocalizationsDelegate<T> old) => false;
}

/// Shared Material theme with the neumorphic palette attached.
ThemeData _theme(AcornPalette palette, Brightness brightness) {
  return ThemeData(
    brightness: brightness,
    scaffoldBackgroundColor: palette.background,
    canvasColor: palette.background,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    colorScheme: ColorScheme.fromSeed(
      seedColor: palette.accent,
      brightness: brightness,
    ),
    fontFamily: 'Roboto',
    extensions: [palette],
  );
}
