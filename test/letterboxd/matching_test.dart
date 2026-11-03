import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/letterboxd/letterboxd_model.dart';
import 'package:kinos/letterboxd/letterboxd_matching.dart';
import 'package:kinos/recommendations/models/watch_event.dart';
import 'package:kinos/recommendations/models/watch_signal.dart';
import 'package:kinos/recommendations/models/trait.dart';
import 'package:kinos/recommendations/engine/taste_profile_builder.dart';

const genre = (kind: TraitKind.genre, value: 'drama');
const work = LetterboxdWork(
    title: 'Film', year: 2000, tmdbId: 1, jellyfinId: 'local', traits: [genre]);
LetterboxdFilm film(
        {double? rating, int watches = 1, String uri = 'https://boxd.it/a'}) =>
    LetterboxdFilm(
        uri: uri, title: 'Film', year: 2000, rating: rating, watches: watches);
void main() {
  test('an unresolved watch excludes all editions after one unique work match',
      () {
    expect(
        letterboxdWatchedLibraryIds([
          LetterboxdRecord(film())
        ], const [
          LetterboxdWork(
              title: 'Film',
              year: 2000,
              tmdbId: 1,
              jellyfinId: 'A',
              traits: []),
          LetterboxdWork(
              title: 'Film',
              year: 2000,
              tmdbId: 1,
              jellyfinId: 'B',
              traits: []),
        ]),
        {'A', 'B'});
  });
  test(
      'watched exclusions include neutral ratings, translated titles and editions but not remakes',
      () {
    const library = [
      LetterboxdWork(
          title: 'Titre français',
          year: 2000,
          tmdbId: 1,
          jellyfinId: 'edition1',
          traits: [genre]),
      LetterboxdWork(
          title: 'Other edition',
          year: 2000,
          tmdbId: 1,
          jellyfinId: 'edition2',
          traits: [genre]),
      LetterboxdWork(
          title: 'Film',
          year: 2020,
          tmdbId: 2,
          jellyfinId: 'remake',
          traits: [genre]),
      LetterboxdWork(
          title: 'Unmatched', year: 1999, jellyfinId: 'exact', traits: []),
    ];
    expect(
        letterboxdWatchedLibraryIds([
          LetterboxdRecord(film(rating: 3), work: work),
          const LetterboxdRecord(LetterboxdFilm(
              uri: 'https://boxd.it/b', title: 'Unmatched', year: 1999)),
        ], library),
        {'local', 'edition1', 'edition2', 'exact'});
    expect(letterboxdWatchedLibraryIds([], library), isEmpty);
  });
  test('automatic title/year matching is exact and rejects homonyms', () {
    expect(exactLetterboxdMatch(film(), [work]), work);
    expect(
        exactLetterboxdMatch(film(), [
          work,
          const LetterboxdWork(
              title: 'Film', year: 2000, tmdbId: 2, traits: [genre])
        ]),
        isNull);
    expect(
        exactLetterboxdMatch(film(), [
          const LetterboxdWork(
              title: 'Film 2', year: 2000, tmdbId: 2, traits: [genre])
        ]),
        isNull);
  });
  test('explicit low rating overrides Jellyfin once per work', () {
    final result = mergeLetterboxdEvents([
      const WatchEvent(
          itemId: 'local',
          traits: [genre],
          signal: WatchSignal.completedFavorite),
      const WatchEvent(
          itemId: 'edition2', traits: [genre], signal: WatchSignal.rewatched),
    ], [
      LetterboxdRecord(film(rating: .5), work: work)
    ], [
      work,
      const LetterboxdWork(
          title: 'Film',
          year: 2000,
          tmdbId: 1,
          jellyfinId: 'edition2',
          traits: [genre]),
    ]);
    expect(result.length, 1);
    expect(result.single.baseWeight, lessThan(0));
    expect(
        const TasteProfileBuilder().build(result).weightOf(genre), lessThan(0));
  });
  test('unrated import preserves stronger existing favorite and recent date',
      () {
    final date = DateTime(2026, 1, 1);
    final result = mergeLetterboxdEvents([
      WatchEvent(
          itemId: 'local',
          traits: [genre],
          signal: WatchSignal.completedFavorite,
          occurredAt: date)
    ], [
      LetterboxdRecord(film(), work: work)
    ], [
      work
    ]);
    expect(result.single.baseWeight, 1.5);
    expect(result.single.occurredAt, date);
  });
  test('unmatched entries have no effect and external work only adds an event',
      () {
    expect(mergeLetterboxdEvents([], [LetterboxdRecord(film())], []), isEmpty);
    final result = mergeLetterboxdEvents(
        [], [LetterboxdRecord(film(rating: 5), work: work)], []);
    expect(result.single.itemId, 'tmdb:movie:1');
    expect(result.single.baseWeight, 1.5);
  });
  test('a reimport or duplicate film URL cannot double a work contribution',
      () {
    final entries = [
      LetterboxdRecord(film(rating: 5), work: work),
      LetterboxdRecord(film(rating: 5, uri: 'https://boxd.it/b'), work: work)
    ];
    expect(mergeLetterboxdEvents([], entries, []).length, 1);
  });
  test(
      'legacy event weights stay identical and explicit neutral rating is neutral',
      () {
    expect(
        const WatchEvent(itemId: 'a', traits: [], signal: WatchSignal.rewatched)
            .baseWeight,
        2);
    expect(
        mergeLetterboxdEvents(
                [], [LetterboxdRecord(film(rating: 3), work: work)], [])
            .single
            .baseWeight,
        0);
  });
}
