import 'package:just_audio/just_audio.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';

import '../models/song.dart';
import 'app_platform.dart';

/// Thin wrapper around just_audio. One track is loaded at a time, because the
/// media_kit backend used on Linux and Windows has no playlist support; the
/// queue itself lives in `PlayerController`.
class AudioPlayerService {
  /// Must run before the first player is created.
  static void registerBackend() {
    if (!AppPlatform.needsMediaKit) return;
    JustAudioMediaKit.title = 'Acorn Player';
    JustAudioMediaKit.ensureInitialized(linux: true, windows: true);
  }

  /// Created lazily so tests can substitute the whole service without ever
  /// touching the platform plugin.
  late final AudioPlayer _player = AudioPlayer();

  Stream<Duration> get positionStream => _player.positionStream;

  Stream<Duration?> get durationStream => _player.durationStream;

  Stream<bool> get playingStream => _player.playingStream;

  Stream<ProcessingState> get processingStateStream =>
      _player.processingStateStream;

  bool get isPlaying => _player.playing;

  Future<void> load(Song song) async {
    final source = song.source.contains('://')
        ? AudioSource.uri(Uri.parse(song.source))
        : AudioSource.file(song.source);
    await _player.setAudioSource(source);
  }

  Future<void> play() => _player.play();

  Future<void> pause() => _player.pause();

  Future<void> seek(Duration position) => _player.seek(position);

  /// 0 is silent, 1 is full output.
  Future<void> setVolume(double volume) =>
      _player.setVolume(volume.clamp(0.0, 1.0));

  /// Playback rate. 1 is normal speed.
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  Future<void> stop() => _player.stop();

  Future<void> dispose() => _player.dispose();
}
