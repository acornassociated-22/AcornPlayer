import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../models/song.dart';

part 'database.g.dart';

/// Metadata of every track we have seen, plus its liked flag.
class CachedSongs extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get artist => text()();
  TextColumn get album => text().nullable()();
  IntColumn get durationMs => integer().withDefault(const Constant(0))();
  TextColumn get source => text()();
  IntColumn get mediaStoreId => integer().nullable()();
  BoolColumn get isLiked => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class Playlists extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}

class PlaylistItems extends Table {
  IntColumn get playlistId =>
      integer().references(Playlists, #id, onDelete: KeyAction.cascade)();
  TextColumn get songId => text()();
  IntColumn get position => integer()();

  @override
  Set<Column> get primaryKey => {playlistId, songId};
}

/// Simple key/value store for the picked music folder and similar preferences.
class Preferences extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [CachedSongs, Playlists, PlaylistItems, Preferences])
class AppDatabase extends _$AppDatabase {
  /// [executor] is only passed by tests, which use an in-memory database.
  AppDatabase([QueryExecutor? executor])
    : super(
        executor ??
            // Keeps the file out of the user's visible documents folder.
            driftDatabase(
              name: 'acorn_player',
              native: const DriftNativeOptions(
                databaseDirectory: getApplicationSupportDirectory,
              ),
            ),
      );

  @override
  int get schemaVersion => 1;

  /// Stores freshly scanned metadata without touching the liked flag.
  Future<void> cacheSongs(List<Song> songs) async {
    await batch((batch) {
      for (final song in songs) {
        batch.insert(
          cachedSongs,
          CachedSongsCompanion.insert(
            id: song.id,
            title: song.title,
            artist: song.artist,
            album: Value(song.album),
            durationMs: Value(song.duration.inMilliseconds),
            source: song.source,
            mediaStoreId: Value(song.mediaStoreId),
          ),
          onConflict: DoUpdate(
            (_) => CachedSongsCompanion(
              title: Value(song.title),
              artist: Value(song.artist),
              album: Value(song.album),
              durationMs: Value(song.duration.inMilliseconds),
              source: Value(song.source),
              mediaStoreId: Value(song.mediaStoreId),
            ),
          ),
        );
      }
    });
  }

  Future<Set<String>> likedSongIds() async {
    final rows = await (selectOnly(cachedSongs)
          ..addColumns([cachedSongs.id])
          ..where(cachedSongs.isLiked.equals(true)))
        .get();
    return rows.map((row) => row.read(cachedSongs.id)!).toSet();
  }

  Future<void> setLiked(String songId, bool isLiked) async {
    await (update(cachedSongs)..where((t) => t.id.equals(songId))).write(
      CachedSongsCompanion(isLiked: Value(isLiked)),
    );
  }

  Stream<List<Playlist>> watchPlaylists() => select(playlists).watch();

  Future<int> createPlaylist(String name) =>
      into(playlists).insert(PlaylistsCompanion.insert(name: name));

  Future<void> deletePlaylist(int playlistId) async {
    await (delete(playlists)..where((t) => t.id.equals(playlistId))).go();
  }

  Future<void> addToPlaylist(int playlistId, String songId) async {
    final count = await (selectOnly(playlistItems)
          ..addColumns([playlistItems.songId])
          ..where(playlistItems.playlistId.equals(playlistId)))
        .get();
    await into(playlistItems).insert(
      PlaylistItemsCompanion.insert(
        playlistId: playlistId,
        songId: songId,
        position: count.length,
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  Future<void> removeFromPlaylist(int playlistId, String songId) async {
    await (delete(playlistItems)..where(
      (t) => t.playlistId.equals(playlistId) & t.songId.equals(songId),
    )).go();
  }

  Future<List<String>> songIdsInPlaylist(int playlistId) async {
    final rows = await (select(playlistItems)
          ..where((t) => t.playlistId.equals(playlistId))
          ..orderBy([(t) => OrderingTerm(expression: t.position)]))
        .get();
    return rows.map((row) => row.songId).toList();
  }

  Future<String?> preference(String key) async {
    final row = await (select(preferences)
          ..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> setPreference(String key, String value) async {
    await into(preferences).insertOnConflictUpdate(
      PreferencesCompanion.insert(key: key, value: value),
    );
  }
}
