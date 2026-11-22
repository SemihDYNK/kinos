import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/letterboxd/letterboxd_model.dart';
import 'package:kinos/models/syncing/database_item.dart';
import 'package:kinos/recommendations/models/trait.dart';
import 'package:kinos/stats/viewing_backfill.dart';
import 'package:kinos/stats/viewing_log.dart';

ViewingEvent event(String identity, DateTime at,
        {Set<ViewingSource> sources = const {ViewingSource.kinos},
        int watched = 0,
        bool completed = true,
        List<String> genres = const []}) =>
    ViewingEvent(
        identity: identity,
        kind: 'movie',
        title: identity,
        at: at,
        watchedSeconds: watched,
        completed: completed,
        sources: sources,
        genres: genres);

void main() {
  test('one title, one day, one viewing; Kinos time wins over a bare day', () {
    final letterboxd = event('tmdb:movie:1', DateTime(2026, 3, 2),
        sources: {ViewingSource.letterboxd}, genres: ['Drame']);
    final kinos = event('tmdb:movie:1', DateTime(2026, 3, 2, 21, 30),
        watched: 5400, completed: false);
    expect(letterboxd.key, kinos.key);
    final merged = letterboxd.merge(kinos);
    expect(merged.at, DateTime(2026, 3, 2, 21, 30));
    expect(merged.watchedSeconds, 5400);
    expect(merged.completed, isTrue);
    expect(merged.genres, ['Drame']);
    expect(merged.sources, {ViewingSource.letterboxd, ViewingSource.kinos});
    // Deux reprises dans Kinos le même jour : les durées s'ajoutent.
    expect(kinos.merge(kinos).watchedSeconds, 10800);
    expect(ViewingEvent.fromJson(merged.toJson())!.key, merged.key);
  });

  test('every Letterboxd diary date is a viewing, rewatches flagged', () {
    final events = letterboxdViewings(LetterboxdSnapshot(records: [
      LetterboxdRecord(
          LetterboxdFilm(
              uri: 'https://letterboxd.com/film/dune/',
              title: 'Dune',
              year: 2021,
              viewings: [DateTime(2021, 9, 15), DateTime(2024, 3, 1)]),
          work: LetterboxdWork(title: 'Dune', tmdbId: 438631, traits: [
            trait(TraitKind.genre, 'Science Fiction'),
            trait(TraitKind.director, 'Denis Villeneuve'),
          ])),
      // Sans date de journal : pas dans la frise.
      const LetterboxdRecord(
          LetterboxdFilm(uri: 'https://letterboxd.com/film/x/', title: 'X')),
      // Import d'avant les dates du journal : la dernière séance seulement.
      LetterboxdRecord(LetterboxdFilm(
          uri: 'https://letterboxd.com/film/y/',
          title: 'Y',
          watchedAt: DateTime(2026, 7, 8))),
    ]));
    expect(events.length, 3);
    expect(events.last.identity, 'letterboxd:y');
    expect(events.last.at, DateTime(2026, 7, 8));
    events.removeLast();
    expect(events.first.identity, 'tmdb:movie:438631');
    expect(events.first.rewatch, isFalse);
    expect(events.last.rewatch, isTrue);
    expect(events.first.genres, ['Science Fiction']);
    expect(events.first.directors, ['Denis Villeneuve']);
  });

  test('a Jellyfin last play a day away from a known viewing is dropped', () {
    final known = [
      event('tmdb:movie:1', DateTime(2026, 3, 2),
          sources: {ViewingSource.letterboxd})
    ];
    final kept = withoutNearDuplicates([
      event('tmdb:movie:1', DateTime(2026, 3, 3, 0, 40),
          sources: {ViewingSource.jellyfin}),
      event('tmdb:movie:1', DateTime(2026, 6, 1),
          sources: {ViewingSource.jellyfin}),
      event('tmdb:movie:2', DateTime(2026, 3, 2),
          sources: {ViewingSource.jellyfin}),
    ], known);
    expect([for (final e in kept) (e.identity, e.at.month)],
        [('tmdb:movie:1', 6), ('tmdb:movie:2', 3)]);
  });

  test('the store merges by day and forgets a source on rebuild', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final db = AppDatabase(
        container.read(Provider<Ref>((r) => r)), NativeDatabase.memory());
    addTearDown(db.close);
    final store = ViewingLogStore(db, 'p');
    await store.addAll([
      event('a', DateTime(2026, 1, 1), sources: {ViewingSource.letterboxd}),
      event('a', DateTime(2026, 1, 1, 20), watched: 3000),
      event('b', DateTime(2026, 1, 2), sources: {ViewingSource.letterboxd}),
    ]);
    expect((await store.all()).length, 2);
    await store.removeSource(ViewingSource.letterboxd);
    final left = await store.all();
    // « a » vient aussi de Kinos : il reste ; « b » ne venait que de
    // Letterboxd.
    expect(left.map((e) => e.identity), ['a']);
  });
}
