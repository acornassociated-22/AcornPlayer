import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../models/song.dart';
import '../services/audio_player_service.dart';
import '../services/system_volume.dart';

/// How the queue behaves when a track ends.
enum QueueRepeat { off, all, one }

/// Owns the queue, the current index and the transport state of the player.
class PlayerController extends ChangeNotifier {
  PlayerController(this._audio, {SystemVolume? systemVolume})
    : _systemVolume = systemVolume ?? const SilentSystemVolume() {
    _subscriptions.addAll([
      _audio.positionStream.listen((position) {
        _position = position;
        notifyListeners();
      }),
      _audio.durationStream.listen((duration) {
        if (duration != null) _duration = duration;
        notifyListeners();
      }),
      _audio.playingStream.listen((playing) {
        _isPlaying = playing;
        notifyListeners();
      }),
      _audio.processingStateStream.listen((state) {
        if (state == ProcessingState.completed) _handleTrackCompleted();
      }),
      _systemVolume.watch(handleSystemVolume),
    ]);
    _syncFromSystem();
  }

  final AudioPlayerService _audio;
  final SystemVolume _systemVolume;
  final List<StreamSubscription<Object?>> _subscriptions = [];

  List<Song> _originalQueue = const [];
  List<Song> _queue = const [];
  int _index = -1;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  double _volume = 1;
  double _volumeBeforeMute = 1;
  QueueRepeat _repeat = QueueRepeat.off;
  bool _shuffle = false;
  double _speed = 1;

  static const _speeds = [1.0, 1.25, 1.5, 2.0, 0.75];

  List<Song> get queue => _queue;

  int get index => _index;

  Song? get current =>
      _index >= 0 && _index < _queue.length ? _queue[_index] : null;

  bool get isPlaying => _isPlaying;

  Duration get position => _position;

  Duration get duration => _duration;

  /// 0–1 how far the current track has played.
  double get progress {
    final total = _duration.inMilliseconds;
    if (total <= 0) return 0;
    return (_position.inMilliseconds / total).clamp(0.0, 1.0);
  }

  bool get hasTrack => current != null;

  double get volume => _volume;

  QueueRepeat get repeat => _repeat;

  bool get shuffle => _shuffle;

  double get speed => _speed;

  /// Replaces the queue and starts playing [startIndex].
  Future<void> playQueue(List<Song> songs, int startIndex) async {
    if (songs.isEmpty) return;
    _originalQueue = List.unmodifiable(songs);
    final safeIndex = startIndex.clamp(0, songs.length - 1);
    if (_shuffle) {
      _applyShuffle(keepId: songs[safeIndex].id);
      final start = _index;
      _index = -1;
      await playAt(start);
      return;
    }
    _queue = _originalQueue;
    _index = -1;
    await playAt(safeIndex);
  }

  /// Jumps to [next] in the current queue. Used by the carousel and the list.
  Future<void> playAt(int next) async {
    if (_queue.isEmpty) return;
    final target = next.clamp(0, _queue.length - 1);
    if (target == _index) {
      if (!_isPlaying) await _audio.play();
      return;
    }

    _index = target;
    _position = Duration.zero;
    _duration = _queue[target].duration;
    notifyListeners();

    await _audio.load(_queue[target]);
    await _audio.setSpeed(_speed);
    await _audio.play();
  }

  Future<void> togglePlay() async {
    if (!hasTrack) return;
    if (_isPlaying) {
      await _audio.pause();
    } else {
      await _audio.play();
    }
  }

  /// Wraps around so the carousel can be swiped endlessly in one direction.
  Future<void> next() => playAt(_index >= _queue.length - 1 ? 0 : _index + 1);

  Future<void> previous() => playAt(_index <= 0 ? _queue.length - 1 : _index - 1);

  /// Cycles off → all → one → off.
  void toggleRepeat() {
    _repeat = QueueRepeat.values[(_repeat.index + 1) % QueueRepeat.values.length];
    notifyListeners();
  }

  /// Steps through 1× → 1.25× → 1.5× → 2× → 0.75×.
  Future<void> cycleSpeed() async {
    final index = _speeds.indexWhere((value) => (value - _speed).abs() < 0.01);
    _speed = _speeds[(index < 0 ? 0 : index + 1) % _speeds.length];
    notifyListeners();
    await _audio.setSpeed(_speed);
  }

  /// Shuffles the remaining queue, or restores the original order.
  void toggleShuffle() {
    _shuffle = !_shuffle;
    if (_originalQueue.isEmpty) _originalQueue = _queue;
    if (_originalQueue.isEmpty) {
      notifyListeners();
      return;
    }
    final currentId = current?.id;
    if (_shuffle) {
      _applyShuffle(keepId: currentId);
    } else {
      _queue = _originalQueue;
      _index = currentId == null
          ? 0
          : _queue.indexWhere((song) => song.id == currentId);
      if (_index < 0) _index = 0;
    }
    notifyListeners();
  }

  /// Shuffles the library order but keeps the playing track at its new index
  /// so the cover slider can still move both ways.
  void _applyShuffle({String? keepId}) {
    final shuffled = List<Song>.of(_originalQueue)..shuffle(Random());
    _queue = List.unmodifiable(shuffled);
    _index = keepId == null
        ? 0
        : _queue.indexWhere((song) => song.id == keepId);
    if (_index < 0) _index = 0;
  }

  /// Repeat-one restarts; last track with repeat-off stops; otherwise next.
  Future<void> _handleTrackCompleted() async {
    if (_repeat == QueueRepeat.one) {
      _position = Duration.zero;
      notifyListeners();
      await _audio.seek(Duration.zero);
      await _audio.play();
      return;
    }
    if (_index >= _queue.length - 1 && _repeat == QueueRepeat.off) {
      await _audio.pause();
      await _audio.seek(Duration.zero);
      _position = Duration.zero;
      notifyListeners();
      return;
    }
    await next();
  }

  Future<void> seek(Duration position) async {
    _position = position;
    notifyListeners();
    await _audio.seek(position);
  }

  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    if (_volume > 0) _volumeBeforeMute = _volume;
    notifyListeners();
    final systemOk = await _systemVolume.write(_volume);
    // When the OS accepts the change, keep the decoder at full gain so we
    // do not attenuate twice. Otherwise fall back to the player stream.
    await _audio.setVolume(systemOk ? 1 : _volume);
  }

  /// Silences the player, or restores the last audible level.
  Future<void> toggleMute() =>
      setVolume(_volume > 0 ? 0 : (_volumeBeforeMute == 0 ? 0.7 : _volumeBeforeMute));

  /// Hardware keys and other apps move the same dial.
  void handleSystemVolume(double volume) {
    final next = volume.clamp(0.0, 1.0);
    if ((next - _volume).abs() < 0.008) return;
    _volume = next;
    if (next > 0) _volumeBeforeMute = next;
    notifyListeners();
  }

  Future<void> _syncFromSystem() async {
    final current = await _systemVolume.read();
    handleSystemVolume(current);
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _systemVolume.dispose();
    _audio.dispose();
    super.dispose();
  }
}
