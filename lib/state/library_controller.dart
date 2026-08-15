import 'package:flutter/foundation.dart';

import '../data/database.dart';
import '../models/song.dart';
import '../services/library/library_source.dart';

enum LibraryTab { albums, playlists, songs, favorites }

enum LibraryStatus { loading, needsPermission, needsFolder, ready }

/// What the list area of the library screen should render right now.
enum LibraryView { songs, albums, playlists }

const _folderPreferenceKey = 'music_folder';

/// Holds the scanned library, the liked set and the browsing state (tab,
/// selected album or playlist).
class LibraryController extends ChangeNotifier {
  LibraryController(this._db, this._source);

  final AppDatabase _db;
  final LibrarySource _source;

  LibraryStatus _status = LibraryStatus.loading;
  List<Song> _songs = const [];
  Set<String> _likedIds = const {};
  List<Playlist> _playlists = const [];
  LibraryTab _tab = LibraryTab.songs;
  bool _likedOnly = false;
  bool _gridSongs = false;
  String? _selectedAlbum;
  int? _selectedPlaylistId;
  List<String> _selectedPlaylistSongIds = const [];
  String? _folder;

  LibraryStatus get status => _status;

  List<Song> get allSongs => _songs;

  List<Playlist> get playlists => _playlists;

  LibraryTab get tab => _tab;

  bool get likedOnly => _likedOnly;

  bool get gridSongs => _gridSongs;

  String? get selectedAlbum => _selectedAlbum;

  int? get selectedPlaylistId => _selectedPlaylistId;

  bool get canGoBack => _selectedAlbum != null || _selectedPlaylistId != null;

  LibraryView get view {
    if (_tab == LibraryTab.albums && _selectedAlbum == null) {
      return LibraryView.albums;
    }
    if (_tab == LibraryTab.playlists && _selectedPlaylistId == null) {
      return LibraryView.playlists;
    }
    return LibraryView.songs;
  }

  /// Title shown in the app bar, mirroring the current selection.
  String get title {
    if (_selectedAlbum != null) return _selectedAlbum!;
    if (_selectedPlaylistId != null) {
      for (final playlist in _playlists) {
        if (playlist.id == _selectedPlaylistId) return playlist.name;
      }
      return 'Playlist';
    }
    return switch (_tab) {
      LibraryTab.albums => 'Albums',
      LibraryTab.playlists => 'Playlists',
      LibraryTab.songs => _likedOnly ? 'Liked Songs' : 'All Songs',
      LibraryTab.favorites => 'Favorites',
    };
  }

  List<String> get albums {
    final names = _songs
        .map((song) => song.album?.trim())
        .whereType<String>()
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList();
    names.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return names;
  }

  /// Songs currently listed, honouring album, playlist and liked filters.
  List<Song> get visibleSongs {
    if (_selectedAlbum != null) {
      return _songs.where((song) => song.album == _selectedAlbum).toList();
    }
    if (_selectedPlaylistId != null) {
      final byId = {for (final song in _songs) song.id: song};
      return _selectedPlaylistSongIds
          .map((id) => byId[id])
          .whereType<Song>()
          .toList();
    }
    if (_tab == LibraryTab.favorites || _likedOnly) {
      return _songs.where((song) => _likedIds.contains(song.id)).toList();
    }
    return _songs;
  }

  bool isLiked(Song song) => _likedIds.contains(song.id);

  int songCountInAlbum(String album) =>
      _songs.where((song) => song.album == album).length;

  /// Loads the persisted state, then the songs themselves.
  Future<void> initialise() async {
    _likedIds = await _db.likedSongIds();
    _playlists = await _db.select(_db.playlists).get();
    _folder = await _db.preference(_folderPreferenceKey);

    if (!await _source.requestAccess()) {
      _status = LibraryStatus.needsPermission;
      notifyListeners();
      return;
    }

    _folder ??= await _source.defaultFolder();
    if (_folder == null) {
      _status = LibraryStatus.needsFolder;
      notifyListeners();
      return;
    }

    await _scan();
  }

  Future<void> pickFolder() async {
    final folder = await _source.pickFolder();
    if (folder == null) return;
    _folder = folder;
    await _db.setPreference(_folderPreferenceKey, folder);
    await _scan();
  }

  Future<void> refresh() => _scan();

  Future<void> toggleLike(Song song) async {
    final liked = !_likedIds.contains(song.id);
    final updated = Set<String>.of(_likedIds);
    if (liked) {
      updated.add(song.id);
    } else {
      updated.remove(song.id);
    }
    _likedIds = updated;
    notifyListeners();
    await _db.setLiked(song.id, liked);
  }

  void selectTab(LibraryTab tab) {
    if (_tab == tab) return;
    _tab = tab;
    _selectedAlbum = null;
    _selectedPlaylistId = null;
    notifyListeners();
  }

  void toggleLikedOnly() {
    _likedOnly = !_likedOnly;
    notifyListeners();
  }

  /// Switches the song list between rows and cover cards.
  void toggleSongLayout() {
    _gridSongs = !_gridSongs;
    notifyListeners();
  }

  void openAlbum(String album) {
    _selectedAlbum = album;
    notifyListeners();
  }

  Future<void> openPlaylist(int playlistId) async {
    _selectedPlaylistId = playlistId;
    _selectedPlaylistSongIds = await _db.songIdsInPlaylist(playlistId);
    notifyListeners();
  }

  void goBack() {
    _selectedAlbum = null;
    _selectedPlaylistId = null;
    _selectedPlaylistSongIds = const [];
    notifyListeners();
  }

  Future<void> createPlaylist(String name) async {
    await _db.createPlaylist(name);
    _playlists = await _db.select(_db.playlists).get();
    notifyListeners();
  }

  Future<void> addToPlaylist(int playlistId, Song song) async {
    await _db.addToPlaylist(playlistId, song.id);
    if (playlistId == _selectedPlaylistId) {
      _selectedPlaylistSongIds = await _db.songIdsInPlaylist(playlistId);
      notifyListeners();
    }
  }

  Future<void> _scan() async {
    _status = LibraryStatus.loading;
    notifyListeners();

    _songs = await _source.loadSongs(folder: _folder);
    await _db.cacheSongs(_songs);
    _likedIds = await _db.likedSongIds();
    _status = LibraryStatus.ready;
    notifyListeners();
  }
}
