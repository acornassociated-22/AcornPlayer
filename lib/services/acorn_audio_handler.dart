import 'dart:io';

import 'package:audio_service/audio_service.dart';

import '../models/song.dart';
import '../state/player_controller.dart';
import 'artwork_cache.dart';

/// Bridges [PlayerController] to the OS media session (MPRIS, SMTC, Android).
class AcornAudioHandler extends BaseAudioHandler with SeekHandler {
  AcornAudioHandler(this._player, this._artwork) {
    _player.addListener(_publish);
    _publish();
  }

  final PlayerController _player;
  final ArtworkCache _artwork;
  String? _artSongId;
  Uri? _artUri;

  /// Pushes the current track, queue and transport state to the OS.
  Future<void> _publish() async {
    final song = _player.current;
    if (song == null) {
      mediaItem.add(null);
      queue.add(const []);
      playbackState.add(
        playbackState.value.copyWith(
          playing: false,
          processingState: AudioProcessingState.idle,
        ),
      );
      return;
    }

    if (song.id != _artSongId) {
      _artSongId = song.id;
      _artUri = await _writeArt(song);
    }

    mediaItem.add(_itemFor(song, _artUri));
    queue.add([
      for (final item in _player.queue) _itemFor(item, null),
    ]);
    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          _player.isPlaying ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {MediaAction.seek},
        androidCompactActionIndices: const [0, 1, 2],
        processingState: AudioProcessingState.ready,
        playing: _player.isPlaying,
        updatePosition: _player.position,
        speed: _player.speed,
        queueIndex: _player.index < 0 ? null : _player.index,
        repeatMode: switch (_player.repeat) {
          QueueRepeat.off => AudioServiceRepeatMode.none,
          QueueRepeat.all => AudioServiceRepeatMode.all,
          QueueRepeat.one => AudioServiceRepeatMode.one,
        },
        shuffleMode: _player.shuffle
            ? AudioServiceShuffleMode.all
            : AudioServiceShuffleMode.none,
      ),
    );
  }

  MediaItem _itemFor(Song song, Uri? artUri) {
    return MediaItem(
      id: song.id,
      title: song.title,
      artist: song.artist,
      album: song.album,
      duration: song.duration,
      artUri: artUri,
    );
  }

  /// Writes cover bytes to a temp file so MPRIS/SMTC can show them.
  Future<Uri?> _writeArt(Song song) async {
    final bytes = await _artwork.load(song);
    if (bytes == null || bytes.isEmpty) return null;
    try {
      final file = File(
        '${Directory.systemTemp.path}/acorn-art-${song.id.hashCode}.jpg',
      );
      await file.writeAsBytes(bytes, flush: true);
      return Uri.file(file.path);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> play() async {
    if (!_player.isPlaying) await _player.togglePlay();
  }

  @override
  Future<void> pause() async {
    if (_player.isPlaying) await _player.togglePlay();
  }

  @override
  Future<void> skipToNext() => _player.next();

  @override
  Future<void> skipToPrevious() => _player.previous();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setSpeed(double speed) => _player.setPlaybackSpeed(speed);

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    while (_mappedRepeat != repeatMode) {
      await _player.toggleRepeat();
    }
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    final want = shuffleMode != AudioServiceShuffleMode.none;
    if (_player.shuffle != want) await _player.toggleShuffle();
  }

  @override
  Future<void> stop() async {
    if (_player.isPlaying) await _player.togglePlay();
    await super.stop();
  }

  AudioServiceRepeatMode get _mappedRepeat => switch (_player.repeat) {
    QueueRepeat.off => AudioServiceRepeatMode.none,
    QueueRepeat.all => AudioServiceRepeatMode.all,
    QueueRepeat.one => AudioServiceRepeatMode.one,
  };
}
