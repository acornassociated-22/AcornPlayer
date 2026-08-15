import 'dart:io';

import 'package:acorn_player/services/audio_player_service.dart';
import 'package:acorn_player/services/library/folder_library_source.dart';
import 'package:acorn_player/state/player_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Runs against the real audio backend, so it needs a device:
/// `flutter test integration_test/playback_test.dart -d linux`
///
/// Point ACORN_TEST_MUSIC_DIR at a folder with audio files to run it.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  AudioPlayerService.registerBackend();

  final musicDirectory =
      Platform.environment['ACORN_TEST_MUSIC_DIR'] ??
      '${Platform.environment['HOME']}/Music/AcornTest';

  testWidgets('scans a folder and actually plays the first track', (
    tester,
  ) async {
    final source = FolderLibrarySource();
    final songs = await source.loadSongs(folder: musicDirectory);
    expect(
      songs,
      isNotEmpty,
      reason: 'No audio files found in $musicDirectory',
    );

    final controller = PlayerController(AudioPlayerService());
    addTearDown(controller.dispose);

    await controller.playQueue(songs, 0);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 3)),
    );

    expect(controller.isPlaying, isTrue);
    expect(controller.position, greaterThan(Duration.zero));
    expect(controller.duration, greaterThan(Duration.zero));
  });

  testWidgets('skipping forward switches to the next track', (tester) async {
    final source = FolderLibrarySource();
    final songs = await source.loadSongs(folder: musicDirectory);
    expect(songs.length, greaterThan(1));

    final controller = PlayerController(AudioPlayerService());
    addTearDown(controller.dispose);

    await controller.playQueue(songs, 0);
    await controller.next();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );

    expect(controller.index, 1);
    expect(controller.current, songs[1]);
    expect(controller.isPlaying, isTrue);
  });
}
