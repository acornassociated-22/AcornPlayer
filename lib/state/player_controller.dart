import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../data/database.dart';
import '../models/song.dart';
import '../services/audio_player_service.dart';
import '../services/system_volume.dart';

/// How the queue behaves when a track ends.
enum QueueRepeat { off, all, one }

/// Sleep-timer modes the user can arm from now playing.
enum SleepMode { off, minutes15, minutes30, minutes60, endOfTrack }

const _sessionQueueKey = 'session_queue';
const _sessionIndexKey = 'session_index';
const _sessionPositionKey = 'session_position';
const _sessionRepeatKey = 'session_repeat';
const _sessionShuffleKey = 'session_shuffle';
const _sessionSpeedKey = 'session_speed';
const _sessionVolumeKey = 'session_volume';

/// Owns the queue, the current index and the transport state of the player.
class PlayerController extends ChangeNotifier {
  PlayerController(
    this._audio, {
    SystemVolume? systemVolume,
    AppDatabase? database,
    this.onTrackPlayed,
  }) : _systemVolume = systemVolume ?? const SilentSystemVolume(),
       _db = database {
    _subscriptions.addAll([
      _audio.positionStream.listen(_handlePosition),
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
      _audio.currentIndexStream.listen(_handleEngineIndex),
      _systemVolume.watch(handleSystemVolume),
    ]);
    _syncFromSystem();
  }

  final AudioPlayerService _audio;
  final SystemVolume _systemVolume;
  final AppDatabase? _db;
  final List<StreamSubscription<Object?>> _subscriptions = [];

  /// Called once a track has been listened to long enough to count as a play.
  final Future<void> Function(Song song)? onTrackPlayed;

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
  bool _countedCurrent = false;
  SleepMode _sleep = SleepMode.off;
  DateTime? _sleepEndsAt;
  Timer? _sleepTimer;

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

  SleepMode get sleep => _sleep;

  /// Remaining sleep time, or null when the timer is off.
  Duration? get sleepRemaining {
    if (_sleep == SleepMode.off || _sleepEndsAt == null) return null;
    final left = _sleepEndsAt!.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  /// Replaces the queue and starts playing [startIndex].
  Future<void> playQueue(List<Song> songs, int startIndex) async {
    if (songs.isEmpty) return;
    _originalQueue = List.unmodifiable(songs);
    final safeIndex = startIndex.clamp(0, songs.length - 1);
    if (_shuffle) {
      _applyShuffle(keepId: songs[safeIndex].id);
    } else {
      _queue = _originalQueue;
      _index = safeIndex;
    }
    _position = Duration.zero;
    _duration = _queue[_index].duration;
    _countedCurrent = false;
    notifyListeners();
    await _audio.setQueue(_queue, initialIndex: _index);
    await _audio.setLoopMode(_loopMode);
    await _audio.setSpeed(_speed);
    await _audio.play();
    await _persistSession();
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
    _countedCurrent = false;
    notifyListeners();
    await _audio.seek(Duration.zero, index: target);
    await _audio.play();
    await _persistSession();
  }

  /// Inserts [song] so it plays immediately after the current track.
  Future<void> playNext(Song song) async {
    if (_queue.isEmpty) {
      await playQueue([song], 0);
      return;
    }
    final insertAt = (_index + 1).clamp(0, _queue.length);
    _queue = [..._queue]..insert(insertAt, song);
    _originalQueue = _queue;
    notifyListeners();
    await _audio.insertAt(insertAt, song);
    await _persistSession();
  }

  /// Appends [song] to the end of the queue.
  Future<void> addToQueue(Song song) async {
    if (_queue.isEmpty) {
      await playQueue([song], 0);
      return;
    }
    _queue = [..._queue, song];
    _originalQueue = _queue;
    notifyListeners();
    await _audio.add(song);
    await _persistSession();
  }

  /// Removes the song at [index] from the queue.
  Future<void> removeAt(int index) async {
    if (index < 0 || index >= _queue.length) return;
    final removingCurrent = index == _index;
    final next = [..._queue]..removeAt(index);
    if (next.isEmpty) {
      _queue = const [];
      _originalQueue = const [];
      _index = -1;
      _position = Duration.zero;
      notifyListeners();
      await _audio.setQueue(const []);
      await _persistSession();
      return;
    }
    _queue = next;
    _originalQueue = next;
    if (index < _index) {
      _index -= 1;
    } else if (removingCurrent) {
      _index = _index.clamp(0, _queue.length - 1);
      _duration = _queue[_index].duration;
      _countedCurrent = false;
    }
    notifyListeners();
    await _audio.removeAt(index);
    if (removingCurrent) {
      await _audio.seek(Duration.zero, index: _index);
      if (_isPlaying) await _audio.play();
    }
    await _persistSession();
  }

  /// Moves a queue row from [from] to [to] (ReorderableListView indices).
  Future<void> reorder(int from, int to) async {
    if (from == to || from < 0 || from >= _queue.length) return;
    final dest = to.clamp(0, _queue.length - 1);
    final next = [..._queue];
    final song = next.removeAt(from);
    next.insert(dest, song);
    final currentId = current?.id;
    _queue = next;
    _originalQueue = next;
    _index = currentId == null
        ? 0
        : _queue.indexWhere((item) => item.id == currentId);
    if (_index < 0) _index = 0;
    notifyListeners();
    await _audio.move(from, dest);
    await _persistSession();
  }

  Future<void> togglePlay() async {
    if (!hasTrack) return;
    if (_isPlaying) {
      await _audio.pause();
    } else {
      await _audio.play();
    }
    await _persistSession();
  }

  /// Wraps around so the carousel can be swiped endlessly in one direction.
  Future<void> next() => playAt(_index >= _queue.length - 1 ? 0 : _index + 1);

  Future<void> previous() =>
      playAt(_index <= 0 ? _queue.length - 1 : _index - 1);

  /// Cycles off → all → one → off.
  Future<void> toggleRepeat() async {
    _repeat =
        QueueRepeat.values[(_repeat.index + 1) % QueueRepeat.values.length];
    notifyListeners();
    await _audio.setLoopMode(_loopMode);
    await _persistSession();
  }

  AndroidEqualizer? get equalizer => _audio.equalizer;

  /// Sets an explicit playback rate from the OS media session.
  Future<void> setPlaybackSpeed(double speed) async {
    _speed = speed;
    notifyListeners();
    await _audio.setSpeed(_speed);
    await _persistSession();
  }

  /// Steps through 1× → 1.25× → 1.5× → 2× → 0.75×.
  Future<void> cycleSpeed() async {
    final index = _speeds.indexWhere((value) => (value - _speed).abs() < 0.01);
    _speed = _speeds[(index < 0 ? 0 : index + 1) % _speeds.length];
    notifyListeners();
    await _audio.setSpeed(_speed);
    await _persistSession();
  }

  /// Shuffles the remaining queue after the current track, or restores order.
  Future<void> toggleShuffle() async {
    _shuffle = !_shuffle;
    if (_originalQueue.isEmpty) _originalQueue = _queue;
    if (_originalQueue.isEmpty) {
      notifyListeners();
      return;
    }
    final currentId = current?.id;
    final position = _position;
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
    await _audio.setQueue(_queue, initialIndex: _index, initialPosition: position);
    await _audio.setLoopMode(_loopMode);
    await _audio.setSpeed(_speed);
    if (_isPlaying) await _audio.play();
    await _persistSession();
  }

  /// Keeps the playing track at the front and shuffles everything after it.
  void _applyShuffle({String? keepId}) {
    final source = List<Song>.of(_originalQueue);
    Song? kept;
    if (keepId != null) {
      final match = source.where((song) => song.id == keepId);
      if (match.isNotEmpty) {
        kept = match.first;
        source.removeWhere((song) => song.id == keepId);
      }
    }
    source.shuffle(Random());
    _queue = List.unmodifiable([?kept, ...source]);
    _index = 0;
  }

  LoopMode get _loopMode => switch (_repeat) {
    QueueRepeat.off => LoopMode.off,
    QueueRepeat.all => LoopMode.all,
    QueueRepeat.one => LoopMode.one,
  };

  /// Repeat-one restarts; last track with repeat-off stops; otherwise next.
  Future<void> _handleTrackCompleted() async {
    if (_sleep == SleepMode.endOfTrack) {
      await _clearSleep(pause: true);
      return;
    }
    if (_repeat == QueueRepeat.one) {
      _position = Duration.zero;
      _countedCurrent = false;
      notifyListeners();
      await _audio.seek(Duration.zero, index: _index);
      await _audio.play();
      return;
    }
    if (_index >= _queue.length - 1 && _repeat == QueueRepeat.off) {
      await _audio.pause();
      await _audio.seek(Duration.zero, index: _index);
      _position = Duration.zero;
      notifyListeners();
      return;
    }
    await next();
  }

  /// Follows gapless advances that the engine makes on its own.
  void _handleEngineIndex(int? engineIndex) {
    if (engineIndex == null || engineIndex == _index) return;
    if (engineIndex < 0 || engineIndex >= _queue.length) return;
    _index = engineIndex;
    _position = Duration.zero;
    _duration = _queue[engineIndex].duration;
    _countedCurrent = false;
    notifyListeners();
    _persistSession();
  }

  /// Updates position and records a play once the listen threshold is met.
  void _handlePosition(Duration position) {
    _position = position;
    notifyListeners();
    final song = current;
    if (song == null || _countedCurrent || onTrackPlayed == null) return;
    final heard = position.inSeconds;
    final half = _duration.inSeconds / 2;
    if (heard >= 30 || (half > 0 && heard >= half)) {
      _countedCurrent = true;
      onTrackPlayed!(song);
    }
  }

  Future<void> seek(Duration position) async {
    _position = position;
    notifyListeners();
    await _audio.seek(position);
    await _persistSession();
  }

  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    if (_volume > 0) _volumeBeforeMute = _volume;
    notifyListeners();
    final systemOk = await _systemVolume.write(_volume);
    // When the OS accepts the change, keep the decoder at full gain so we
    // do not attenuate twice. Otherwise fall back to the player stream.
    await _audio.setVolume(systemOk ? 1 : _volume);
    await _persistSession();
  }

  /// Steps the volume by [delta], used by desktop keyboard shortcuts.
  Future<void> nudgeVolume(double delta) => setVolume(_volume + delta);

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

  /// Arms or cancels the sleep timer.
  void setSleep(SleepMode mode) {
    _sleepTimer?.cancel();
    _sleep = mode;
    _sleepEndsAt = null;
    if (mode == SleepMode.off || mode == SleepMode.endOfTrack) {
      notifyListeners();
      return;
    }
    final minutes = switch (mode) {
      SleepMode.minutes15 => 15,
      SleepMode.minutes30 => 30,
      SleepMode.minutes60 => 60,
      SleepMode.off || SleepMode.endOfTrack => 0,
    };
    _sleepEndsAt = DateTime.now().add(Duration(minutes: minutes));
    _sleepTimer = Timer(Duration(minutes: minutes), () {
      _clearSleep(pause: true);
    });
    notifyListeners();
  }

  /// Clears the timer and optionally pauses playback.
  Future<void> _clearSleep({required bool pause}) async {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleep = SleepMode.off;
    _sleepEndsAt = null;
    notifyListeners();
    if (pause && _isPlaying) await _audio.pause();
  }

  Future<void> _syncFromSystem() async {
    final current = await _systemVolume.read();
    handleSystemVolume(current);
  }

  /// Writes the live session so the next launch can restore it paused.
  Future<void> _persistSession() async {
    final db = _db;
    if (db == null || _queue.isEmpty || _index < 0) return;
    await db.setPreference(
      _sessionQueueKey,
      jsonEncode(_queue.map((song) => song.id).toList()),
    );
    await db.setPreference(_sessionIndexKey, '$_index');
    await db.setPreference(
      _sessionPositionKey,
      '${_position.inMilliseconds}',
    );
    await db.setPreference(_sessionRepeatKey, _repeat.name);
    await db.setPreference(_sessionShuffleKey, _shuffle ? '1' : '0');
    await db.setPreference(_sessionSpeedKey, '$_speed');
    await db.setPreference(_sessionVolumeKey, '$_volume');
  }

  /// Restores the last queue without auto-playing.
  Future<void> restoreSession(List<Song> library) async {
    final db = _db;
    if (db == null || library.isEmpty) return;
    final raw = await db.preference(_sessionQueueKey);
    if (raw == null || raw.isEmpty) return;
    final ids = (jsonDecode(raw) as List<dynamic>).cast<String>();
    final byId = {for (final song in library) song.id: song};
    final restored = [for (final id in ids) byId[id]].whereType<Song>().toList();
    if (restored.isEmpty) return;
    final index = int.tryParse(await db.preference(_sessionIndexKey) ?? '') ?? 0;
    final positionMs =
        int.tryParse(await db.preference(_sessionPositionKey) ?? '') ?? 0;
    final repeatName = await db.preference(_sessionRepeatKey);
    final shuffleFlag = await db.preference(_sessionShuffleKey);
    final speedRaw = double.tryParse(await db.preference(_sessionSpeedKey) ?? '');
    final volumeRaw =
        double.tryParse(await db.preference(_sessionVolumeKey) ?? '');

    _originalQueue = List.unmodifiable(restored);
    _queue = _originalQueue;
    _index = index.clamp(0, restored.length - 1);
    _position = Duration(milliseconds: positionMs);
    _duration = restored[_index].duration;
    _repeat = QueueRepeat.values.firstWhere(
      (value) => value.name == repeatName,
      orElse: () => QueueRepeat.off,
    );
    _shuffle = shuffleFlag == '1';
    if (speedRaw != null) _speed = speedRaw;
    if (volumeRaw != null) _volume = volumeRaw.clamp(0.0, 1.0);
    notifyListeners();

    await _audio.setQueue(
      _queue,
      initialIndex: _index,
      initialPosition: _position,
    );
    await _audio.setLoopMode(_loopMode);
    await _audio.setSpeed(_speed);
    await _audio.pause();
  }

  @override
  void dispose() {
    _sleepTimer?.cancel();
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _systemVolume.dispose();
    _audio.dispose();
    super.dispose();
  }
}
