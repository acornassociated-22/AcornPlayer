import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:acorn_player/data/database.dart';
import 'package:acorn_player/models/song.dart';
import 'package:acorn_player/screens/library_screen.dart';
import 'package:acorn_player/screens/now_playing_screen.dart';
import 'package:acorn_player/services/artwork_cache.dart';
import 'package:acorn_player/services/audio_player_service.dart';
import 'package:acorn_player/services/library/library_source.dart';
import 'package:acorn_player/state/library_controller.dart';
import 'package:acorn_player/state/player_controller.dart';
import 'package:acorn_player/state/settings_controller.dart';
import 'package:acorn_player/theme/acorn_palette.dart';
import 'package:acorn_player/theme/app_colors.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

const _designSize = Size(390, 844);
const _fontsDirectory =
    '/home/asus/flutter/bin/cache/artifacts/material_fonts';

const _tracks = [
  ('ZHU', 'Exhale/Stardust'),
  ('Soner Karaca', 'Encore'),
  ('Sebastian Wibe', 'Lies ft. Jack Dawson'),
  ('Apricots', 'Bicep'),
  ('Monolink', 'Return To Oz (ARTBAT Remix)'),
  ('Otnicka', 'Where Are You'),
];

List<Song> _songs() => [
  for (var index = 0; index < _tracks.length; index++)
    Song(
      id: 'song-$index',
      artist: _tracks[index].$1,
      title: _tracks[index].$2,
      album: 'Liked Songs',
      duration: Duration(seconds: 165 + index * 40),
      source: '/music/track-$index.mp3',
    ),
];

/// Library that serves the fixed track list and a solid colour cover.
class _FakeLibrarySource implements LibrarySource {
  static final Map<String, Uint8List> covers = {};

  @override
  Future<bool> requestAccess() async => true;

  @override
  Future<String?> defaultFolder() async => '/music';

  @override
  Future<String?> pickFolder() async => null;

  @override
  Future<List<Song>> loadSongs({String? folder}) async => _songs();

  @override
  Future<Uint8List?> artwork(Song song) async => covers[song.id];
}

/// Audio service that never touches the platform plugin.
class _FakeAudioService extends AudioPlayerService {
  @override
  Stream<Duration> get positionStream =>
      Stream.value(const Duration(minutes: 2, seconds: 45));

  @override
  Stream<Duration?> get durationStream =>
      Stream.value(const Duration(minutes: 6, seconds: 17));

  @override
  Stream<bool> get playingStream => Stream.value(true);

  @override
  Stream<ProcessingState> get processingStateStream =>
      Stream.value(ProcessingState.ready);

  @override
  bool get isPlaying => true;

  @override
  Future<void> load(Song song) async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> setSpeed(double speed) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

Future<void> _loadFont(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final file in files) {
    loader.addFont(
      File('$_fontsDirectory/$file').readAsBytes().then(
        (bytes) => ByteData.view(bytes.buffer),
      ),
    );
  }
  await loader.load();
}

/// Decodes every cover up front so `Image.memory` resolves synchronously
/// during the golden pump, which otherwise leaves images undecoded.
Future<void> _precacheCovers(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (final bytes in _FakeLibrarySource.covers.values) {
      final completer = Completer<void>();
      MemoryImage(bytes).resolve(ImageConfiguration.empty).addListener(
        ImageStreamListener((_, _) => completer.complete()),
      );
      await completer.future;
    }
  });
}

Future<Uint8List> _solidCover(int index) async {
  const palette = [
    Color(0xFFD81B2C),
    Color(0xFF5B57C8),
    Color(0xFF12A8A4),
    Color(0xFFEE8A1E),
    Color(0xFF9B45C8),
    Color(0xFF2FB06E),
  ];
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    const Rect.fromLTWH(0, 0, 300, 300),
    Paint()..color = palette[index % palette.length],
  );
  final image = await recorder.endRecording().toImage(300, 300);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return bytes!.buffer.asUint8List();
}

Widget _harness({
  required Widget child,
  required List<SingleChildWidget> providers,
}) {
  return MultiProvider(
    providers: providers,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        splashFactory: NoSplash.splashFactory,
        fontFamily: 'Roboto',
        extensions: const [AcornPalette.dark],
      ),
      home: child,
    ),
  );
}

void main() {
  late AppDatabase database;
  late LibraryController library;
  late PlayerController player;
  late SettingsController settings;

  setUpAll(() async {
    await _loadFont('Roboto', [
      'Roboto-Regular.ttf',
      'Roboto-Medium.ttf',
      'Roboto-Bold.ttf',
    ]);
    await _loadFont('MaterialIcons', ['MaterialIcons-Regular.otf']);

    for (var index = 0; index < _tracks.length; index++) {
      _FakeLibrarySource.covers['song-$index'] = await _solidCover(index);
    }
  });

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    library = LibraryController(database, _FakeLibrarySource());
    player = PlayerController(_FakeAudioService());
    settings = SettingsController(database);
    await settings.load();
    await library.initialise();
    // Third track, so the carousel shows a neighbour on both sides.
    await player.playQueue(_songs(), 2);
  });

  tearDown(() async {
    await database.close();
  });

  testWidgets('library screen matches the reference layout', (tester) async {
    tester.view.physicalSize = _designSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _precacheCovers(tester);

    await tester.pumpWidget(
      _harness(
        providers: [
          Provider<ArtworkCache>.value(
            value: ArtworkCache(_FakeLibrarySource()),
          ),
          ChangeNotifierProvider<SettingsController>.value(value: settings),
          ChangeNotifierProvider<LibraryController>.value(value: library),
          ChangeNotifierProvider<PlayerController>.value(value: player),
        ],
        child: const LibraryScreen(),
      ),
    );
    // The equaliser animates forever, so settle by time instead.
    await tester.pump(const Duration(milliseconds: 400));

    await expectLater(
      find.byType(LibraryScreen),
      matchesGoldenFile('goldens/library_screen.png'),
    );
  });

  testWidgets('now playing screen matches the reference layout', (
    tester,
  ) async {
    tester.view.physicalSize = _designSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _precacheCovers(tester);

    await tester.pumpWidget(
      _harness(
        providers: [
          Provider<ArtworkCache>.value(
            value: ArtworkCache(_FakeLibrarySource()),
          ),
          ChangeNotifierProvider<SettingsController>.value(value: settings),
          ChangeNotifierProvider<LibraryController>.value(value: library),
          ChangeNotifierProvider<PlayerController>.value(value: player),
        ],
        child: const NowPlayingScreen(),
      ),
    );
    // The waveform pulses while playing, so settle by time instead.
    await tester.pump(const Duration(milliseconds: 400));

    await expectLater(
      find.byType(NowPlayingScreen),
      matchesGoldenFile('goldens/now_playing_screen.png'),
    );
  });
}
