import 'package:flutter_test/flutter_test.dart';

import 'package:kinos/recommendations/engine/taste_profile_builder.dart';
import 'package:kinos/recommendations/models/accumulation_saturation.dart';
import 'package:kinos/recommendations/models/library_trait_stats.dart';
import 'package:kinos/recommendations/models/trait.dart';
import 'package:kinos/recommendations/models/watch_event.dart';
import 'package:kinos/recommendations/models/watch_signal.dart';

void main() {
  const builder = TasteProfileBuilder();
  final now = DateTime(2025, 1, 1);

  TraitKey sciFi = trait(TraitKind.genre, 'Sci-Fi');
  TraitKey drama = trait(TraitKind.genre, 'Drama');

  group('signal weighting', () {
    test('early abandonment lowers the weight of a shared trait', () {
      // Un profil composé uniquement d'un visionnage terminé et favori
      // sur Sci-Fi...
      final positiveOnly = builder.build([
        WatchEvent(
            itemId: 'a',
            traits: [sciFi],
            signal: WatchSignal.completedFavorite,
            occurredAt: now),
      ], now: now);

      // ...comparé au même historique, plus un abandon précoce sur un
      // AUTRE film qui partage le même trait.
      final withAbandon = builder.build([
        WatchEvent(
            itemId: 'a',
            traits: [sciFi],
            signal: WatchSignal.completedFavorite,
            occurredAt: now),
        WatchEvent(
            itemId: 'b',
            traits: [sciFi],
            signal: WatchSignal.abandonedEarly,
            occurredAt: now),
      ], now: now);

      expect(
          withAbandon.weightOf(sciFi), lessThan(positiveOnly.weightOf(sciFi)));
    });

    test('abandonedLate contributes nothing — treated as neutral, ignored', () {
      final profile = builder.build([
        WatchEvent(
            itemId: 'a',
            traits: [sciFi],
            signal: WatchSignal.abandonedLate,
            occurredAt: now),
      ], now: now);

      expect(profile.weightOf(sciFi), 0.0);
      expect(profile.catalogSize, 0,
          reason:
              'un abandon tardif ne doit même pas compter dans le catalogue '
              'utilisé pour la pondération IDF des autres traits');
    });

    test('rewatched outweighs a single completedFavorite watch', () {
      final rewatchedProfile = builder.build([
        WatchEvent(
            itemId: 'a',
            traits: [sciFi],
            signal: WatchSignal.rewatched,
            occurredAt: now),
      ], now: now);
      final singleWatchProfile = builder.build([
        WatchEvent(
            itemId: 'a',
            traits: [sciFi],
            signal: WatchSignal.completedFavorite,
            occurredAt: now),
      ], now: now);

      expect(rewatchedProfile.weightOf(sciFi),
          greaterThan(singleWatchProfile.weightOf(sciFi)));
    });
  });

  group('time decay', () {
    test('a signal half a decay-period old is worth roughly half as much', () {
      // Saturation désactivée : isole la décroissance temporelle de la
      // non-linéarité de la saturation (sqrt(x/2) != sqrt(x)/2), pour
      // que ce test vérifie une seule chose à la fois.
      const shortBuilder = TasteProfileBuilder(
          halfLife: Duration(days: 100),
          saturation: AccumulationSaturation.none);
      final recent = shortBuilder.build([
        WatchEvent(
            itemId: 'a',
            traits: [sciFi],
            signal: WatchSignal.completedNeutral,
            occurredAt: now),
      ], now: now);
      final halfLifeAgo = shortBuilder.build([
        WatchEvent(
            itemId: 'a',
            traits: [sciFi],
            signal: WatchSignal.completedNeutral,
            occurredAt: now.subtract(const Duration(days: 100))),
      ], now: now);

      expect(halfLifeAgo.weightOf(sciFi),
          closeTo(recent.weightOf(sciFi) / 2, 0.001));
    });

    test('an undated event applies full weight (no decay)', () {
      final dated = builder.build([
        WatchEvent(
            itemId: 'a',
            traits: [sciFi],
            signal: WatchSignal.completedNeutral,
            occurredAt: now),
      ], now: now);
      final undated = builder.build([
        WatchEvent(
            itemId: 'a', traits: [sciFi], signal: WatchSignal.completedNeutral),
      ], now: now);

      expect(undated.weightOf(sciFi), dated.weightOf(sciFi));
    });
  });

  group('IDF-style trait weighting', () {
    // Saturation désactivée et un seul type de trait (genre pour les
    // deux) sur tous les cas de ce groupe : isole l'IDF de la
    // saturation et du coefficient par type, qui ont chacun leur propre
    // groupe de tests plus bas.
    const idfBuilder =
        TasteProfileBuilder(saturation: AccumulationSaturation.none);
    final rareGenre = trait(TraitKind.genre, 'Noir');

    test(
        'a ubiquitous trait contributes far less per occurrence than a rare one',
        () {
      // Drama apparaît dans les 10 œuvres regardées ; le genre rare dans
      // une seule.
      final events = [
        for (var i = 0; i < 10; i++)
          WatchEvent(
            itemId: 'item$i',
            traits: [
              drama,
              if (i == 0) rareGenre,
            ],
            signal: WatchSignal.completedNeutral,
            occurredAt: now,
          ),
      ];
      final profile = idfBuilder.build(events, now: now);

      // Contribution moyenne par occurrence — équivalente au facteur
      // IDF puisque chaque événement porte le même poids de base et le
      // même type de trait (coefficient neutre des deux côtés).
      final dramaPerOccurrence = profile.weightOf(drama) / 10;
      final rareGenrePerOccurrence = profile.weightOf(rareGenre) / 1;

      expect(dramaPerOccurrence, lessThan(rareGenrePerOccurrence));
    });

    test(
        'IDF never flips the sign of a trait, even when it appears in every item',
        () {
      final events = [
        for (var i = 0; i < 5; i++)
          WatchEvent(
              itemId: 'item$i',
              traits: [drama],
              signal: WatchSignal.completedNeutral,
              occurredAt: now),
      ];
      final profile = idfBuilder.build(events, now: now);

      // Poids de base positif -> poids final positif, jamais négatif ou
      // nul malgré un df == base IDF (cf. IDF lissé).
      expect(profile.weightOf(drama), greaterThan(0));
    });

    test('using library-wide stats as the IDF base widens the rare/common gap',
        () {
      // Même historique (10 œuvres, drama partout, un genre rare une
      // fois) que le premier test du groupe, mais l'IDF est calculée
      // sur une bibliothèque de 1000 œuvres où drama est très commun
      // (400) et le genre rare l'est vraiment (2) — cf. spec du
      // calibrage : "la base de comparaison doit être le catalogue, pas
      // l'historique", un historique de 33 œuvres écrase l'écart.
      final events = [
        for (var i = 0; i < 10; i++)
          WatchEvent(
            itemId: 'item$i',
            traits: [drama, if (i == 0) rareGenre],
            signal: WatchSignal.completedNeutral,
            occurredAt: now,
          ),
      ];
      final withLibraryStats = idfBuilder.build(events,
          now: now,
          libraryStats:
              LibraryTraitStats(librarySize: 1000, traitDocFrequency: {
            drama: 400,
            rareGenre: 2,
          }));
      final withHistoryOnly = idfBuilder.build(events, now: now);

      expect(withLibraryStats.idfBaseSize, 1000);
      expect(withHistoryOnly.idfBaseSize, 10);

      final gapWithLibrary = withLibraryStats.weightOf(rareGenre) /
          withLibraryStats.weightOf(drama);
      final gapWithHistoryOnly =
          withHistoryOnly.weightOf(rareGenre) / withHistoryOnly.weightOf(drama);

      expect(gapWithLibrary, greaterThan(gapWithHistoryOnly));
    });
  });

  group('accumulation saturation', () {
    test('none: raw weight grows exactly linearly with occurrence count', () {
      const linearBuilder = TasteProfileBuilder(
          saturation: AccumulationSaturation.none,
          traitKindWeights: {}); // pas de sous-pondération pour isoler la saturation
      final oneEvent = linearBuilder.build([
        WatchEvent(
            itemId: 'a',
            traits: [drama],
            signal: WatchSignal.completedNeutral,
            occurredAt: now),
      ],
          now: now,
          libraryStats:
              const LibraryTraitStats(librarySize: 1, traitDocFrequency: {}));
      final tenEvents = linearBuilder.build([
        for (var i = 0; i < 10; i++)
          WatchEvent(
              itemId: 'item$i',
              traits: [drama],
              signal: WatchSignal.completedNeutral,
              occurredAt: now),
      ],
          now: now,
          libraryStats:
              const LibraryTraitStats(librarySize: 1, traitDocFrequency: {}));

      // Même base IDF fixée (df non renseigné -> 0 des deux côtés) :
      // seule la somme brute change, 10x plus d'événements doit donner
      // exactement 10x le poids sans saturation.
      expect(tenEvents.weightOf(drama),
          closeTo(oneEvent.weightOf(drama) * 10, 0.0001));
    });

    test(
        'sqrt compresses the gap between a frequent and a rare trait less than log',
        () {
      const sqrtBuilder =
          TasteProfileBuilder(saturation: AccumulationSaturation.sqrt);
      const logBuilder =
          TasteProfileBuilder(saturation: AccumulationSaturation.log);
      final rareGenre = trait(TraitKind.genre, 'Noir');

      List<WatchEvent> events() => [
            for (var i = 0; i < 50; i++)
              WatchEvent(
                itemId: 'item$i',
                traits: [drama, if (i == 0) rareGenre],
                signal: WatchSignal.completedNeutral,
                occurredAt: now,
              ),
          ];

      final sqrtProfile = sqrtBuilder.build(events(), now: now);
      final logProfile = logBuilder.build(events(), now: now);

      final sqrtRatio =
          sqrtProfile.weightOf(drama) / sqrtProfile.weightOf(rareGenre);
      final logRatio =
          logProfile.weightOf(drama) / logProfile.weightOf(rareGenre);

      // log(1+x) croît plus lentement que sqrt(x) pour x grand : l'écart
      // entre un trait fréquent (20 occurrences) et un trait rare (1)
      // doit être davantage écrasé sous log que sous sqrt.
      expect(logRatio, lessThan(sqrtRatio));
    });

    test('a negative raw sum stays negative after saturation', () {
      const negBuilder =
          TasteProfileBuilder(saturation: AccumulationSaturation.sqrt);
      final profile = negBuilder.build([
        for (var i = 0; i < 4; i++)
          WatchEvent(
              itemId: 'item$i',
              traits: [drama],
              signal: WatchSignal.abandonedEarly,
              occurredAt: now),
      ], now: now);

      expect(profile.weightOf(drama), lessThan(0));
    });
  });

  group('per-trait-kind coefficients', () {
    test('genres are down-weighted relative to a same-strength director signal',
        () {
      final director = trait(TraitKind.director, 'Auteur');
      // Mêmes signaux, même magnitude — seul le type de trait diffère.
      final profile = builder.build([
        WatchEvent(
            itemId: 'a',
            traits: [drama],
            signal: WatchSignal.completedFavorite,
            occurredAt: now),
        WatchEvent(
            itemId: 'b',
            traits: [director],
            signal: WatchSignal.completedFavorite,
            occurredAt: now),
      ], now: now);

      expect(profile.weightOf(drama), lessThan(profile.weightOf(director)));
    });

    test('a custom coefficient map overrides the defaults', () {
      const flatBuilder = TasteProfileBuilder(
          saturation: AccumulationSaturation.none,
          traitKindWeights: {TraitKind.genre: 1.0, TraitKind.director: 1.0});
      final director = trait(TraitKind.director, 'Auteur');
      final profile = flatBuilder.build([
        WatchEvent(
            itemId: 'a',
            traits: [drama],
            signal: WatchSignal.completedFavorite,
            occurredAt: now),
        WatchEvent(
            itemId: 'b',
            traits: [director],
            signal: WatchSignal.completedFavorite,
            occurredAt: now),
      ], now: now);

      expect(profile.weightOf(drama), profile.weightOf(director));
    });
  });

  test('two distinct users produce distinct profiles from distinct histories',
      () {
    final romance = trait(TraitKind.genre, 'Romance');
    final sciFiFan = builder.build([
      WatchEvent(
          itemId: 'a',
          traits: [sciFi],
          signal: WatchSignal.completedFavorite,
          occurredAt: now),
    ], now: now);
    final romanceFan = builder.build([
      WatchEvent(
          itemId: 'b',
          traits: [romance],
          signal: WatchSignal.completedFavorite,
          occurredAt: now),
    ], now: now);

    expect(sciFiFan.weightOf(sciFi), greaterThan(0));
    expect(sciFiFan.weightOf(romance), 0.0);
    expect(romanceFan.weightOf(romance), greaterThan(0));
    expect(romanceFan.weightOf(sciFi), 0.0);
  });

  group('sourceEventForTrait', () {
    test(
        'picks the event with the highest contribution, same formula as the builder',
        () {
      final events = [
        WatchEvent(
            itemId: 'old-favorite',
            traits: [sciFi],
            signal: WatchSignal.completedFavorite,
            occurredAt: now.subtract(const Duration(days: 400))),
        WatchEvent(
            itemId: 'recent-rewatch',
            traits: [sciFi],
            signal: WatchSignal.rewatched,
            occurredAt: now.subtract(const Duration(days: 1))),
      ];

      final source = sourceEventForTrait(sciFi, events, now: now);

      expect(source?.itemId, 'recent-rewatch',
          reason: 'un revisionnage récent pèse plus qu\'un favori ancien, '
              'une fois la décroissance temporelle appliquée');
    });

    test('ignores events that do not carry the seed trait', () {
      final events = [
        WatchEvent(
            itemId: 'a',
            traits: [drama],
            signal: WatchSignal.completedFavorite,
            occurredAt: now),
      ];

      expect(sourceEventForTrait(sciFi, events, now: now), isNull);
    });

    test('ignores neutral (abandonedLate) events even if they carry the trait',
        () {
      final events = [
        WatchEvent(
            itemId: 'a',
            traits: [sciFi],
            signal: WatchSignal.abandonedLate,
            occurredAt: now),
      ];

      expect(sourceEventForTrait(sciFi, events, now: now), isNull);
    });

    test('returns null for an empty event list', () {
      expect(sourceEventForTrait(sciFi, const [], now: now), isNull);
    });
  });

  group('decayFactor', () {
    test('full weight for an undated event', () {
      expect(decayFactor(null, now), 1.0);
    });

    test('half weight after exactly one half-life', () {
      final factor = decayFactor(now.subtract(const Duration(days: 182)), now,
          halfLife: const Duration(days: 182));

      expect(factor, closeTo(0.5, 0.01));
    });
  });
}
