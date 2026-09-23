import 'package:flutter_test/flutter_test.dart';

import 'package:kinos/recommendations/engine/arr_added_date_ranking.dart';
import 'package:kinos/recommendations/engine/recommendation_scorer.dart';
import 'package:kinos/recommendations/models/candidate_item.dart';
import 'package:kinos/recommendations/models/taste_profile.dart';
import 'package:kinos/recommendations/models/trait.dart';

void main() {
  const scorer = RecommendationScorer();
  final genre = trait(TraitKind.genre, 'Action');
  final profile = TasteProfile(weights: {genre: 3.0}, catalogSize: 1);
  final now = DateTime(2025, 6, 1);

  CandidateItem candidate(String id, {DateTime? added, List<TraitKey>? traits}) =>
      CandidateItem(
        id: id,
        title: id,
        traits: traits ?? [genre],
        source: CandidateSource.arrOnly,
        added: added,
      );

  DateTime daysAgo(int days) => now.subtract(Duration(days: days));

  test('candidates added more recently than minAge are excluded — would'
      ' duplicate "Ajouts récents"', () {
    final results = rankArrCandidatesByAddedDate(
      profile,
      [
        candidate('tooRecent', added: daysAgo(10)),
        candidate('justOldEnough', added: daysAgo(30)),
      ],
      scorer: scorer,
      now: now,
    );

    expect(results.map((r) => r.item.id).toList(), ['justOldEnough']);
  });

  test('candidates with no known added date are excluded — the threshold'
      ' cannot be verified', () {
    final results = rankArrCandidatesByAddedDate(
      profile,
      [
        candidate('noDate', added: null),
        candidate('dated', added: daysAgo(45)),
      ],
      scorer: scorer,
      now: now,
    );

    expect(results.map((r) => r.item.id).toList(), ['dated']);
  });

  test('candidates with no traits at all are skipped', () {
    final results = rankArrCandidatesByAddedDate(
      profile,
      [
        candidate('empty', added: daysAgo(45), traits: const []),
        candidate('withTraits', added: daysAgo(45)),
      ],
      scorer: scorer,
      now: now,
    );

    expect(results.map((r) => r.item.id).toList(), ['withTraits']);
  });

  group('recent block (entre minAge et stableOrderAge)', () {
    test('sorted by added date, most recent first', () {
      final results = rankArrCandidatesByAddedDate(
        profile,
        [
          candidate('older', added: daysAgo(55)),
          candidate('newest', added: daysAgo(31)),
          candidate('middle', added: daysAgo(40)),
        ],
        scorer: scorer,
        now: now,
      );

      expect(results.map((r) => r.item.id).toList(),
          ['newest', 'middle', 'older']);
    });

    test('date is the primary key even when it contradicts the affinity score',
        () {
      final weak = trait(TraitKind.genre, 'Unrelated');
      final results = rankArrCandidatesByAddedDate(
        TasteProfile(weights: {genre: 100.0, weak: 0.01}, catalogSize: 1),
        [
          candidate('addedEarlierButLoved', added: daysAgo(58), traits: [genre]),
          candidate('addedRecentlyButIrrelevant',
              added: daysAgo(32), traits: [weak]),
        ],
        scorer: scorer,
        now: now,
      );

      expect(results.first.item.id, 'addedRecentlyButIrrelevant',
          reason: 'la date prime sur l\'affinité, sauf à date proche');
    });

    test('candidates added on the same day are tie-broken by score, descending',
        () {
      final strong = trait(TraitKind.genre, 'Strong');
      final weak = trait(TraitKind.genre, 'Weak');
      final sameDayProfile =
          TasteProfile(weights: {strong: 10.0, weak: 1.0}, catalogSize: 1);
      final sameDay = daysAgo(40).add(const Duration(hours: 1));
      final sameDayLater = daysAgo(40).add(const Duration(hours: 15));

      final results = rankArrCandidatesByAddedDate(sameDayProfile, [
        candidate('weakerAffinity', added: sameDay, traits: [weak]),
        candidate('strongerAffinity', added: sameDayLater, traits: [strong]),
      ], scorer: scorer, now: now);

      expect(results.map((r) => r.item.id).toList(),
          ['strongerAffinity', 'weakerAffinity'],
          reason: 'même jour calendaire -> le score décide, pas l\'heure exacte');
    });
  });

  group('stable block (au-delà de stableOrderAge)', () {
    test('placed after the recent block regardless of its own dates', () {
      final results = rankArrCandidatesByAddedDate(
        profile,
        [
          candidate('veryOld', added: daysAgo(400)),
          candidate('recent', added: daysAgo(31)),
        ],
        scorer: scorer,
        now: now,
        seed: 1,
      );

      expect(results.map((r) => r.item.id).toList(), ['recent', 'veryOld']);
    });

    test('the same seed produces the same order for the stable block', () {
      final candidates = [
        for (var i = 0; i < 6; i++) candidate('old$i', added: daysAgo(200 + i)),
      ];

      final first = rankArrCandidatesByAddedDate(profile, candidates,
          scorer: scorer, now: now, seed: 42);
      final second = rankArrCandidatesByAddedDate(profile, candidates,
          scorer: scorer, now: now, seed: 42);

      expect(first.map((r) => r.item.id).toList(),
          second.map((r) => r.item.id).toList());
    });
  });

  test('the two thresholds are configurable', () {
    // Avec des seuils resserrés (15 jours / 20 jours), un candidat
    // "moyen" (17 jours) tombe dans le bloc récent au lieu d'être exclu
    // par les seuils par défaut (30/60 jours).
    final results = rankArrCandidatesByAddedDate(
      profile,
      [candidate('midAge', added: daysAgo(17))],
      scorer: scorer,
      now: now,
      minAge: const Duration(days: 15),
      stableOrderAge: const Duration(days: 20),
    );

    expect(results.map((r) => r.item.id).toList(), ['midAge']);
  });

  test('no diversity constraint applied — franchise duplicates are all kept',
      () {
    final results = rankArrCandidatesByAddedDate(
      profile,
      [
        for (var i = 0; i < 5; i++)
          CandidateItem(
            id: 'film$i',
            title: 'film$i',
            traits: [genre],
            source: CandidateSource.arrOnly,
            added: daysAgo(35 + i),
            franchiseKeys: const ['title:same franchise'],
          ),
      ],
      scorer: scorer,
      now: now,
    );

    expect(results, hasLength(5),
        reason: 'un inventaire honnête ne cache pas des suites bien présentes');
  });

  test('still computes a justification per candidate, reusing the scorer\'s rules',
      () {
    final director = trait(TraitKind.director, 'Auteur');
    final richProfile = TasteProfile(weights: {director: 5.0}, catalogSize: 1);
    final results = rankArrCandidatesByAddedDate(
      richProfile,
      [candidate('x', added: daysAgo(45), traits: [director])],
      scorer: scorer,
      now: now,
    );

    expect(results.single.justification, director);
  });
}
