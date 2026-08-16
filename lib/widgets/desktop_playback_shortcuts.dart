import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../state/player_controller.dart';

/// Desktop playback actions bound to keys. Volume repeats while held; the
/// rest fire once per key down.
enum PlaybackShortcut {
  playPause,
  next,
  previous,
  volumeUp,
  volumeDown,
}

const _volumeStep = 0.05;

/// Maps a key event to a playback shortcut. Returns null when the event
/// should pass through to text fields and buttons.
PlaybackShortcut? playbackShortcutFor(
  KeyEvent event, {
  required bool commandHeld,
}) {
  final isRepeat = event is KeyRepeatEvent;
  if (event is! KeyDownEvent && !isRepeat) return null;

  final key = event.logicalKey;
  if (commandHeld && key == LogicalKeyboardKey.arrowUp) {
    return PlaybackShortcut.volumeUp;
  }
  if (commandHeld && key == LogicalKeyboardKey.arrowDown) {
    return PlaybackShortcut.volumeDown;
  }
  if (isRepeat) return null;

  if (key == LogicalKeyboardKey.space ||
      key == LogicalKeyboardKey.mediaPlayPause ||
      key == LogicalKeyboardKey.mediaPlay ||
      key == LogicalKeyboardKey.mediaPause) {
    return PlaybackShortcut.playPause;
  }
  if (key == LogicalKeyboardKey.mediaTrackNext ||
      (commandHeld && key == LogicalKeyboardKey.arrowRight)) {
    return PlaybackShortcut.next;
  }
  if (key == LogicalKeyboardKey.mediaTrackPrevious ||
      (commandHeld && key == LogicalKeyboardKey.arrowLeft)) {
    return PlaybackShortcut.previous;
  }
  return null;
}

/// True when Ctrl (Linux/Windows) or Cmd (macOS) is held.
bool get playbackCommandHeld {
  final keys = HardwareKeyboard.instance;
  return Platform.isMacOS ? keys.isMetaPressed : keys.isControlPressed;
}

/// Applies [shortcut] to [player] without waiting for the audio engine.
void applyPlaybackShortcut(
  PlayerController player,
  PlaybackShortcut shortcut,
) {
  switch (shortcut) {
    case PlaybackShortcut.playPause:
      unawaited(player.togglePlay());
    case PlaybackShortcut.next:
      unawaited(player.next());
    case PlaybackShortcut.previous:
      unawaited(player.previous());
    case PlaybackShortcut.volumeUp:
      unawaited(player.nudgeVolume(_volumeStep));
    case PlaybackShortcut.volumeDown:
      unawaited(player.nudgeVolume(-_volumeStep));
  }
}

/// Listens for playback keys on Linux, Windows and macOS. Child widgets that
/// handle the same key (search fields, focused buttons) win first.
class DesktopPlaybackShortcuts extends StatelessWidget {
  const DesktopPlaybackShortcuts({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerController>();
    return Focus(
      autofocus: true,
      skipTraversal: true,
      onKeyEvent: (node, event) {
        final shortcut = playbackShortcutFor(
          event,
          commandHeld: playbackCommandHeld,
        );
        if (shortcut == null) return KeyEventResult.ignored;
        applyPlaybackShortcut(player, shortcut);
        return KeyEventResult.handled;
      },
      child: child,
    );
  }
}
