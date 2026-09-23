import 'package:flutter_test/flutter_test.dart';

import 'package:kinos/arr/models/arr_library_entry.dart';
import 'package:kinos/arr/models/arr_library_item.dart';
import 'package:kinos/recommendations/adapters/arr_candidate_adapter.dart';
import 'package:kinos/recommendations/models/candidate_item.dart';
import 'package:kinos/recommendations/models/trait.dart';

ArrLibraryEntry _movie({
  required int id,
  bool hasFile = true,
  int? year = 2015,
  List<String> genres = const ['Thriller'],
  Map<String, dynamic> extraRaw = const {},
}) {
  return ArrLibraryEntry.movie(ArrMovie(
    id: id,
    title: 'Movie $id',
    year: year,
    posterUrl: null,
    monitored: true,
    hasFile: hasFile,
    qualityName: null,
    added: null,
    raw: {'genres': genres, ...extraRaw},
  ));
}

ArrLibraryEntry _series({
  required int id,
  int episodeFileCount = 1,
  int? year = 2018,
  List<String> genres = const ['Drama'],
  Map<String, dynamic> extraRaw = const {},
}) {
  return ArrLibraryEntry.series(ArrSeries(
    id: id,
    title: 'Series $id',
    year: year,
    posterUrl: null,
    monitored: true,
    seasonCount: 1,
    episodeCount: 10,
    episodeFileCount: episodeFileCount,
    added: null,
    raw: {'genres': genres, ...extraRaw},
  ));
}

void main() {
  test('builds a candidate from a movie with a file, tagged arrOnly', () {
    final candidates = buildArrCandidates([_movie(id: 1)]);

    expect(candidates, hasLength(1));
    expect(candidates.single.id, 'arr:movie:1');
    expect(candidates.single.source, CandidateSource.arrOnly);
    expect(candidates.single.traits, contains(trait(TraitKind.genre, 'Thriller')));
    expect(candidates.single.traits, contains(trait(TraitKind.decade, '2010')));
  });

  test('builds a candidate from a series with at least one episode file', () {
    final candidates = buildArrCandidates([_series(id: 2)]);

    expect(candidates, hasLength(1));
    expect(candidates.single.id, 'arr:series:2');
  });

  test('skips a movie with no file yet — nothing to actually recommend', () {
    final candidates = buildArrCandidates([_movie(id: 1, hasFile: false)]);

    expect(candidates, isEmpty);
  });

  test('skips a series with no episode file yet', () {
    final candidates = buildArrCandidates([_series(id: 2, episodeFileCount: 0)]);

    expect(candidates, isEmpty);
  });

  test('skips an entry with no genres and no known year — nothing to score',
      () {
    final candidates =
        buildArrCandidates([_movie(id: 1, genres: const [], year: null)]);

    expect(candidates, isEmpty);
  });

  test('reads genres straight off the raw JSON kept for PUT requests', () {
    final candidates =
        buildArrCandidates([_movie(id: 1, genres: const ['Horror', 'Comedy'])]);

    expect(candidates.single.traits, contains(trait(TraitKind.genre, 'Horror')));
    expect(candidates.single.traits, contains(trait(TraitKind.genre, 'Comedy')));
  });

  test('adds a studio trait from a movie\'s raw "studio" field', () {
    final candidates = buildArrCandidates(
        [_movie(id: 1, extraRaw: const {'studio': 'Legendary Pictures'})]);

    expect(candidates.single.traits,
        contains(trait(TraitKind.studio, 'Legendary Pictures')));
  });

  test('adds a studio trait from a series\' raw "network" field', () {
    final candidates =
        buildArrCandidates([_series(id: 2, extraRaw: const {'network': 'HBO'})]);

    expect(candidates.single.traits, contains(trait(TraitKind.studio, 'HBO')));
  });

  test('no studio trait when studio/network is absent', () {
    final candidates = buildArrCandidates([_movie(id: 1)]);

    expect(candidates.single.traits.any((t) => t.kind == TraitKind.studio),
        isFalse);
  });
}
