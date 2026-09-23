import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:kinos/recommendations/engine/recommendation_scorer.dart';
import 'package:kinos/recommendations/engine/taste_profile_builder.dart';
import 'package:kinos/recommendations/models/candidate_item.dart';
import 'package:kinos/recommendations/models/library_trait_stats.dart';
import 'package:kinos/recommendations/models/taste_profile.dart';
import 'package:kinos/recommendations/models/trait.dart';
import 'package:kinos/recommendations/models/watch_event.dart';
import 'package:kinos/recommendations/models/watch_signal.dart';

void main() {
  const scorer = RecommendationScorer();
  final sciFi = trait(TraitKind.genre, 'Sci-Fi');
  final romance = trait(TraitKind.genre, 'Romance');

  CandidateItem candidate(
    String id,
    List<TraitKey> traits, {
    CandidateSource source = CandidateSource.jellyfinLibrary,
    List<String> franchiseKeys = const [],
  }) =>
      CandidateItem(
        id: id,
        title: id,
        traits: traits,
        source: source,
        franchiseKeys: franchiseKeys,
      );

  group('normalization', () {
    test(
        'an over-documented candidate does not win on raw dot product alone',
        () {
      final profile = TasteProfile(weights: {sciFi: 10.0}, catalogSize: 1);

      // Candidat A : un seul trait pertinent (Sci-Fi).
      final a = candidate('a', [sciFi]);
      // Candidat B : le même trait pertinent, noyé dans 5 autres traits
      // absents du profil (poids 0 chacun) — même produit scalaire brut
      // que A (10.0 + 0*5 = 10.0), mais bien plus "documenté".
      final unrelated = [
        trait(TraitKind.actor, 'x1'),
        trait(TraitKind.actor, 'x2'),
        trait(TraitKind.actor, 'x3'),
        trait(TraitKind.studio, 'x4'),
        trait(TraitKind.keyword, 'x5'),
      ];
      final b = candidate('b', [sciFi, ...unrelated]);

      final results = {
        for (final r in scorer.score(profile, [a, b])) r.item.id: r.score
      };

      // Sans normalisation, les deux scores bruts seraient identiques
      // (10.0) : la correction doit strictement les départager en
      // faveur du candidat le moins documenté.
      expect(results['a'], greaterThan(results['b']!));
    });
  });

  group('diversity constraint', () {
    test('caps entries sharing the same dominant trait at maxPerDominantTrait',
        () {
      final director = trait(TraitKind.director, 'Auteur X');
      final profile = TasteProfile(weights: {director: 5.0}, catalogSize: 1);

      final candidates = [
        for (var i = 0; i < 8; i++) candidate('film$i', [director]),
      ];

      final results = scorer.score(profile, candidates);

      expect(results.length, 2,
          reason:
              'un score brut sortirait les 8 films du même réalisateur (cf. spec)');
    });

    test('a higher maxPerDominantTrait allows more entries through', () {
      const looseScorer = RecommendationScorer(maxPerDominantTrait: 4);
      final director = trait(TraitKind.director, 'Auteur X');
      final profile = TasteProfile(weights: {director: 5.0}, catalogSize: 1);
      final candidates = [
        for (var i = 0; i < 8; i++) candidate('film$i', [director]),
      ];

      expect(looseScorer.score(profile, candidates).length, 4);
    });

    test('diversity is applied after sorting, keeping the highest scorers',
        () {
      final director = trait(TraitKind.director, 'Auteur X');
      final genre = trait(TraitKind.genre, 'Thriller');
      // Un trait secondaire distinct par film — départage les scores
      // sans changer le trait dominant (director reste le plus fort en
      // valeur absolue pour les trois), pour que le classement avant
      // diversité soit déterministe plutôt que dépendant de l'ordre de
      // tri en cas d'égalité stricte.
      final secondaryBest = trait(TraitKind.keyword, 'a');
      final secondarySecond = trait(TraitKind.keyword, 'b');
      final secondaryThird = trait(TraitKind.keyword, 'c');
      final profile = TasteProfile(weights: {
        director: 5.0,
        genre: 1.0,
        secondaryBest: 1.0,
        secondarySecond: 0.5,
        secondaryThird: 0.1,
      }, catalogSize: 1);

      // Trois films du même réalisateur (dominant), un thriller isolé
      // avec un score plus faible.
      final results = scorer.score(profile, [
        candidate('best', [director, secondaryBest]),
        candidate('second', [director, secondarySecond]),
        candidate('third', [director, secondaryThird]), // doit être filtré
        candidate('other', [genre]),
      ]);

      expect(results.map((r) => r.item.id).toList(),
          ['best', 'second', 'other']);
    });
  });

  group('franchise deduplication', () {
    test(
        'caps entries sharing a franchise key at maxPerFranchise, even when their dominant traits differ',
        () {
      // Motivé par le calibrage : deux James Bond en tête du rapport,
      // "≤2 par trait dominant" ne les attrapait pas parce que leurs
      // traits dominants respectifs diffèrent (l'un justifié par son
      // réalisateur, l'autre par un acteur) — seule la clé de franchise
      // partagée (le mot-clé "james bond") les relie.
      final director1 = trait(TraitKind.director, 'Sam Mendes');
      final director2 = trait(TraitKind.director, 'Cary Fukunaga');
      final actor = trait(TraitKind.actor, 'Daniel Craig');
      final profile = TasteProfile(weights: {
        director1: 5.0,
        director2: 4.9,
        actor: 4.8,
      }, catalogSize: 1);

      final bondFilms = [
        candidate('skyfall', [director1],
            franchiseKeys: const ['keyword:james bond']),
        candidate('spectre', [director2],
            franchiseKeys: const ['keyword:james bond']),
        candidate('no-time-to-die', [actor],
            franchiseKeys: const ['keyword:james bond']),
      ];

      final results = scorer.score(profile, bondFilms);

      expect(results.length, 2,
          reason:
              'la diversité par trait dominant seule laisserait passer les 3 '
              '(traits dominants tous différents)');
    });

    test('a higher maxPerFranchise allows more entries through', () {
      const looseScorer = RecommendationScorer(maxPerFranchise: 3);
      final director1 = trait(TraitKind.director, 'Sam Mendes');
      final director2 = trait(TraitKind.director, 'Cary Fukunaga');
      final actor = trait(TraitKind.actor, 'Daniel Craig');
      final profile = TasteProfile(weights: {
        director1: 5.0,
        director2: 4.9,
        actor: 4.8,
      }, catalogSize: 1);

      final bondFilms = [
        candidate('skyfall', [director1],
            franchiseKeys: const ['keyword:james bond']),
        candidate('spectre', [director2],
            franchiseKeys: const ['keyword:james bond']),
        candidate('no-time-to-die', [actor],
            franchiseKeys: const ['keyword:james bond']),
      ];

      expect(looseScorer.score(profile, bondFilms).length, 3);
    });

    test('candidates from different franchises are unaffected by each other',
        () {
      final bondKeyword = trait(TraitKind.keyword, 'james bond');
      final batmanKeyword = trait(TraitKind.keyword, 'batman');
      final profile = TasteProfile(
          weights: {bondKeyword: 5.0, batmanKeyword: 5.0}, catalogSize: 1);

      final results = scorer.score(profile, [
        candidate('bond1', [bondKeyword], franchiseKeys: const ['keyword:james bond']),
        candidate('bond2', [bondKeyword], franchiseKeys: const ['keyword:james bond']),
        candidate('batman1', [batmanKeyword], franchiseKeys: const ['keyword:batman']),
        candidate('batman2', [batmanKeyword], franchiseKeys: const ['keyword:batman']),
      ]);

      expect(results.map((r) => r.item.id).toSet(),
          {'bond1', 'bond2', 'batman1', 'batman2'});
    });

    test(
        'title-based franchise keys catch sequels even with distinct dominant traits',
        () {
      // "Moi, moche et méchant 1/2/3" — chaque volet a son propre acteur
      // dominant (distinct, donc la diversité par trait dominant seule
      // laisserait passer les 3) ; seule la clé de franchise par titre
      // (cf. `normalizeFranchiseTitle`) les relie.
      final actor1 = trait(TraitKind.actor, 'Steve Carell 1');
      final actor2 = trait(TraitKind.actor, 'Steve Carell 2');
      final actor3 = trait(TraitKind.actor, 'Steve Carell 3');
      final profile = TasteProfile(
          weights: {actor1: 5.0, actor2: 4.9, actor3: 4.8}, catalogSize: 1);

      final results = scorer.score(profile, [
        candidate('dm1', [actor1],
            franchiseKeys: const ['title:moi, moche et méchant']),
        candidate('dm2', [actor2],
            franchiseKeys: const ['title:moi, moche et méchant']),
        candidate('dm3', [actor3],
            franchiseKeys: const ['title:moi, moche et méchant']),
      ]);

      expect(results.length, 2);
    });
  });

  group('justification specificity', () {
    test(
        'at comparable contribution, a keyword is preferred over a genre as justification',
        () {
      final genre = trait(TraitKind.genre, 'Action');
      final keyword = trait(TraitKind.keyword, 'james bond');
      // À moins de 25% d'écart (tolérance par défaut) : le mot-clé,
      // plus spécifique, doit l'emporter malgré un poids légèrement
      // inférieur au genre.
      final profile =
          TasteProfile(weights: {genre: 5.0, keyword: 4.5}, catalogSize: 1);

      final results = scorer.score(profile, [candidate('x', [genre, keyword])]);

      expect(results.single.justification, keyword);
    });

    test('a director is preferred over a keyword at comparable contribution',
        () {
      final director = trait(TraitKind.director, 'Denis Villeneuve');
      final keyword = trait(TraitKind.keyword, 'space opera');
      final profile = TasteProfile(
          weights: {director: 5.0, keyword: 4.9}, catalogSize: 1);

      final results =
          scorer.score(profile, [candidate('x', [director, keyword])]);

      expect(results.single.justification, director);
    });

    test('genre is used as a last resort when nothing comparable is more specific',
        () {
      final genre = trait(TraitKind.genre, 'Action');
      final keyword = trait(TraitKind.keyword, 'minor');
      // Écart largement au-delà de la tolérance par défaut (25%) : le
      // mot-clé n'est pas "à contribution comparable", le genre reste
      // la seule justification défendable.
      final profile =
          TasteProfile(weights: {genre: 5.0, keyword: 0.1}, catalogSize: 1);

      final results = scorer.score(profile, [candidate('x', [genre, keyword])]);

      expect(results.single.justification, genre);
    });

    test('comparableTolerance is configurable', () {
      final genre = trait(TraitKind.genre, 'Action');
      final keyword = trait(TraitKind.keyword, 'james bond');
      final profile =
          TasteProfile(weights: {genre: 5.0, keyword: 4.0}, catalogSize: 1);

      // 4.0 est à 20% de 5.0 — comparable avec une tolérance large,
      // pas avec une tolérance étroite.
      const strictScorer = RecommendationScorer(comparableTolerance: 0.05);
      const looseScorer = RecommendationScorer(comparableTolerance: 0.3);

      expect(strictScorer.score(profile, [candidate('x', [genre, keyword])]).single.justification,
          genre);
      expect(looseScorer.score(profile, [candidate('x', [genre, keyword])]).single.justification,
          keyword);
    });
  });

  group('keyword rarity filter for justification', () {
    test(
        'a keyword too rare in the library is never chosen as justification, even with the highest weight',
        () {
      final genre = trait(TraitKind.genre, 'Comedy');
      final rareKeyword = trait(TraitKind.keyword, 'chipmunk');
      // Le mot-clé a le poids le plus fort (IDF élevé, rare dans
      // l'historique) mais n'apparaît que dans 1 œuvre de toute la
      // bibliothèque — sous le seuil par défaut (4).
      final profile = TasteProfile(
          weights: {genre: 1.0, rareKeyword: 8.0}, catalogSize: 1);
      final libraryStats = LibraryTraitStats(
          librarySize: 500, traitDocFrequency: {rareKeyword: 1});
      final scorerWithStats = RecommendationScorer(libraryStats: libraryStats);

      final results = scorerWithStats
          .score(profile, [candidate('x', [genre, rareKeyword])]);

      expect(results.single.justification, genre,
          reason: 'le score, lui, doit rester inchangé par ce filtre');
      expect(results.single.score, closeTo((1.0 + 8.0) / sqrt(2), 0.0001));
    });

    test('a keyword that meets the threshold remains eligible as justification',
        () {
      final genre = trait(TraitKind.genre, 'Comedy');
      final commonKeyword = trait(TraitKind.keyword, 'heist');
      final profile = TasteProfile(
          weights: {genre: 1.0, commonKeyword: 8.0}, catalogSize: 1);
      final libraryStats = LibraryTraitStats(
          librarySize: 500, traitDocFrequency: {commonKeyword: 10});
      final scorerWithStats = RecommendationScorer(libraryStats: libraryStats);

      final results = scorerWithStats
          .score(profile, [candidate('x', [genre, commonKeyword])]);

      expect(results.single.justification, commonKeyword);
    });

    test('a custom minKeywordDocFrequencyForJustification threshold is honored',
        () {
      final keyword = trait(TraitKind.keyword, 'heist');
      final genre = trait(TraitKind.genre, 'Comedy');
      final profile =
          TasteProfile(weights: {genre: 1.0, keyword: 8.0}, catalogSize: 1);
      final libraryStats = LibraryTraitStats(
          librarySize: 500, traitDocFrequency: {keyword: 5});

      final strict = RecommendationScorer(
          libraryStats: libraryStats,
          minKeywordDocFrequencyForJustification: 10);
      final loose = RecommendationScorer(
          libraryStats: libraryStats,
          minKeywordDocFrequencyForJustification: 2);

      expect(
          strict.score(profile, [candidate('x', [genre, keyword])]).single.justification,
          genre);
      expect(
          loose.score(profile, [candidate('x', [genre, keyword])]).single.justification,
          keyword);
    });

    test('with no libraryStats, no keyword is filtered (backward compatible)',
        () {
      final rareKeyword = trait(TraitKind.keyword, 'chipmunk');
      final genre = trait(TraitKind.genre, 'Comedy');
      final profile = TasteProfile(
          weights: {genre: 1.0, rareKeyword: 8.0}, catalogSize: 1);

      final results = scorer.score(profile, [candidate('x', [genre, rareKeyword])]);

      expect(results.single.justification, rareKeyword);
    });

    test(
        'no justification at all when the only trait is an excluded keyword — '
        'never invents a misleading reason (revised per calibrage: "n\'invente '
        'pas de justification")', () {
      final rareKeyword = trait(TraitKind.keyword, 'chipmunk');
      final profile =
          TasteProfile(weights: {rareKeyword: 8.0}, catalogSize: 1);
      final libraryStats = LibraryTraitStats(
          librarySize: 500, traitDocFrequency: {rareKeyword: 1});
      final scorerWithStats = RecommendationScorer(libraryStats: libraryStats);

      final results =
          scorerWithStats.score(profile, [candidate('x', [rareKeyword])]);

      expect(results.single.justification, isNull);
      expect(results.single.score, closeTo(8.0, 0.0001),
          reason: 'le score reste calculé normalement, seule la raison '
              'affichée disparaît');
    });

    test('a keyword on the default stoplist is never chosen, regardless of weight',
        () {
      final genre = trait(TraitKind.genre, 'Comedy');
      final noise = trait(TraitKind.keyword, 'excited');
      final profile =
          TasteProfile(weights: {genre: 1.0, noise: 9.0}, catalogSize: 1);
      // df élevé : ne serait pas filtré par le seuil de rareté seul —
      // c'est la liste nommée qui doit l'écarter.
      final libraryStats = LibraryTraitStats(
          librarySize: 500, traitDocFrequency: {noise: 50});
      final scorerWithStats = RecommendationScorer(libraryStats: libraryStats);

      final results =
          scorerWithStats.score(profile, [candidate('x', [genre, noise])]);

      expect(results.single.justification, genre);
    });
  });

  group('studio filter for justification', () {
    test('a generic studio from the default list is never chosen', () {
      final genre = trait(TraitKind.genre, 'Drama');
      final genericStudio = trait(TraitKind.studio, 'Netflix');
      final profile = TasteProfile(
          weights: {genre: 1.0, genericStudio: 9.0}, catalogSize: 1);

      final results =
          scorer.score(profile, [candidate('x', [genre, genericStudio])]);

      expect(results.single.justification, genre);
    });

    test('a studio present in too large a fraction of the library is excluded',
        () {
      final genre = trait(TraitKind.genre, 'Drama');
      final commonStudio = trait(TraitKind.studio, 'Big Distributor');
      final profile = TasteProfile(
          weights: {genre: 1.0, commonStudio: 9.0}, catalogSize: 1);
      // 60 œuvres sur 1000 (6%) — au-delà du plafond par défaut (5%).
      final libraryStats = LibraryTraitStats(
          librarySize: 1000, traitDocFrequency: {commonStudio: 60});
      final scorerWithStats = RecommendationScorer(libraryStats: libraryStats);

      final results = scorerWithStats
          .score(profile, [candidate('x', [genre, commonStudio])]);

      expect(results.single.justification, genre);
    });

    test('a niche studio well under the fraction threshold remains eligible',
        () {
      final genre = trait(TraitKind.genre, 'Drama');
      final nicheStudio = trait(TraitKind.studio, 'A24');
      final profile = TasteProfile(
          weights: {genre: 1.0, nicheStudio: 9.0}, catalogSize: 1);
      // 5 œuvres sur 1000 (0.5%) — bien sous le plafond par défaut (5%).
      final libraryStats = LibraryTraitStats(
          librarySize: 1000, traitDocFrequency: {nicheStudio: 5});
      final scorerWithStats = RecommendationScorer(libraryStats: libraryStats);

      final results = scorerWithStats
          .score(profile, [candidate('x', [genre, nicheStudio])]);

      expect(results.single.justification, nicheStudio);
    });

    test('a custom maxStudioDocFrequencyFraction is honored', () {
      final genre = trait(TraitKind.genre, 'Drama');
      final studio = trait(TraitKind.studio, 'Mid-Size Studio');
      final profile =
          TasteProfile(weights: {genre: 1.0, studio: 9.0}, catalogSize: 1);
      // 20 œuvres sur 1000 (2%).
      final libraryStats = LibraryTraitStats(
          librarySize: 1000, traitDocFrequency: {studio: 20});

      final strict = RecommendationScorer(
          libraryStats: libraryStats, maxStudioDocFrequencyFraction: 0.01);
      final loose = RecommendationScorer(
          libraryStats: libraryStats, maxStudioDocFrequencyFraction: 0.1);

      expect(strict.score(profile, [candidate('x', [genre, studio])]).single.justification,
          genre);
      expect(loose.score(profile, [candidate('x', [genre, studio])]).single.justification,
          studio);
    });

    test('no justification at all when the only trait is a generic studio', () {
      final genericStudio = trait(TraitKind.studio, 'Netflix');
      final profile =
          TasteProfile(weights: {genericStudio: 9.0}, catalogSize: 1);

      final results =
          scorer.score(profile, [candidate('x', [genericStudio])]);

      expect(results.single.justification, isNull);
    });
  });

  group('exclusion', () {
    test('excludedIds are filtered out before scoring/diversity', () {
      final profile = TasteProfile(weights: {sciFi: 5.0}, catalogSize: 1);
      final results = scorer.score(
        profile,
        [candidate('watched', [sciFi]), candidate('new', [sciFi])],
        excludedIds: {'watched'},
      );

      expect(results.map((r) => r.item.id), ['new']);
    });
  });

  group('justification', () {
    test('the dominant trait is the one with the largest absolute weight',
        () {
      final profile =
          TasteProfile(weights: {sciFi: 1.0, romance: 5.0}, catalogSize: 1);
      final results = scorer.score(profile, [candidate('x', [sciFi, romance])]);

      expect(results.single.justification, romance);
    });

    test('a strongly negative trait can be the dominant justification', () {
      final director = trait(TraitKind.director, 'Disliked');
      final profile =
          TasteProfile(weights: {sciFi: 1.0, director: -5.0}, catalogSize: 1);
      final results =
          scorer.score(profile, [candidate('x', [sciFi, director])]);

      expect(results.single.justification, director);
    });

    test('candidates with no traits at all are skipped, not scored at zero',
        () {
      final profile = TasteProfile(weights: {sciFi: 5.0}, catalogSize: 1);
      final results = scorer.score(profile, [candidate('empty', const [])]);

      expect(results, isEmpty);
    });
  });

  group('seeded tie-breaking', () {
    test('the same seed produces the same order for tied scores', () {
      final profile = TasteProfile(weights: {sciFi: 1.0}, catalogSize: 1);
      final candidates = [
        for (var i = 0; i < 6; i++) candidate('c$i', [sciFi]),
      ];

      final first = scorer.score(profile, candidates, seed: 42);
      final second = scorer.score(profile, candidates, seed: 42);

      expect(first.map((c) => c.item.id).toList(),
          second.map((c) => c.item.id).toList());
    });
  });

  test('two profiles built from distinct histories rank the same catalog differently',
      () {
    const builder = TasteProfileBuilder();
    final now = DateTime(2025, 1, 1);

    final sciFiFan = builder.build([
      WatchEvent(
          itemId: 'w1',
          traits: [sciFi],
          signal: WatchSignal.completedFavorite,
          occurredAt: now),
    ], now: now);
    final romanceFan = builder.build([
      WatchEvent(
          itemId: 'w2',
          traits: [romance],
          signal: WatchSignal.completedFavorite,
          occurredAt: now),
    ], now: now);

    final catalog = [
      candidate('sci-fi-movie', [sciFi]),
      candidate('romance-movie', [romance]),
    ];

    final forSciFiFan = scorer.score(sciFiFan, catalog);
    final forRomanceFan = scorer.score(romanceFan, catalog);

    expect(forSciFiFan.first.item.id, 'sci-fi-movie');
    expect(forRomanceFan.first.item.id, 'romance-movie');
  });
}
