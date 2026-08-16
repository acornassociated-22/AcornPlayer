import 'package:acorn_player/widgets/desktop_playback_shortcuts.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

KeyDownEvent _down(LogicalKeyboardKey key) {
  return KeyDownEvent(
    physicalKey: PhysicalKeyboardKey.space,
    logicalKey: key,
    timeStamp: Duration.zero,
  );
}

KeyRepeatEvent _repeat(LogicalKeyboardKey key) {
  return KeyRepeatEvent(
    physicalKey: PhysicalKeyboardKey.arrowUp,
    logicalKey: key,
    timeStamp: Duration.zero,
  );
}

void main() {
  group('playbackShortcutFor', () {
    test('space and media keys toggle playback', () {
      expect(
        playbackShortcutFor(_down(LogicalKeyboardKey.space), commandHeld: false),
        PlaybackShortcut.playPause,
      );
      expect(
        playbackShortcutFor(
          _down(LogicalKeyboardKey.mediaPlayPause),
          commandHeld: false,
        ),
        PlaybackShortcut.playPause,
      );
    });

    test('command plus arrows skip and change volume', () {
      expect(
        playbackShortcutFor(
          _down(LogicalKeyboardKey.arrowRight),
          commandHeld: true,
        ),
        PlaybackShortcut.next,
      );
      expect(
        playbackShortcutFor(
          _down(LogicalKeyboardKey.arrowLeft),
          commandHeld: true,
        ),
        PlaybackShortcut.previous,
      );
      expect(
        playbackShortcutFor(
          _down(LogicalKeyboardKey.arrowUp),
          commandHeld: true,
        ),
        PlaybackShortcut.volumeUp,
      );
      expect(
        playbackShortcutFor(
          _down(LogicalKeyboardKey.arrowDown),
          commandHeld: true,
        ),
        PlaybackShortcut.volumeDown,
      );
    });

    test('plain arrows do nothing so lists keep them', () {
      expect(
        playbackShortcutFor(
          _down(LogicalKeyboardKey.arrowRight),
          commandHeld: false,
        ),
        isNull,
      );
    });

    test('volume repeats while held, skip does not', () {
      expect(
        playbackShortcutFor(
          _repeat(LogicalKeyboardKey.arrowUp),
          commandHeld: true,
        ),
        PlaybackShortcut.volumeUp,
      );
      expect(
        playbackShortcutFor(
          _repeat(LogicalKeyboardKey.arrowRight),
          commandHeld: true,
        ),
        isNull,
      );
    });
  });
}
