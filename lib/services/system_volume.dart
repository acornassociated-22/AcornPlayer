import 'dart:async';
import 'dart:io';

/// Reads and writes the OS volume so the dial matches the system slider.
abstract class SystemVolume {
  Future<double> read();

  /// Returns false when the OS has no software volume (then the player
  /// stream volume is used instead).
  Future<bool> write(double volume);

  StreamSubscription<double> watch(void Function(double volume) onChanged);

  Future<void> dispose();
}

/// Used by tests: never touches a platform plugin.
class SilentSystemVolume implements SystemVolume {
  const SilentSystemVolume();

  @override
  Future<double> read() async => 1;

  @override
  Future<bool> write(double volume) async => false;

  @override
  StreamSubscription<double> watch(void Function(double volume) onChanged) =>
      const Stream<double>.empty().listen(onChanged);

  @override
  Future<void> dispose() async {}
}

/// Linux uses PipeWire/Pulse (`wpctl`); macOS uses AppleScript. Other
/// platforms report failure so the player keeps its own gain.
class DeviceSystemVolume implements SystemVolume {
  Timer? _poll;
  final _updates = StreamController<double>.broadcast();
  double _last = -1;

  @override
  Future<double> read() async {
    try {
      if (Platform.isLinux) return _linuxRead();
      if (Platform.isMacOS) return _macRead();
    } catch (_) {}
    return 1;
  }

  @override
  Future<bool> write(double volume) async {
    final clamped = volume.clamp(0.0, 1.0);
    try {
      if (Platform.isLinux) {
        await _linuxWrite(clamped);
        return true;
      }
      if (Platform.isMacOS) {
        await _macWrite(clamped);
        return true;
      }
    } catch (_) {}
    return false;
  }

  @override
  StreamSubscription<double> watch(void Function(double volume) onChanged) {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(milliseconds: 400), (_) async {
      final next = await read();
      if ((next - _last).abs() < 0.008) return;
      _last = next;
      if (!_updates.isClosed) _updates.add(next);
    });
    return _updates.stream.listen(onChanged);
  }

  @override
  Future<void> dispose() async {
    _poll?.cancel();
    await _updates.close();
  }

  /// Parses `wpctl get-volume` (`Volume: 0.42` or `Volume: 0.42 [MUTED]`).
  Future<double> _linuxRead() async {
    final result = await Process.run('wpctl', [
      'get-volume',
      '@DEFAULT_AUDIO_SINK@',
    ]);
    final text = result.stdout.toString();
    if (text.contains('MUTED')) return 0;
    final match = RegExp(r'Volume:\s+([0-9.]+)').firstMatch(text);
    return double.tryParse(match?.group(1) ?? '') ?? 1;
  }

  /// Writes the PipeWire/Pulse sink volume, muting at zero.
  Future<void> _linuxWrite(double volume) async {
    if (volume <= 0) {
      await Process.run('wpctl', [
        'set-mute',
        '@DEFAULT_AUDIO_SINK@',
        '1',
      ]);
      return;
    }
    await Process.run('wpctl', ['set-mute', '@DEFAULT_AUDIO_SINK@', '0']);
    await Process.run('wpctl', [
      'set-volume',
      '@DEFAULT_AUDIO_SINK@',
      volume.toStringAsFixed(3),
    ]);
  }

  /// Reads the macOS output volume (0–100) as a 0–1 fraction.
  Future<double> _macRead() async {
    final result = await Process.run('osascript', [
      '-e',
      'output volume of (get volume settings)',
    ]);
    final n = double.tryParse(result.stdout.toString().trim());
    return n == null ? 1 : (n / 100).clamp(0.0, 1.0);
  }

  /// Sets the macOS output volume, muting at zero.
  Future<void> _macWrite(double volume) async {
    if (volume <= 0) {
      await Process.run('osascript', ['-e', 'set volume output muted true']);
      return;
    }
    final percent = (volume * 100).round();
    await Process.run('osascript', [
      '-e',
      'set volume output muted false',
    ]);
    await Process.run('osascript', [
      '-e',
      'set volume output volume $percent',
    ]);
  }
}
