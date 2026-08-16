import 'dart:io';

import 'package:just_audio/just_audio.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';

import '../models/song.dart';
import 'app_platform.dart';

/// Thin wrapper around just_audio. The whole queue is loaded so the engine
/// can advance gaplessly; [PlayerController] still owns the Song objects.
class AudioPlayerService {
  /// Must run before the first player is created.
  static void registerBackend() {
    if (!AppPlatform.needsMediaKit) return;
    JustAudioMediaKit.title = 'Acorn Player';
    JustAudioMediaKit.ensureInitialized(linux: true, windows: true);
  }

  AudioPlayer? _player;
  AndroidEqualizer? _equalizer;

  /// Created lazily so tests can substitute the service without a plugin.
  AudioPlayer get player => _player ??= _createPlayer();

  /// Android-only equalizer; null on every other platform.
  AndroidEqualizer? get equalizer => _equalizer;

  /// Builds the player, attaching an equalizer only on Android.
  AudioPlayer _createPlayer() {
    if (Platform.isAndroid) {
      _equalizer = AndroidEqualizer();
      return AudioPlayer(
        audioPipeline: AudioPipeline(androidAudioEffects: [_equalizer!]),
      );
    }
    return AudioPlayer();
  }

  Stream<Duration> get positionStream => player.positionStream;

  Stream<Duration?> get durationStream => player.durationStream;

  Stream<bool> get playingStream => player.playingStream;

  Stream<ProcessingState> get processingStateStream =>
      player.processingStateStream;

  Stream<int?> get currentIndexStream => player.currentIndexStream;

  bool get isPlaying => _player?.playing ?? false;

  int? get currentIndex => _player?.currentIndex;

  /// Turns a library song into an engine source, tagged with its id.
  AudioSource sourceFor(Song song) {
    return song.source.contains('://')
        ? AudioSource.uri(Uri.parse(song.source), tag: song.id)
        : AudioSource.file(song.source, tag: song.id);
  }

  /// Loads [songs] as one playlist and seeks to [initialIndex].
  Future<void> setQueue(
    List<Song> songs, {
    int initialIndex = 0,
    Duration initialPosition = Duration.zero,
  }) async {
    if (songs.isEmpty) {
      await player.clearAudioSources();
      return;
    }
    final safeIndex = initialIndex.clamp(0, songs.length - 1);
    await player.setAudioSources(
      [for (final song in songs) sourceFor(song)],
      initialIndex: safeIndex,
      initialPosition: initialPosition,
    );
  }

  Future<void> insertAt(int index, Song song) =>
      player.insertAudioSource(index, sourceFor(song));

  Future<void> add(Song song) => player.addAudioSource(sourceFor(song));

  Future<void> removeAt(int index) => player.removeAudioSourceAt(index);

  Future<void> move(int from, int to) => player.moveAudioSource(from, to);

  Future<void> play() => player.play();

  Future<void> pause() => player.pause();

  Future<void> seek(Duration position, {int? index}) =>
      player.seek(position, index: index);

  Future<void> seekToNext() => player.seekToNext();

  Future<void> seekToPrevious() => player.seekToPrevious();

  /// Maps the app repeat enum onto the engine loop mode.
  Future<void> setLoopMode(LoopMode mode) => player.setLoopMode(mode);

  /// 0 is silent, 1 is full output.
  Future<void> setVolume(double volume) =>
      player.setVolume(volume.clamp(0.0, 1.0));

  /// Playback rate. 1 is normal speed.
  Future<void> setSpeed(double speed) => player.setSpeed(speed);

  Future<void> stop() => player.stop();

  Future<void> dispose() async {
    await _player?.dispose();
    _player = null;
    _equalizer = null;
  }
}
