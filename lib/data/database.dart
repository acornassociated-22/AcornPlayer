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
  TextColumn get genre => text().nullable()();
  IntColumn get year => integer().nullable()();
  IntColumn get trackNumber => integer().nullable()();
  IntColumn get discNumber => integer().nullable()();
  TextColumn get albumArtist => text().nullable()();
  DateTimeColumn get addedAt => dateTime().nullable()();
  IntColumn get playCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastPlayedAt => dateTime().nullable()();
  IntColumn get fileModified => integer().nullable()();
  IntColumn get fileSize => integer().nullable()();

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
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.addColumn(cachedSongs, cachedSongs.genre);
        await migrator.addColumn(cachedSongs, cachedSongs.year);
        await migrator.addColumn(cachedSongs, cachedSongs.trackNumber);
        await migrator.addColumn(cachedSongs, cachedSongs.discNumber);
        await migrator.addColumn(cachedSongs, cachedSongs.albumArtist);
        await migrator.addColumn(cachedSongs, cachedSongs.addedAt);
        await migrator.addColumn(cachedSongs, cachedSongs.playCount);
        await migrator.addColumn(cachedSongs, cachedSongs.lastPlayedAt);
        await migrator.addColumn(cachedSongs, cachedSongs.fileModified);
        await migrator.addColumn(cachedSongs, cachedSongs.fileSize);
      }
    },
  );

  /// Maps a cached row back into a [Song].
  Song songFromRow(CachedSong row) {
    return Song(
      id: row.id,
      title: row.title,
      artist: row.artist,
      album: row.album,
      duration: Duration(milliseconds: row.durationMs),
      source: row.source,
      mediaStoreId: row.mediaStoreId,
      genre: row.genre,
      year: row.year,
      trackNumber: row.trackNumber,
      discNumber: row.discNumber,
      albumArtist: row.albumArtist,
      addedAt: row.addedAt,
      playCount: row.playCount,
      lastPlayedAt: row.lastPlayedAt,
      fileModified: row.fileModified,
      fileSize: row.fileSize,
    );
  }

  /// Every cached track, used to paint the library before a rescan.
  Future<List<Song>> cachedLibrary() async {
    final rows = await select(cachedSongs).get();
    return [for (final row in rows) songFromRow(row)];
  }

  /// Stores freshly scanned metadata without touching likes or play counts.
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
            genre: Value(song.genre),
            year: Value(song.year),
            trackNumber: Value(song.trackNumber),
            discNumber: Value(song.discNumber),
            albumArtist: Value(song.albumArtist),
            addedAt: Value(song.addedAt ?? DateTime.now()),
            fileModified: Value(song.fileModified),
            fileSize: Value(song.fileSize),
          ),
          onConflict: DoUpdate(
            (_) => CachedSongsCompanion(
              title: Value(song.title),
              artist: Value(song.artist),
              album: Value(song.album),
              durationMs: Value(song.duration.inMilliseconds),
              source: Value(song.source),
              mediaStoreId: Value(song.mediaStoreId),
              genre: Value(song.genre),
              year: Value(song.year),
              trackNumber: Value(song.trackNumber),
              discNumber: Value(song.discNumber),
              albumArtist: Value(song.albumArtist),
              fileModified: Value(song.fileModified),
              fileSize: Value(song.fileSize),
            ),
          ),
        );
      }
    });
  }

  /// Drops cache rows whose files are no longer on disk.
  Future<void> removeMissingSongs(Set<String> keepIds) async {
    await (delete(cachedSongs)..where((t) => t.id.isNotIn(keepIds))).go();
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

  /// Bumps the play counter after a meaningful listen.
  Future<void> recordPlay(String songId) async {
    final row = await (select(cachedSongs)
          ..where((t) => t.id.equals(songId)))
        .getSingleOrNull();
    if (row == null) return;
    await (update(cachedSongs)..where((t) => t.id.equals(songId))).write(
      CachedSongsCompanion(
        playCount: Value(row.playCount + 1),
        lastPlayedAt: Value(DateTime.now()),
      ),
    );
  }

  Stream<List<Playlist>> watchPlaylists() => select(playlists).watch();

  Future<int> createPlaylist(String name) =>
      into(playlists).insert(PlaylistsCompanion.insert(name: name));

  Future<void> renamePlaylist(int playlistId, String name) async {
    await (update(playlists)..where((t) => t.id.equals(playlistId))).write(
      PlaylistsCompanion(name: Value(name)),
    );
  }

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

  /// Rewrites playlist order to match [songIds].
  Future<void> reorderPlaylist(int playlistId, List<String> songIds) async {
    await batch((batch) {
      for (var index = 0; index < songIds.length; index++) {
        batch.update(
          playlistItems,
          PlaylistItemsCompanion(position: Value(index)),
          where: (t) =>
              t.playlistId.equals(playlistId) & t.songId.equals(songIds[index]),
        );
      }
    });
  }

  Future<int> playlistSongCount(int playlistId) async {
    final count = countAll();
    final row = await (selectOnly(playlistItems)
          ..addColumns([count])
          ..where(playlistItems.playlistId.equals(playlistId)))
        .getSingle();
    return row.read(count) ?? 0;
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
