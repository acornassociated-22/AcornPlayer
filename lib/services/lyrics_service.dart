import 'dart:io';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:path/path.dart' as p;

import '../models/song.dart';

/// One line of lyrics, optionally timestamped.
class LyricsLine {
  const LyricsLine({required this.text, this.time});

  final String text;
  final Duration? time;
}

/// Parsed lyrics for a track.
class Lyrics {
  const Lyrics(this.lines);

  final List<LyricsLine> lines;

  bool get isSynced => lines.any((line) => line.time != null);

  /// Index of the line that should be highlighted at [position].
  int indexAt(Duration position) {
    if (!isSynced) return 0;
    var current = 0;
    for (var i = 0; i < lines.length; i++) {
      final time = lines[i].time;
      if (time != null && time <= position) current = i;
    }
    return current;
  }
}

/// Reads sidecar `.lrc` files and embedded USLT tags. Never hits the network.
class LyricsService {
  /// Returns lyrics for [song], or null when none are available.
  Future<Lyrics?> load(Song song) async {
    if (!song.source.contains('://')) {
      final sidecar = File('${p.withoutExtension(song.source)}.lrc');
      if (await sidecar.exists()) {
        return parse(await sidecar.readAsString());
      }
    }
    try {
      final embedded = readMetadata(File(song.source)).lyrics?.trim();
      if (embedded == null || embedded.isEmpty) return null;
      return parse(embedded);
    } catch (_) {
      return null;
    }
  }

  /// Parses LRC or plain text into [Lyrics].
  Lyrics parse(String raw) {
    final lines = <LyricsLine>[];
    for (final line in raw.split(RegExp(r'\r?\n'))) {
      final match = RegExp(
        r'^\[(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?\](.*)$',
      ).firstMatch(line);
      if (match == null) {
        final text = line.trim();
        if (text.isNotEmpty && !text.startsWith('[')) {
          lines.add(LyricsLine(text: text));
        }
        continue;
      }
      final minutes = int.parse(match.group(1)!);
      final seconds = int.parse(match.group(2)!);
      final fraction = match.group(3);
      var millis = 0;
      if (fraction != null) {
        millis = int.parse(fraction.padRight(3, '0').substring(0, 3));
      }
      final text = match.group(4)!.trim();
      if (text.isEmpty) continue;
      lines.add(
        LyricsLine(
          text: text,
          time: Duration(
            minutes: minutes,
            seconds: seconds,
            milliseconds: millis,
          ),
        ),
      );
    }
    return Lyrics(lines);
  }
}
