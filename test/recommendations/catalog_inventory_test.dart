import 'package:flutter_test/flutter_test.dart';

import 'package:kinos/models/item_base_model.dart';
import 'package:kinos/models/items/item_shared_models.dart';
import 'package:kinos/models/items/overview_model.dart';
import 'package:kinos/recommendations/adapters/catalog_inventory.dart';
import 'package:kinos/recommendations/adapters/jellyfin_trait_extraction.dart';
import 'package:kinos/recommendations/models/library_trait_stats.dart';

ItemBaseModel _item(String id,
    {OverviewModel overview = const OverviewModel()}) {
  return ItemBaseModel(
    name: id,
    id: id,
    overview: overview,
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

void main() {
  group('dedupeByTmdbId', () {
    test('keeps only the first occurrence of a shared tmdbId', () {
      final items = [
        _item('kingsman-1',
            overview: const OverviewModel(providerIds: {'tmdb': '343668'})),
        _item('kingsman-2',
            overview: const OverviewModel(providerIds: {'tmdb': '343668'})),
      ];

      final result = dedupeByTmdbId(items);

      expect(result.map((e) => e.id), ['kingsman-1']);
    });

    test('never merges items with no known tmdbId', () {
      final items = [_item('a'), _item('b')];

      expect(dedupeByTmdbId(items), hasLength(2));
    });

    test('items with distinct tmdbIds are all kept', () {
      final items = [
        _item('a', overview: const OverviewModel(providerIds: {'tmdb': '1'})),
        _item('b', overview: const OverviewModel(providerIds: {'tmdb': '2'})),
      ];

      expect(dedupeByTmdbId(items), hasLength(2));
    });
  });

  group('wellRatedNeverWatched', () {
    test('keeps only items at or above the rating threshold, sorted descending',
        () {
      final items = [
        _item('low', overview: const OverviewModel(communityRating: 6.0)),
        _item('high', overview: const OverviewModel(communityRating: 9.0)),
        _item('mid', overview: const OverviewModel(communityRating: 7.5)),
      ];

      final result = wellRatedNeverWatched(items);

      expect(result.map((e) => e.id), ['high', 'mid']);
    });

    test('an item with no rating is excluded', () {
      final items = [_item('unrated')];

      expect(wellRatedNeverWatched(items), isEmpty);
    });
  });

  group('canonicalGenreLabel', () {
    test('translates known English movie/TV genres to French', () {
      expect(canonicalGenreLabel('Drama'), 'Drame');
      expect(canonicalGenreLabel('War & Politics'), 'Guerre');
      expect(canonicalGenreLabel('Science Fiction'), 'Science-fiction');
      expect(canonicalGenreLabel('war'), 'Guerre');
    });

    test('is case-insensitive on the lookup', () {
      expect(canonicalGenreLabel('DRAMA'), 'Drame');
      expect(canonicalGenreLabel('drama'), 'Drame');
    });

    test('an already-French or unknown genre passes through unchanged', () {
      expect(canonicalGenreLabel('Guerre'), 'Guerre');
      expect(canonicalGenreLabel('Film-Noir'), 'Film-Noir');
    });
  });

  group('genreRowPool', () {
    test(
        'excludes only the widest genre (relative to the median), keeps '
        'medium ones', () {
      final unwatched = [
        for (var i = 0; i < 40; i++)
          _item('drama-$i', overview: const OverviewModel(genres: ['Drama'])),
        for (var i = 0; i < 12; i++)
          _item('comedy-$i', overview: const OverviewModel(genres: ['Comedy'])),
        for (var i = 0; i < 11; i++)
          _item('horror-$i', overview: const OverviewModel(genres: ['Horror'])),
        for (var i = 0; i < 10; i++)
          _item('mystery-$i',
              overview: const OverviewModel(genres: ['Mystery'])),
        for (var i = 0; i < 9; i++)
          _item('family-$i', overview: const OverviewModel(genres: ['Family'])),
      ];
      // Fréquences : Drame 40, Comédie 12, Horreur 11, Mystère 10,
      // Familial 9 -> médiane 11, seuil par défaut (x3) = 33. Seul Drame
      // (40) le dépasse — les autres, y compris des genres "moyens"
      // comme Comédie, restent dans le pot.
      final stats = buildLibraryTraitStats(unwatched);

      final pool = genreRowPool(unwatched, stats);

      expect(pool.keys, isNot(contains('Drame')));
      expect(pool.keys,
          containsAll(['Comédie', 'Horreur', 'Mystère', 'Familial']));
    });

    test(
        'merges English and French variants of the same genre before '
        'computing frequency and eligibility', () {
      final unwatched = [
        for (var i = 0; i < 20; i++)
          _item('en-$i', overview: const OverviewModel(genres: ['Drama'])),
        for (var i = 0; i < 20; i++)
          _item('fr-$i', overview: const OverviewModel(genres: ['Drame'])),
      ];
      final stats = buildLibraryTraitStats(unwatched);

      final pool = genreRowPool(unwatched, stats);

      expect(pool.keys, contains('Drame'));
      expect(pool['Drame'], hasLength(40),
          reason: 'les deux variantes doivent fusionner dans la même '
              'rangée, pas rester deux entrées séparées');
    });

    test('a genre below the minimum item count is not in the pool', () {
      final unwatched = [
        for (var i = 0; i < 90; i++)
          _item('drama-$i', overview: const OverviewModel(genres: ['Drama'])),
        _item('noir-1', overview: const OverviewModel(genres: ['Film-Noir'])),
      ];
      final stats = buildLibraryTraitStats(unwatched);

      final pool = genreRowPool(unwatched, stats, minItemsPerRow: 8);

      expect(pool.keys, isNot(contains('Film-Noir')));
    });

    test('empty library yields no pool', () {
      final pool = genreRowPool(const [],
          const LibraryTraitStats(librarySize: 0, traitDocFrequency: {}));

      expect(pool, isEmpty);
    });
  });

  group('decadeRowPool', () {
    test('groups by decade, newest first, dropping rows below the minimum', () {
      final unwatched = [
        for (var i = 0; i < 8; i++)
          _item('2020-$i', overview: OverviewModel(yearAired: 2021 + i % 3)),
        for (var i = 0; i < 3; i++)
          _item('1990-$i', overview: const OverviewModel(yearAired: 1995)),
      ];

      final pool = decadeRowPool(unwatched, minItemsPerRow: 8);

      expect(pool.keys.toList(), [2020]);
    });

    test(
        'reads yearAired, not productionYear — the field actually '
        'populated for a server-loaded item (cf. OverviewModel.fromBaseItemDto)',
        () {
      final unwatched = [
        for (var i = 0; i < 8; i++)
          _item('2020-$i', overview: const OverviewModel(productionYear: 2021)),
      ];

      expect(decadeRowPool(unwatched, minItemsPerRow: 8), isEmpty,
          reason: 'productionYear seul ne doit jamais suffire — c\'est '
              'exactement le bug calibré (pot vide malgré ~1200 films)');
    });

    test('items without a known year are ignored', () {
      final unwatched = [_item('unknown')];

      expect(decadeRowPool(unwatched, minItemsPerRow: 1), isEmpty);
    });
  });

  group('longFilms', () {
    test('keeps only films at or above the runtime threshold', () {
      final items = [
        _item('short',
            overview: const OverviewModel(runTime: Duration(minutes: 90))),
        _item('long',
            overview: const OverviewModel(runTime: Duration(hours: 3))),
      ];

      final result = longFilms(items);

      expect(result.map((e) => e.id), ['long']);
    });

    test('an item with no known runtime is excluded', () {
      final items = [_item('unknown')];

      expect(longFilms(items), isEmpty);
    });
  });
}
