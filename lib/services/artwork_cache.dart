import 'dart:typed_data';

import '../models/song.dart';
import 'library/library_source.dart';

/// Memoises cover art per song id and hands out the same future on every
/// rebuild, so widgets never flicker while scrolling.
class ArtworkCache {
  ArtworkCache(this._source);

  static const _maxEntries = 150;

  final LibrarySource _source;
  final Map<String, Future<Uint8List?>> _futures = {};

  Future<Uint8List?> load(Song song) {
    if (_futures.length > _maxEntries) _futures.clear();
    return _futures.putIfAbsent(song.id, () => _source.artwork(song));
  }
}
