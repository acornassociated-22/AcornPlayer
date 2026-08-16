import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:audio_service_mpris/audio_service_mpris.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'data/database.dart';
import 'services/acorn_audio_handler.dart';
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
  final artwork = ArtworkCache(librarySource);
  final settings = SettingsController(database);
  await settings.load();

  final library = LibraryController(database, librarySource);
  final player = PlayerController(
    AudioPlayerService(),
    systemVolume: DeviceSystemVolume(),
    database: database,
    onTrackPlayed: library.recordPlay,
  );
  await library.initialise();
  await player.restoreSession(library.allSongs);
  await _initMediaSession(player, artwork);

  runApp(
    MultiProvider(
      providers: [
        Provider<AppDatabase>.value(value: database),
        Provider<ArtworkCache>.value(value: artwork),
        ChangeNotifierProvider<SettingsController>.value(value: settings),
        ChangeNotifierProvider<PlayerController>.value(value: player),
        ChangeNotifierProvider<LibraryController>.value(value: library),
      ],
      child: const AcornApp(),
    ),
  );
}

/// Registers MPRIS / SMTC / Android media session around [player].
Future<void> _initMediaSession(
  PlayerController player,
  ArtworkCache artwork,
) async {
  if (Platform.isLinux) {
    AudioServiceMpris.init(
      dBusName: 'AcornPlayer',
      identity: 'Acorn Player',
      desktopEntry: 'acorn-player',
      canGoNext: true,
      canGoPrevious: true,
      canPlay: true,
      canPause: true,
      canControl: true,
    );
  }
  try {
    await AudioService.init(
      builder: () => AcornAudioHandler(player, artwork),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.acorn.acorn_player.channel.audio',
        androidNotificationChannelName: 'Acorn Player',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    );
  } catch (_) {
    // OS session is optional; playback still works inside the app.
  }
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
