import 'dart:typed_data';

import '../../models/song.dart';

/// Access to the music stored on the device. Kept as an interface so tests can
/// serve a fixed library without touching the file system.
abstract interface class LibrarySource {
  /// Requests the permission the platform needs; false when the user refuses.
  Future<bool> requestAccess();

  /// Folder to scan before asking the user, when the platform has an obvious
  /// music location. Null means "ask the user".
  Future<String?> defaultFolder();

  /// Opens a folder picker, or null when the user cancels.
  Future<String?> pickFolder();

  /// Every playable track inside [folder]. Unchanged [cached] rows are reused.
  Future<List<Song>> loadSongs({
    String? folder,
    Map<String, Song> cached = const {},
    void Function(int done, int total)? onProgress,
    bool Function()? isCancelled,
  });

  /// Cover art bytes, or null when the track carries none.
  Future<Uint8List?> artwork(Song song);
}
