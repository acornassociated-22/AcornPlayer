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
    this.genre,
    this.year,
    this.trackNumber,
    this.discNumber,
    this.albumArtist,
    this.addedAt,
    this.playCount = 0,
    this.lastPlayedAt,
    this.fileModified,
    this.fileSize,
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

  final String? genre;
  final int? year;
  final int? trackNumber;
  final int? discNumber;
  final String? albumArtist;
  final DateTime? addedAt;
  final int playCount;
  final DateTime? lastPlayedAt;
  final int? fileModified;
  final int? fileSize;

  /// Returns a copy with the given fields replaced.
  Song copyWith({
    String? title,
    String? artist,
    String? album,
    Duration? duration,
    String? genre,
    int? year,
    int? trackNumber,
    int? discNumber,
    String? albumArtist,
    DateTime? addedAt,
    int? playCount,
    DateTime? lastPlayedAt,
    int? fileModified,
    int? fileSize,
  }) {
    return Song(
      id: id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      source: source,
      album: album ?? this.album,
      duration: duration ?? this.duration,
      mediaStoreId: mediaStoreId,
      genre: genre ?? this.genre,
      year: year ?? this.year,
      trackNumber: trackNumber ?? this.trackNumber,
      discNumber: discNumber ?? this.discNumber,
      albumArtist: albumArtist ?? this.albumArtist,
      addedAt: addedAt ?? this.addedAt,
      playCount: playCount ?? this.playCount,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      fileModified: fileModified ?? this.fileModified,
      fileSize: fileSize ?? this.fileSize,
    );
  }

  @override
  bool operator ==(Object other) => other is Song && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
