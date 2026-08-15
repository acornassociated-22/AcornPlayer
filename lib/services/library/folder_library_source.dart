import 'dart:io';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';

import '../../models/song.dart';
import 'library_source.dart';

const _audioExtensions = {
  '.mp3',
  '.flac',
  '.m4a',
  '.m4b',
  '.aac',
  '.ogg',
  '.oga',
  '.opus',
  '.wav',
  '.aiff',
  '.aif',
  '.ape',
  '.wma',
};

/// Android's shared storage, in the order we would rather scan it.
const _androidRoots = [
  '/storage/emulated/0/Music',
  '/storage/emulated/0/Download',
  '/storage/emulated/0',
];

/// Reads music straight from the file system on all five platforms. Tag parsing
/// runs in an isolate so a large library never blocks the first frame.
class FolderLibrarySource implements LibrarySource {
  @override
  Future<bool> requestAccess() async {
    if (!Platform.isAndroid) return true;
    // Android 13+ exposes audio separately; older releases use storage.
    if (await Permission.audio.request().isGranted) return true;
    return Permission.storage.request().isGranted;
  }

  @override
  Future<String?> defaultFolder() async {
    for (final root in Platform.isAndroid ? _androidRoots : _homeRoots()) {
      if (Directory(root).existsSync()) return root;
    }
    return null;
  }

  @override
  Future<String?> pickFolder() =>
      FilePicker.getDirectoryPath(dialogTitle: 'Choose your music folder');

  @override
  Future<List<Song>> loadSongs({String? folder}) async {
    if (folder == null) return const [];
    final directory = Directory(folder);
    if (!directory.existsSync()) return const [];

    final paths = _audioFilesIn(directory);
    return compute(_parseFiles, paths);
  }

  @override
  Future<Uint8List?> artwork(Song song) => compute(_readArtwork, song.source);

  /// Walks [directory], skipping folders we cannot read instead of failing.
  List<String> _audioFilesIn(Directory directory) {
    final paths = <String>[];
    final pending = <Directory>[directory];

    while (pending.isNotEmpty) {
      final current = pending.removeLast();
      final List<FileSystemEntity> entries;
      try {
        entries = current.listSync(followLinks: false);
      } on FileSystemException {
        continue;
      }

      for (final entry in entries) {
        if (entry is Directory) {
          if (!p.basename(entry.path).startsWith('.')) pending.add(entry);
        } else if (entry is File &&
            _audioExtensions.contains(p.extension(entry.path).toLowerCase())) {
          paths.add(entry.path);
        }
      }
    }
    return paths;
  }
}

/// The conventional music folder of the signed-in user, for desktop first runs.
List<String> _homeRoots() {
  final home =
      Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
  return home == null ? const [] : [p.join(home, 'Music')];
}

/// Runs in a background isolate: turns file paths into songs.
List<Song> _parseFiles(List<String> paths) {
  final songs = [for (final path in paths) _parseFile(path)];
  songs.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  return songs;
}

Song _parseFile(String path) {
  final fallback = _fromFileName(p.basenameWithoutExtension(path));
  try {
    final metadata = readMetadata(File(path));
    return Song(
      id: path,
      title: _cleanTag(metadata.title) ?? fallback.title,
      artist: _cleanTag(metadata.artist) ?? fallback.artist,
      album: _cleanTag(metadata.album),
      duration: metadata.duration ?? Duration.zero,
      source: path,
    );
  } catch (_) {
    // Unsupported or damaged tags still leave a playable file.
    return Song(
      id: path,
      title: fallback.title,
      artist: fallback.artist,
      source: path,
    );
  }
}

/// Untagged files usually spell out "Artist - Title", often with a trailing
/// download id in brackets.
({String artist, String title}) _fromFileName(String name) {
  final cleaned = name
      .replaceAll(RegExp(r'\s*[\[(][^\[\]()]*[\])]\s*$'), '')
      .trim();
  final parts = cleaned.split(RegExp(r'\s+[-–—|｜]\s+'));
  if (parts.length > 1 && parts.first.isNotEmpty) {
    return (artist: parts.first, title: parts.skip(1).join(' - '));
  }
  return (artist: 'Unknown artist', title: cleaned.isEmpty ? name : cleaned);
}

String? _cleanTag(String? value) {
  final trimmed = value?.trim();
  return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
}

Uint8List? _readArtwork(String path) {
  try {
    final pictures = readMetadata(File(path), getImage: true).pictures;
    if (pictures.isEmpty) return null;
    final front = pictures.firstWhere(
      (picture) => picture.pictureType == PictureType.coverFront,
      orElse: () => pictures.first,
    );
    return front.bytes;
  } catch (_) {
    return null;
  }
}
