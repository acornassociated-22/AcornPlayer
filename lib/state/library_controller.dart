import 'package:flutter/foundation.dart';

import '../data/database.dart';
import '../l10n/app_strings.dart';
import '../models/song.dart';
import '../services/library/library_source.dart';

enum LibraryTab { artists, playlists, songs, favorites }

enum LibraryStatus { loading, scanning, needsPermission, needsFolder, ready }

/// What the list area of the library screen should render right now.
enum LibraryView { songs, playlists, artists }

enum LibrarySort { title, artist, album, duration, recent, played }

const _folderPreferenceKey = 'music_folder';
const _sortPreferenceKey = 'library_sort';

/// Holds the scanned library, the liked set and the browsing state (tab,
/// selected artist or playlist).
class LibraryController extends ChangeNotifier {
  LibraryController(this._db, this._source);

  final AppDatabase _db;
  final LibrarySource _source;

  LibraryStatus _status = LibraryStatus.loading;
  List<Song> _songs = const [];
  Set<String> _likedIds = const {};
  List<Playlist> _playlists = const [];
  Map<int, int> _playlistCounts = const {};
  LibraryTab _tab = LibraryTab.songs;
  bool _likedOnly = false;
  bool _gridSongs = false;
  String? _selectedArtist;
  int? _selectedPlaylistId;
  List<String> _selectedPlaylistSongIds = const [];
  String? _folder;
  String _query = '';
  LibrarySort _sort = LibrarySort.title;
  int _scanDone = 0;
  int _scanTotal = 0;
  bool _cancelScan = false;

  LibraryStatus get status => _status;

  List<Song> get allSongs => _songs;

  List<Playlist> get playlists => _playlists;

  LibraryTab get tab => _tab;

  bool get likedOnly => _likedOnly;

  bool get gridSongs => _gridSongs;

  String? get selectedArtist => _selectedArtist;

  int? get selectedPlaylistId => _selectedPlaylistId;

  /// Song ids already in the opened playlist.
  Set<String> get openPlaylistSongIds => _selectedPlaylistSongIds.toSet();

  String? get folder => _folder;

  String get query => _query;

  LibrarySort get sort => _sort;

  int get scanDone => _scanDone;

  int get scanTotal => _scanTotal;

  bool get isScanning => _status == LibraryStatus.scanning;

  bool get canGoBack =>
      _selectedArtist != null || _selectedPlaylistId != null;

  LibraryView get view {
    if (_tab == LibraryTab.playlists && _selectedPlaylistId == null) {
      return LibraryView.playlists;
    }
    if (_tab == LibraryTab.artists && _selectedArtist == null) {
      return LibraryView.artists;
    }
    return LibraryView.songs;
  }

  /// Title shown in the app bar, mirroring the current selection.
  String titleFor(AppStrings strings) {
    if (_selectedArtist != null) return _selectedArtist!;
    if (_selectedPlaylistId != null) {
      for (final playlist in _playlists) {
        if (playlist.id == _selectedPlaylistId) return playlist.name;
      }
      return strings['playlist'];
    }
    return switch (_tab) {
      LibraryTab.playlists => strings['playlists'],
      LibraryTab.songs =>
        _likedOnly ? strings['likedSongs'] : strings['allSongs'],
      LibraryTab.favorites => strings['favorites'],
      LibraryTab.artists => strings['artists'],
    };
  }

  /// English title used by tests and callers without a locale.
  String get title => titleFor(AppStrings.en);

  List<String> get albums => _unique(_songs.map((song) => song.album));

  List<String> get artists => _unique(_songs.map((song) => song.artist));

  /// Songs currently listed, honouring filters, search and sort.
  List<Song> get visibleSongs {
    final scoped = _scopedSongs;
    final needle = _query.trim().toLowerCase();
    final filtered = needle.isEmpty
        ? scoped
        : scoped.where((song) => _matches(song, needle)).toList();
    return _sorted(filtered);
  }

  /// Artists matching the current search.
  List<String> get visibleArtists => _filterNames(artists);

  /// Playlists matching the current search.
  List<Playlist> get visiblePlaylists {
    final needle = _query.trim().toLowerCase();
    if (needle.isEmpty) return _playlists;
    return _playlists
        .where((playlist) => playlist.name.toLowerCase().contains(needle))
        .toList();
  }

  int playlistCount(int playlistId) => _playlistCounts[playlistId] ?? 0;

  /// Songs in the current tab or opened collection, before search.
  List<Song> get _scopedSongs {
    if (_selectedArtist != null) {
      return _songs.where((song) => song.artist == _selectedArtist).toList();
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

  /// Whether [song] title, artist, album or genre contains [needle].
  bool _matches(Song song, String needle) {
    return song.title.toLowerCase().contains(needle) ||
        song.artist.toLowerCase().contains(needle) ||
        (song.album?.toLowerCase().contains(needle) ?? false) ||
        (song.genre?.toLowerCase().contains(needle) ?? false);
  }

  List<String> _filterNames(List<String> names) {
    final needle = _query.trim().toLowerCase();
    if (needle.isEmpty) return names;
    return names.where((name) => name.toLowerCase().contains(needle)).toList();
  }

  List<String> _unique(Iterable<String?> values) {
    final names = values
        .map((value) => value?.trim())
        .whereType<String>()
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList();
    names.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return names;
  }

  List<Song> _sorted(List<Song> songs) {
    final copy = [...songs];
    int byTitle(Song a, Song b) =>
        a.title.toLowerCase().compareTo(b.title.toLowerCase());
    copy.sort((a, b) {
      final compared = switch (_sort) {
        LibrarySort.title => byTitle(a, b),
        LibrarySort.artist => a.artist.toLowerCase().compareTo(
          b.artist.toLowerCase(),
        ),
        LibrarySort.album => (a.album ?? '').toLowerCase().compareTo(
          (b.album ?? '').toLowerCase(),
        ),
        LibrarySort.duration => a.duration.compareTo(b.duration),
        LibrarySort.recent => (b.addedAt ?? DateTime(0)).compareTo(
          a.addedAt ?? DateTime(0),
        ),
        LibrarySort.played => b.playCount.compareTo(a.playCount),
      };
      return compared != 0 ? compared : byTitle(a, b);
    });
    return copy;
  }

  /// Updates the live song filter. Empty text shows the full scoped list.
  void setQuery(String value) {
    if (value == _query) return;
    _query = value;
    notifyListeners();
  }

  Future<void> setSort(LibrarySort value) async {
    if (_sort == value) return;
    _sort = value;
    notifyListeners();
    await _db.setPreference(_sortPreferenceKey, value.name);
  }

  bool isLiked(Song song) => _likedIds.contains(song.id);

  int songCountForArtist(String artist) =>
      _songs.where((song) => song.artist == artist).length;

  /// Loads the persisted cache first, then rescans in the background.
  Future<void> initialise() async {
    _likedIds = await _db.likedSongIds();
    await _reloadPlaylists();
    _folder = await _db.preference(_folderPreferenceKey);
    final sortName = await _db.preference(_sortPreferenceKey);
    _sort = LibrarySort.values.firstWhere(
      (value) => value.name == sortName,
      orElse: () => LibrarySort.title,
    );

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

    final cached = await _db.cachedLibrary();
    if (cached.isNotEmpty) {
      _songs = cached;
      _status = LibraryStatus.ready;
      notifyListeners();
    }

    await _scan(background: cached.isNotEmpty);
  }

  Future<void> pickFolder() async {
    final folder = await _source.pickFolder();
    if (folder == null) return;
    _folder = folder;
    await _db.setPreference(_folderPreferenceKey, folder);
    await _scan();
  }

  Future<void> refresh() => _scan();

  /// Asks the in-flight scan to stop after the current isolate returns.
  void cancelScan() => _cancelScan = true;

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

  /// Records that [song] was listened to long enough to count as a play.
  Future<void> recordPlay(Song song) async {
    await _db.recordPlay(song.id);
    _songs = [
      for (final item in _songs)
        if (item.id == song.id)
          item.copyWith(
            playCount: item.playCount + 1,
            lastPlayedAt: DateTime.now(),
          )
        else
          item,
    ];
    notifyListeners();
  }

  void selectTab(LibraryTab tab) {
    if (_tab == tab) return;
    _tab = tab;
    _selectedArtist = null;
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

  void openArtist(String artist) {
    _selectedArtist = artist;
    notifyListeners();
  }

  Future<void> openPlaylist(int playlistId) async {
    _selectedPlaylistId = playlistId;
    _selectedPlaylistSongIds = await _db.songIdsInPlaylist(playlistId);
    notifyListeners();
  }

  void goBack() {
    _selectedArtist = null;
    _selectedPlaylistId = null;
    _selectedPlaylistSongIds = const [];
    notifyListeners();
  }

  Future<void> createPlaylist(String name) async {
    await _db.createPlaylist(name);
    await _reloadPlaylists();
    notifyListeners();
  }

  Future<void> renamePlaylist(int playlistId, String name) async {
    await _db.renamePlaylist(playlistId, name);
    await _reloadPlaylists();
    notifyListeners();
  }

  Future<void> deletePlaylist(int playlistId) async {
    await _db.deletePlaylist(playlistId);
    if (_selectedPlaylistId == playlistId) goBack();
    await _reloadPlaylists();
    notifyListeners();
  }

  Future<void> addToPlaylist(int playlistId, Song song) async {
    await _db.addToPlaylist(playlistId, song.id);
    if (playlistId == _selectedPlaylistId) {
      _selectedPlaylistSongIds = await _db.songIdsInPlaylist(playlistId);
    }
    await _reloadPlaylists();
    notifyListeners();
  }

  Future<void> removeFromPlaylist(int playlistId, Song song) async {
    await _db.removeFromPlaylist(playlistId, song.id);
    if (playlistId == _selectedPlaylistId) {
      _selectedPlaylistSongIds = await _db.songIdsInPlaylist(playlistId);
    }
    await _reloadPlaylists();
    notifyListeners();
  }

  Future<void> reorderPlaylistSongs(int from, int to) async {
    final playlistId = _selectedPlaylistId;
    if (playlistId == null) return;
    final next = [..._selectedPlaylistSongIds];
    if (from < 0 || from >= next.length || from == to) return;
    final dest = to.clamp(0, next.length - 1);
    final id = next.removeAt(from);
    next.insert(dest, id);
    _selectedPlaylistSongIds = next;
    notifyListeners();
    await _db.reorderPlaylist(playlistId, next);
  }

  Future<void> _reloadPlaylists() async {
    _playlists = await _db.select(_db.playlists).get();
    final counts = <int, int>{};
    for (final playlist in _playlists) {
      counts[playlist.id] = await _db.playlistSongCount(playlist.id);
    }
    _playlistCounts = counts;
  }

  Future<void> _scan({bool background = false}) async {
    _cancelScan = false;
    _scanDone = 0;
    _scanTotal = 0;
    if (!background || _songs.isEmpty) {
      _status = LibraryStatus.scanning;
    }
    notifyListeners();

    final cached = {for (final song in _songs) song.id: song};
    final songs = await _source.loadSongs(
      folder: _folder,
      cached: cached,
      onProgress: (done, total) {
        _scanDone = done;
        _scanTotal = total;
        notifyListeners();
      },
      isCancelled: () => _cancelScan,
    );

    if (_cancelScan) {
      _status = LibraryStatus.ready;
      notifyListeners();
      return;
    }

    _songs = songs;
    await _db.cacheSongs(songs);
    await _db.removeMissingSongs(songs.map((song) => song.id).toSet());
    _likedIds = await _db.likedSongIds();
    _songs = await _db.cachedLibrary();
    _status = LibraryStatus.ready;
    notifyListeners();
  }
}
