import 'package:flutter_test/flutter_test.dart';

import 'package:kinos/arr/models/arr_library_entry.dart';
import 'package:kinos/arr/models/arr_library_item.dart';
import 'package:kinos/models/item_base_model.dart';
import 'package:kinos/models/items/item_shared_models.dart';
import 'package:kinos/models/items/overview_model.dart';
import 'package:kinos/models/syncing/database_item.dart';
import 'package:kinos/recommendations/adapters/recommendation_cache_adapter.dart';
import 'package:kinos/recommendations/models/candidate_item.dart';
import 'package:kinos/recommendations/models/scored_candidate.dart';
import 'package:kinos/recommendations/models/trait.dart';

ItemBaseModel _jellyfinItem(String id, {String name = 'A film', int? year}) {
  return ItemBaseModel(
    name: name,
    id: id,
    overview: OverviewModel(yearAired: year),
    parentId: null,
    playlistId: null,
    images: null,
    childCount: null,
    primaryRatio: null,
    userData: const UserData(),
    canDownload: null,
    canDelete: null,
    jellyType: null,
  );
}

ArrLibraryEntry _arrEntry(int id, {String title = 'A film', int? year}) {
  return ArrLibraryEntry.movie(ArrMovie(
    id: id,
    title: title,
    year: year,
    posterUrl: null,
    monitored: true,
    hasFile: false,
    qualityName: null,
    added: null,
    raw: const {},
  ));
}

ScoredCandidate _scored(String id, {String? justificationValue}) {
  return ScoredCandidate(
    item: CandidateItem(
      id: id,
      title: 'title',
      traits: const [],
      source: CandidateSource.jellyfinLibrary,
    ),
    score: 1,
    justification: justificationValue == null
        ? null
        : trait(TraitKind.studio, justificationValue),
  );
}

void main() {
  group('buildJellyfinCacheEntries', () {
    test('builds one companion per candidate with a matching item', () {
      final item = _jellyfinItem('item-1', name: 'Dune', year: 2021);
      final entries = buildJellyfinCacheEntries(
        'user-1',
        [_scored('item-1', justificationValue: 'A24')],
        {'item-1': item},
      );

      expect(entries, hasLength(1));
      final companion = entries.single;
      expect(companion.userId.value, 'user-1');
      expect(companion.rowKind.value, RecommendationRowKind.forYou);
      expect(companion.position.value, 0);
      expect(companion.source.value, RecommendationEntrySource.jellyfin);
      expect(companion.jellyfinItemId.value, 'item-1');
      expect(companion.title.value, 'Dune');
      expect(companion.year.value, 2021);
      expect(companion.justification.value, 'Produit par A24');
    });

    test(
        'reads year from overview.yearAired — the field actually populated '
        'for a server-loaded item (cf. OverviewModel.fromBaseItemDto)', () {
      const item = ItemBaseModel(
        name: 'A film',
        id: 'item-1',
        overview: OverviewModel(productionYear: 2021),
        parentId: null,
        playlistId: null,
        images: null,
        childCount: null,
        primaryRatio: null,
        userData: UserData(),
        canDownload: null,
        canDelete: null,
        jellyType: null,
      );
      final entries = buildJellyfinCacheEntries(
        'user-1',
        [_scored('item-1')],
        {'item-1': item},
      );

      expect(entries.single.year.value, isNull,
          reason: 'productionYear seul ne doit jamais suffire — c\'est '
              'exactement le bug calibré (année toujours nulle en cache)');
    });

    test('skips a candidate with no matching item — the id/object bridge', () {
      final entries = buildJellyfinCacheEntries(
        'user-1',
        [_scored('missing')],
        const {},
      );

      expect(entries, isEmpty);
    });

    test('positions entries in order, starting at 0', () {
      final items = {
        'a': _jellyfinItem('a'),
        'b': _jellyfinItem('b'),
      };
      final entries = buildJellyfinCacheEntries(
        'user-1',
        [_scored('a'), _scored('b')],
        items,
      );

      expect(entries.map((e) => e.position.value), [0, 1]);
    });

    test('never persists more than the configured limit', () {
      final items = {
        for (var i = 0; i < persistedRecommendationCacheLimit + 5; i++)
          'item-$i': _jellyfinItem('item-$i'),
      };
      final candidates = [
        for (var i = 0; i < persistedRecommendationCacheLimit + 5; i++)
          _scored('item-$i'),
      ];

      final entries = buildJellyfinCacheEntries('user-1', candidates, items);

      expect(entries, hasLength(persistedRecommendationCacheLimit));
    });
  });

  group('buildArrCacheEntries', () {
    test('builds one companion per candidate, radarr for a movie entry', () {
      final entry = _arrEntry(42, title: 'Evil Dead II', year: 1987);
      final entries = buildArrCacheEntries(
        'user-1',
        [_scored('arr:movie:42', justificationValue: 'Horreur')],
        {'arr:movie:42': entry},
      );

      expect(entries, hasLength(1));
      final companion = entries.single;
      expect(companion.rowKind.value, RecommendationRowKind.setAside);
      expect(companion.source.value, RecommendationEntrySource.arr);
      expect(companion.arrId.value, 42);
      expect(companion.arrService.value, 'radarr');
      expect(companion.title.value, 'Evil Dead II');
      expect(companion.year.value, 1987);
    });
  });

  group('sameCacheEntries', () {
    RecommendationCacheEntry cachedRow({
      required RecommendationEntrySource source,
      String? jellyfinItemId,
      int? arrId,
      String? justification,
    }) {
      return RecommendationCacheEntry(
        id: 1,
        userId: 'user-1',
        rowKind: RecommendationRowKind.forYou,
        position: 0,
        source: source,
        jellyfinItemId: jellyfinItemId,
        jellyfinItemType: null,
        arrId: arrId,
        arrService: null,
        title: 'A film',
        year: null,
        justification: justification,
        capturedAt: DateTime(2025, 1, 1),
      );
    }

    test('identical fresh/cached lists — no rebuild needed', () {
      final fresh = buildJellyfinCacheEntries(
        'user-1',
        [_scored('item-1', justificationValue: 'A24')],
        {'item-1': _jellyfinItem('item-1')},
      );
      final cached = [
        cachedRow(
          source: RecommendationEntrySource.jellyfin,
          jellyfinItemId: 'item-1',
          justification: 'Produit par A24',
        ),
      ];

      expect(sameCacheEntries(fresh, cached), isTrue);
    });

    test('different length — not the same', () {
      final fresh = buildJellyfinCacheEntries(
        'user-1',
        [_scored('item-1'), _scored('item-2')],
        {'item-1': _jellyfinItem('item-1'), 'item-2': _jellyfinItem('item-2')},
      );
      final cached = [
        cachedRow(
            source: RecommendationEntrySource.jellyfin,
            jellyfinItemId: 'item-1'),
      ];

      expect(sameCacheEntries(fresh, cached), isFalse);
    });

    test('same items, different order — not the same (rank matters)', () {
      final items = {'a': _jellyfinItem('a'), 'b': _jellyfinItem('b')};
      final fresh = buildJellyfinCacheEntries(
          'user-1', [_scored('a'), _scored('b')], items);
      final cached = [
        cachedRow(
            source: RecommendationEntrySource.jellyfin, jellyfinItemId: 'b'),
        cachedRow(
            source: RecommendationEntrySource.jellyfin, jellyfinItemId: 'a'),
      ];

      expect(sameCacheEntries(fresh, cached), isFalse);
    });

    test('same item but a different justification — not the same', () {
      final fresh = buildJellyfinCacheEntries(
        'user-1',
        [_scored('item-1', justificationValue: 'A24')],
        {'item-1': _jellyfinItem('item-1')},
      );
      final cached = [
        cachedRow(
          source: RecommendationEntrySource.jellyfin,
          jellyfinItemId: 'item-1',
          justification: 'Produit par Legendary',
        ),
      ];

      expect(sameCacheEntries(fresh, cached), isFalse);
    });
  });
}
