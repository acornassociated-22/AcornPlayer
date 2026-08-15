import 'dart:typed_data';

import 'package:acorn_player/models/song.dart';
import 'package:acorn_player/services/artwork_cache.dart';
import 'package:acorn_player/services/library/library_source.dart';
import 'package:acorn_player/widgets/album_carousel.dart';
import 'package:acorn_player/widgets/progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _EmptyLibrarySource implements LibrarySource {
  @override
  Future<bool> requestAccess() async => true;

  @override
  Future<String?> defaultFolder() async => null;

  @override
  Future<String?> pickFolder() async => null;

  @override
  Future<List<Song>> loadSongs({String? folder}) async => const [];

  @override
  Future<Uint8List?> artwork(Song song) async => null;
}

Song _song(int index) => Song(
  id: 'song-$index',
  title: 'Track $index',
  artist: 'Artist $index',
  source: '/music/track-$index.mp3',
);

void main() {
  group('formatDuration', () {
    test('renders minutes and padded seconds', () {
      expect(formatDuration(const Duration(minutes: 2, seconds: 45)), '2:45');
      expect(formatDuration(const Duration(minutes: 6, seconds: 7)), '6:07');
    });

    test('adds the hour part for long tracks', () {
      expect(
        formatDuration(const Duration(hours: 1, minutes: 3, seconds: 9)),
        '1:03:09',
      );
    });
  });

  testWidgets('dragging the carousel left selects the next track', (
    tester,
  ) async {
    final selected = <int>[];

    await tester.pumpWidget(
      Provider<ArtworkCache>(
        create: (_) => ArtworkCache(_EmptyLibrarySource()),
        child: MaterialApp(
          home: Scaffold(
            body: AlbumCarousel(
              songs: [_song(0), _song(1), _song(2)],
              currentIndex: 0,
              onIndexChanged: selected.add,
            ),
          ),
        ),
      ),
    );

    // Just under one card slot, so it settles on the next cover.
    await tester.drag(find.byType(AlbumCarousel), const Offset(-90, 0));
    await tester.pumpAndSettle();

    expect(selected, [1]);
  });

  testWidgets('dragging back to the right returns to the previous track', (
    tester,
  ) async {
    final selected = <int>[];

    await tester.pumpWidget(
      Provider<ArtworkCache>(
        create: (_) => ArtworkCache(_EmptyLibrarySource()),
        child: MaterialApp(
          home: Scaffold(
            body: AlbumCarousel(
              songs: [_song(0), _song(1), _song(2)],
              currentIndex: 1,
              onIndexChanged: selected.add,
            ),
          ),
        ),
      ),
    );

    await tester.drag(find.byType(AlbumCarousel), const Offset(90, 0));
    await tester.pumpAndSettle();

    expect(selected, [0]);
  });
}
