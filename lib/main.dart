import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'data/database.dart';
import 'services/app_platform.dart';
import 'services/artwork_cache.dart';
import 'services/audio_player_service.dart';
import 'services/system_volume.dart';
import 'services/library/folder_library_source.dart';
import 'state/library_controller.dart';
import 'state/player_controller.dart';
import 'state/settings_controller.dart';
import 'theme/app_colors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AudioPlayerService.registerBackend();
  await _setUpDesktopWindow();

  final database = AppDatabase();
  final librarySource = FolderLibrarySource();
  final settings = SettingsController(database);
  await settings.load();

  runApp(
    MultiProvider(
      providers: [
        Provider<AppDatabase>.value(value: database),
        Provider<ArtworkCache>(create: (_) => ArtworkCache(librarySource)),
        ChangeNotifierProvider<SettingsController>.value(value: settings),
        ChangeNotifierProvider<PlayerController>(
          create: (_) => PlayerController(
            AudioPlayerService(),
            systemVolume: DeviceSystemVolume(),
          ),
        ),
        ChangeNotifierProvider<LibraryController>(
          create: (_) =>
              LibraryController(database, librarySource)..initialise(),
        ),
      ],
      child: const AcornApp(),
    ),
  );
}

/// Opens a frameless desktop window; the caption bar lives inside the app.
Future<void> _setUpDesktopWindow() async {
  if (!AppPlatform.isDesktop) return;

  await windowManager.ensureInitialized();
  await windowManager.waitUntilReadyToShow(
    const WindowOptions(
      size: Size(1120, 760),
      minimumSize: Size(560, 560),
      center: true,
      title: 'Acorn Player',
      backgroundColor: AppColors.background,
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: false,
    ),
    () async {
      await windowManager.show();
      await windowManager.maximize();
      await windowManager.focus();
    },
  );
}
