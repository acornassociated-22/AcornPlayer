import 'dart:io';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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

/// Reads music straight from the file system on all five platforms. Tag
/// parsing and the directory walk both run in isolates.
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
  Future<String?> pickFolder() async {
    if (Platform.isMacOS) return _pickMacosFolder();
    return FilePicker.getDirectoryPath(dialogTitle: 'Choose your music folder');
  }

  /// Uses the Runner NSOpenPanel so folder picking works without App Sandbox.
  Future<String?> _pickMacosFolder() async {
    try {
      return await const MethodChannel('com.acorn.acorn_player/folder_picker')
          .invokeMethod<String>('pickFolder');
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Song>> loadSongs({
    String? folder,
    Map<String, Song> cached = const {},
    void Function(int done, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    if (folder == null) return const [];
    final directory = Directory(folder);
    if (!directory.existsSync()) return const [];

    final paths = await compute(_walkFolder, folder);
    if (isCancelled?.call() ?? false) return const [];
    onProgress?.call(0, paths.length);

    final reused = <Song>[];
    final changed = <String>[];
    for (final path in paths) {
      if (isCancelled?.call() ?? false) return const [];
      final previous = cached[path];
      if (previous != null && _sameFile(previous, path)) {
        reused.add(previous);
      } else {
        changed.add(path);
      }
    }

    final parsed = changed.isEmpty
        ? const <Song>[]
        : await compute(_parseFiles, changed);
    if (isCancelled?.call() ?? false) return const [];
    onProgress?.call(paths.length, paths.length);
    return [...reused, ...parsed];
  }

  @override
  Future<Uint8List?> artwork(Song song) => compute(_readArtwork, song.source);
}

/// True when [song] still matches the file on disk.
bool _sameFile(Song song, String path) {
  try {
    final stat = File(path).statSync();
    return song.fileModified == stat.modified.millisecondsSinceEpoch &&
        song.fileSize == stat.size;
  } catch (_) {
    return false;
  }
}

/// The conventional music folder of the signed-in user, for desktop first runs.
List<String> _homeRoots() {
  final home =
      Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
  return home == null ? const [] : [p.join(home, 'Music')];
}

/// Walks [folder] on a background isolate.
List<String> _walkFolder(String folder) {
  final paths = <String>[];
  final pending = <Directory>[Directory(folder)];

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

/// Runs in a background isolate: turns file paths into songs.
List<Song> _parseFiles(List<String> paths) {
  return [for (final path in paths) _parseFile(path)];
}

Song _parseFile(String path) {
  final fallback = _fromFileName(p.basenameWithoutExtension(path));
  int? modified;
  int? size;
  try {
    final stat = File(path).statSync();
    modified = stat.modified.millisecondsSinceEpoch;
    size = stat.size;
  } catch (_) {}

  try {
    final metadata = readMetadata(File(path));
    return Song(
      id: path,
      title: _cleanTag(metadata.title) ?? fallback.title,
      artist: _cleanTag(metadata.artist) ?? fallback.artist,
      album: _cleanTag(metadata.album),
      duration: metadata.duration ?? Duration.zero,
      source: path,
      genre: metadata.genres.isEmpty ? null : _cleanTag(metadata.genres.first),
      year: metadata.year?.year,
      trackNumber: metadata.trackNumber,
      discNumber: metadata.discNumber,
      albumArtist: _cleanTag(metadata.artist),
      addedAt: DateTime.now(),
      fileModified: modified,
      fileSize: size,
    );
  } catch (_) {
    // Unsupported or damaged tags still leave a playable file.
    return Song(
      id: path,
      title: fallback.title,
      artist: fallback.artist,
      source: path,
      addedAt: DateTime.now(),
      fileModified: modified,
      fileSize: size,
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
