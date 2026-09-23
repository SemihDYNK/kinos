import 'package:flutter_test/flutter_test.dart';

import 'package:kinos/recommendations/engine/seed_clustering.dart';
import 'package:kinos/recommendations/models/candidate_item.dart';
import 'package:kinos/recommendations/models/taste_profile.dart';
import 'package:kinos/recommendations/models/trait.dart';

CandidateItem _candidate(String id, List<TraitKey> traits) => CandidateItem(
      id: id,
      title: id,
      traits: traits,
      source: CandidateSource.jellyfinLibrary,
    );

void main() {
  final bond = trait(TraitKind.keyword, 'james bond');
  final mi6 = trait(TraitKind.keyword, 'mi6');
  final scifi = trait(TraitKind.genre, 'sci-fi');
  final nolan = trait(TraitKind.director, 'christopher nolan');

  group('selectSeedTraits', () {
    test('merges near-duplicate traits sharing almost the same candidates', () {
      // "james bond" et "mi6" partagent exactement les 3 mêmes films —
      // similarité de Jaccard maximale, doivent fusionner en une seule
      // graine.
      final candidates = [
        _candidate('skyfall', [bond, mi6]),
        _candidate('spectre', [bond, mi6]),
        _candidate('casino-royale', [bond, mi6]),
        for (var i = 0; i < 8; i++) _candidate('scifi-$i', [scifi]),
      ];
      final profile = TasteProfile(weights: {
        bond: 5.0,
        mi6: 4.0,
        scifi: 3.0,
      }, catalogSize: 20);

      final seeds =
          selectSeedTraits(profile, candidates, minSharedCandidates: 3);

      expect(seeds, contains(bond));
      expect(seeds, isNot(contains(mi6)),
          reason: 'mi6 doit être absorbé dans le même groupe que bond, '
              'qui a le poids le plus fort');
    });

    test('does not merge a broad genre with a rare, unrelated trait', () {
      final candidates = [
        for (var i = 0; i < 8; i++) _candidate('nolan-$i', [nolan]),
        for (var i = 0; i < 200; i++) _candidate('scifi-$i', [scifi]),
      ];
      final profile = TasteProfile(weights: {
        nolan: 5.0,
        scifi: 3.0,
      }, catalogSize: 220);

      final seeds =
          selectSeedTraits(profile, candidates, minSharedCandidates: 8);

      expect(seeds, containsAll([nolan, scifi]));
    });

    test('drops a representative that does not reach the quality floor', () {
      final candidates = [
        _candidate('a', [nolan]),
        _candidate('b', [nolan]),
      ];
      final profile = TasteProfile(weights: {nolan: 5.0}, catalogSize: 2);

      final seeds =
          selectSeedTraits(profile, candidates, minSharedCandidates: 8);

      expect(seeds, isEmpty);
    });

    test('orders representatives by descending profile weight', () {
      final candidates = [
        for (var i = 0; i < 8; i++) _candidate('nolan-$i', [nolan]),
        for (var i = 0; i < 8; i++) _candidate('scifi-$i', [scifi]),
      ];
      final profile = TasteProfile(weights: {
        scifi: 1.0,
        nolan: 5.0,
      }, catalogSize: 16);

      final seeds =
          selectSeedTraits(profile, candidates, minSharedCandidates: 8);

      expect(seeds, [nolan, scifi]);
    });

    test('never returns more than maxSeeds', () {
      final traits = [
        trait(TraitKind.director, 'a'),
        trait(TraitKind.director, 'b'),
        trait(TraitKind.director, 'c'),
        trait(TraitKind.director, 'd'),
        trait(TraitKind.director, 'e'),
      ];
      final candidates = [
        for (final t in traits)
          for (var i = 0; i < 8; i++) _candidate('${t.value}-$i', [t]),
      ];
      final profile = TasteProfile(
        weights: {for (var i = 0; i < traits.length; i++) traits[i]: 5.0 - i},
        catalogSize: 40,
      );

      final seeds = selectSeedTraits(profile, candidates,
          minSharedCandidates: 8, maxSeeds: 4);

      expect(seeds, hasLength(4));
    });

    test('ignores traits with a non-positive weight', () {
      final negative = trait(TraitKind.genre, 'horror');
      final candidates = [
        for (var i = 0; i < 8; i++) _candidate('h-$i', [negative]),
      ];
      final profile = TasteProfile(weights: {negative: -2.0}, catalogSize: 8);

      final seeds = selectSeedTraits(profile, candidates);

      expect(seeds, isEmpty);
    });

    test('empty profile yields no seeds', () {
      final seeds = selectSeedTraits(
          const TasteProfile(weights: {}, catalogSize: 0), const []);

      expect(seeds, isEmpty);
    });
  });
}
