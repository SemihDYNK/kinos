import 'package:flutter_test/flutter_test.dart';

import 'package:kinos/jellyfin/jellyfin_open_api.enums.swagger.dart';
import 'package:kinos/models/item_base_model.dart';
import 'package:kinos/models/items/item_shared_models.dart';
import 'package:kinos/models/items/overview_model.dart';
import 'package:kinos/recommendations/adapters/jellyfin_trait_extraction.dart';
import 'package:kinos/recommendations/models/trait.dart';

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
  test('extracts genres, studios, tags-as-keywords and decade', () {
    final overview = OverviewModel(
      genres: const ['Sci-Fi', 'Adventure'],
      studios: [Studio(id: 's1', name: 'Legendary')],
      tags: const ['space opera'],
      yearAired: 2021,
    );

    final traits = traitsFromOverview(overview);

    expect(traits, contains(trait(TraitKind.genre, 'Sci-Fi')));
    expect(traits, contains(trait(TraitKind.genre, 'Adventure')));
    expect(traits, contains(trait(TraitKind.studio, 'Legendary')));
    expect(traits, contains(trait(TraitKind.keyword, 'space opera')));
    expect(traits, contains(trait(TraitKind.decade, '2020')));
  });

  test(
      'reads yearAired, not productionYear — the field actually populated '
      'for a server-loaded item (cf. OverviewModel.fromBaseItemDto)', () {
    const overview = OverviewModel(productionYear: 2021);

    final traits = traitsFromOverview(overview);

    expect(traits.where((t) => t.kind == TraitKind.decade), isEmpty,
        reason: 'productionYear seul ne doit jamais suffire à produire '
            'une décennie — c\'est exactement le bug calibré (trait '
            '"décennie" jamais déclenché depuis l\'origine du lot)');
  });

  test('takes at most 4 actors, in list order', () {
    final overview = OverviewModel(
      people: [
        for (var i = 0; i < 6; i++)
          Person(id: 'a$i', name: 'Actor $i', type: PersonKind.actor),
      ],
    );

    final traits = traitsFromOverview(overview)
        .where((t) => t.kind == TraitKind.actor)
        .toList();

    expect(traits.length, 4);
    expect(traits, contains(trait(TraitKind.actor, 'Actor 0')));
    expect(traits, contains(trait(TraitKind.actor, 'Actor 3')));
    expect(traits, isNot(contains(trait(TraitKind.actor, 'Actor 4'))));
  });

  test('separates directors from actors and other crew', () {
    final overview = OverviewModel(
      people: [
        Person(id: 'd1', name: 'Denis Villeneuve', type: PersonKind.director),
        Person(id: 'a1', name: 'Timothée Chalamet', type: PersonKind.actor),
        Person(id: 'w1', name: 'A Writer', type: PersonKind.writer),
      ],
    );

    final traits = traitsFromOverview(overview);

    expect(traits, contains(trait(TraitKind.director, 'Denis Villeneuve')));
    expect(traits, contains(trait(TraitKind.actor, 'Timothée Chalamet')));
    expect(traits, isNot(contains(trait(TraitKind.actor, 'A Writer'))));
    expect(traits, isNot(contains(trait(TraitKind.director, 'A Writer'))));
  });

  test('an overview with no production year contributes no decade trait', () {
    final traits = traitsFromOverview(const OverviewModel(genres: ['Drama']));

    expect(traits.any((t) => t.kind == TraitKind.decade), isFalse);
  });

  group('buildLibraryTraitStats', () {
    test('counts library size and document frequency per trait', () {
      final stats = buildLibraryTraitStats([
        _item('1', overview: const OverviewModel(genres: ['Drama'])),
        _item('2', overview: const OverviewModel(genres: ['Drama', 'Comedy'])),
        _item('3', overview: const OverviewModel(genres: ['Comedy'])),
      ]);

      expect(stats.librarySize, 3);
      expect(stats.traitDocFrequency[trait(TraitKind.genre, 'Drama')], 2);
      expect(stats.traitDocFrequency[trait(TraitKind.genre, 'Comedy')], 2);
    });

    test('counts a trait at most once per item, even if it repeats', () {
      // Deux mots-clés identiques sur la même œuvre (payload serveur
      // inhabituel mais pas invalide) : ne doit compter que pour un seul
      // document, même précaution que TasteProfileBuilder côté
      // historique.
      final stats = buildLibraryTraitStats([
        _item('1', overview: const OverviewModel(tags: ['heist', 'heist'])),
      ]);

      expect(stats.traitDocFrequency[trait(TraitKind.keyword, 'heist')], 1);
    });

    test('an empty library produces empty, not null, stats', () {
      final stats = buildLibraryTraitStats(const []);

      expect(stats.librarySize, 0);
      expect(stats.traitDocFrequency, isEmpty);
    });

    test(
        'reunites played and unwatched items — the replacement for the '
        'removed network round-trip, cf. le calibrage de performance', () {
      final played = [
        _item('played1', overview: const OverviewModel(genres: ['Drama']))
      ];
      final unwatched = [
        _item('unwatched1', overview: const OverviewModel(genres: ['Comedy']))
      ];

      final stats = buildLibraryTraitStats([...played, ...unwatched]);

      expect(stats.librarySize, 2);
      expect(stats.traitDocFrequency[trait(TraitKind.genre, 'Drama')], 1);
      expect(stats.traitDocFrequency[trait(TraitKind.genre, 'Comedy')], 1);
    });
  });
}
