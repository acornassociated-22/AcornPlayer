import 'package:flutter/foundation.dart';

/// A single playable track, independent of where it was discovered.
///
/// Liked state deliberately lives in `LibraryController` so a song object is
/// never stale after the user taps the heart.
@immutable
class Song {
  const Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.source,
    this.album,
    this.duration = Duration.zero,
    this.mediaStoreId,
  });

  /// Stable identity: the file path on desktop, `mediastore:<id>` on mobile.
  final String id;
  final String title;
  final String artist;
  final String? album;
  final Duration duration;

  /// Location handed to the audio backend (absolute path or content uri).
  final String source;

  /// MediaStore identifier, required to read artwork on Android and iOS.
  final int? mediaStoreId;

  @override
  bool operator ==(Object other) => other is Song && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
