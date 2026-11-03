import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/anilist/mapping.dart';

void main() {
  late AnilistCatalogIndex index;
  setUp(() => index = AnilistCatalogIndex.fromJson(jsonDecode(
      File('test/anilist/fixtures/catalog.json').readAsStringSync())));
  AnilistTarget target(Map<String, Object?> ids,
          {AnilistTargetKind kind = AnilistTargetKind.movie,
          int? season,
          String? basis}) =>
      AnilistTarget(
          itemId: 'a',
          title: 'Title',
          kind: kind,
          ids: ids,
          season: season,
          seasonSource: basis);
  test('normalizes aliases, case and whitespace without accepting bad IDs', () {
    final ids = AnilistIds.from({
      'AniList': ' 164 ',
      'MyAnimeList': 164,
      'IMDB': ' tt0119698 ',
      'Tvdb': -1,
      'anidb': '1.5',
      'other': 42
    });
    expect(ids.values, {'anilist': '164', 'mal': '164', 'imdb': 'tt0119698'});
    expect(AnilistIds.from({'tmdb': true, 'tvdb': 0}).values, isEmpty);
    expect(AnilistIds.from({'TMDB': '1', 'tmdb': '2'}).conflicting, isTrue);
  });
  test('keeps film and TV TMDB namespaces distinct', () {
    expect(
        resolveAnilistTarget(target({'Tmdb': '128'}), index)
            .candidates
            .single
            .id,
        164);
    expect(
        resolveAnilistTarget(
                target({'Tmdb': '128'}, kind: AnilistTargetKind.series), index)
            .candidates
            .map((c) => c.id),
        [100, 101]);
  });
  test(
      'one exact result retains provenance and duplicate rows are deduplicated',
      () {
    final match = resolveAnilistTarget(
        target({'IMDb': 'tt0119698', 'AniDb': '7'}), index);
    expect(match.status, AnilistMatchStatus.exact);
    expect(match.candidates.single.sources, containsAll(['imdb', 'anidb']));
  });
  test('conflicting IDs cannot silently pick a first match', () {
    final match =
        resolveAnilistTarget(target({'Tmdb': '128', 'MAL': '1535'}), index);
    expect(match.status, AnilistMatchStatus.needsConfirmation);
    expect(match.reason, AnilistMatchReason.conflictingIds);
    expect(match.candidates.map((c) => c.id), containsAll([164, 1535]));
  });
  test(
      'unknown provider has no bearing on another exact match',
      () => expect(
          resolveAnilistTarget(target({'Tmdb': '128', 'random': '100'}), index)
              .status,
          AnilistMatchStatus.exact));
  test('a parent series ID never establishes the identity of a season', () {
    final t = AnilistTarget(
        itemId: 'season',
        title: 'Naruto',
        kind: AnilistTargetKind.season,
        parentIds: {'AniList': '1735', 'Tmdb': '31910'},
        season: 3);
    final m = resolveAnilistTarget(t, index);
    expect(m.candidates.single.id, 1735);
    expect(m.status, AnilistMatchStatus.needsConfirmation);
  });
  test('a season needs a proven numbering basis', () {
    final t = AnilistTarget(
        itemId: 's',
        title: 'TV',
        kind: AnilistTargetKind.season,
        parentIds: {'Tmdb': '128'},
        season: 1);
    expect(resolveAnilistTarget(t, index).candidates, hasLength(2));
    expect(
        resolveAnilistTarget(t.copyWithSeasonSource('tmdb'), index)
            .candidates
            .single
            .id,
        100);
    expect(resolveAnilistTarget(t.copyWithSeasonSource('tvdb'), index).status,
        AnilistMatchStatus.notFound);
  });
  test(
      'own season TMDB IDs are not series IDs',
      () => expect(
          resolveAnilistTarget(
                  target({'Tmdb': '128'},
                      kind: AnilistTargetKind.season, season: 0),
                  index)
              .status,
          AnilistMatchStatus.notFound));
  test(
      'direct AniList on the season itself is exact',
      () => expect(
          resolveAnilistTarget(
                  target({'AniList': '1735'},
                      kind: AnilistTargetKind.season, season: 0),
                  index)
              .status,
          AnilistMatchStatus.exact));
  test('null season differs from specials and fingerprints are stable', () {
    final a = target({'TMDB': '128', 'IMDb': 'tt0119698'});
    final b = target({'imdb': 'tt0119698', 'tmdb': '128'});
    expect(a.fingerprint, b.fingerprint);
    expect(
        target({}, kind: AnilistTargetKind.season).fingerprint,
        isNot(
            target({}, kind: AnilistTargetKind.season, season: 0).fingerprint));
  });
  test('JoJo preserves both AniList parts and their TVDB episode offsets', () {
    final t = AnilistTarget(
        itemId: 'jojo-s2',
        title: 'JoJo',
        kind: AnilistTargetKind.season,
        parentIds: {'Tvdb': 262954},
        season: 2,
        seasonSource: 'tvdb');
    final match = resolveAnilistTarget(t, index);
    expect(match.status, AnilistMatchStatus.needsConfirmation);
    expect(match.reason, AnilistMatchReason.splitSeason);
    expect(match.candidates.map((c) => c.id), [20474, 20799]);
    expect(match.candidates.last.episodeMappings.single,
        (source: 'tvdb', season: 2, offset: 24));
    expect(match.candidates.first.episodeMappings.single.offset, isNull);
    expect(
        match.candidates.last
            .withMedia(
                const AnilistMedia(id: 20799, title: 'Egypt', episodes: 24))
            .episodeMappings
            .single
            .offset,
        24);
  });
  test('invalid catalogs fail, partial rows and invalid entries are skipped',
      () {
    expect(() => AnilistCatalogIndex.fromJson({}), throwsFormatException);
    final partial = AnilistCatalogIndex.fromJson([
      null,
      {},
      {'anilist_id': true},
      {
        'anilist_id': 164,
        'themoviedb_id': {
          'movie': [128]
        }
      }
    ]);
    expect(
        resolveAnilistTarget(target({'tmdb': 128}), partial)
            .candidates
            .single
            .id,
        164);
  });
}
