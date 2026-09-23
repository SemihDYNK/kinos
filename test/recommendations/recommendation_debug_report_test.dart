import 'package:flutter_test/flutter_test.dart';

import 'package:kinos/recommendations/debug/recommendation_debug_report.dart';
import 'package:kinos/recommendations/models/candidate_item.dart';
import 'package:kinos/recommendations/models/scored_candidate.dart';
import 'package:kinos/recommendations/models/taste_profile.dart';
import 'package:kinos/recommendations/models/trait.dart';
import 'package:kinos/recommendations/models/watch_classification.dart';
import 'package:kinos/recommendations/models/watch_signal_sample.dart';

void main() {
  test('report includes history size, idf base size, top traits and candidate lines',
      () {
    final sciFi = trait(TraitKind.genre, 'Sci-Fi');
    final director = trait(TraitKind.director, 'Disliked');
    final profile = TasteProfile(
      weights: {sciFi: 4.2, director: -1.1},
      catalogSize: 7,
      idfBaseSize: 1200,
    );
    final candidates = [
      ScoredCandidate(
        item: CandidateItem(
          id: '1',
          title: 'Dune',
          traits: [sciFi],
          source: CandidateSource.jellyfinLibrary,
        ),
        score: 2.5,
        justification: sciFi,
      ),
      ScoredCandidate(
        item: CandidateItem(
          id: '2',
          title: 'Not Yet Downloaded',
          traits: [sciFi],
          source: CandidateSource.arrOnly,
        ),
        score: 1.1,
        justification: sciFi,
      ),
    ];

    final report =
        buildRecommendationDebugReport(profile: profile, candidates: candidates);

    expect(report, contains('Historique (œuvres ayant produit un signal) : 7'));
    expect(report, contains('Base IDF'));
    expect(report, contains('1200'));
    // Les valeurs de trait sont normalisées en minuscules par trait()
    // (cf. lib/recommendations/models/trait.dart) — le rapport les
    // affiche telles quelles, pas de re-capitalisation inventée ici.
    expect(report, contains('sci-fi'));
    expect(report, contains('disliked'));
    expect(report, contains('1. Dune — score 2.500'));
    expect(report, contains('arrOnly'));
  });

  test('a candidate with no justification is reported explicitly', () {
    const profile = TasteProfile(weights: {}, catalogSize: 0);
    const candidates = [
      ScoredCandidate(
        item: CandidateItem(
          id: '1',
          title: 'Mystery',
          traits: [],
          source: CandidateSource.jellyfinLibrary,
        ),
        score: 0,
        justification: null,
      ),
    ];

    final report =
        buildRecommendationDebugReport(profile: profile, candidates: candidates);

    expect(report, contains('aucune justification crédible'));
  });

  test('the negative-traits section is always shown, even when empty', () {
    final sciFi = trait(TraitKind.genre, 'Sci-Fi');
    final profile = TasteProfile(weights: {sciFi: 4.2}, catalogSize: 1);

    final report =
        buildRecommendationDebugReport(profile: profile, candidates: const []);

    expect(report, contains('Traits les plus négatifs'));
    expect(report, contains('aucun'));
  });

  test(
      'classification counts (including neverStarted/tooRecentToJudge/greyZone) are reported when provided',
      () {
    const profile = TasteProfile(weights: {}, catalogSize: 0);

    final report = buildRecommendationDebugReport(
      profile: profile,
      candidates: const [],
      classificationCounts: const {
        WatchClassification.rewatched: 2,
        WatchClassification.completedFavorite: 5,
        WatchClassification.completedNeutral: 10,
        WatchClassification.abandonedEarly: 3,
        WatchClassification.abandonedLate: 4,
        WatchClassification.neverStarted: 20,
        WatchClassification.tooRecentToJudge: 6,
        WatchClassification.greyZone: 1,
      },
    );

    expect(report, contains('Revu : 2'));
    expect(report, contains('Terminé + favori : 5'));
    expect(report, contains('Terminé : 10'));
    expect(report, contains('Abandon précoce (<20%, ancien) : 3'));
    expect(report, contains('Abandon tardif (>80%, ancien, ignoré) : 4'));
    expect(report, contains('Jamais lancé : 20'));
    expect(
        report,
        contains(
            'En pause récemment (position partielle, pas assez ancien pour juger) : 6'));
    expect(report, contains('Zone grise (20-80%, ancien, ignorée) : 1'));
  });

  test('classification counts section is omitted entirely when not provided',
      () {
    const profile = TasteProfile(weights: {}, catalogSize: 0);

    final report =
        buildRecommendationDebugReport(profile: profile, candidates: const []);

    expect(report, isNot(contains('catégorie de classification')));
  });

  test('candidate counts by source are reported when provided', () {
    const profile = TasteProfile(weights: {}, catalogSize: 0);

    final report = buildRecommendationDebugReport(
      profile: profile,
      candidates: const [],
      candidateCountsBySource: const {
        CandidateSource.jellyfinLibrary: 120,
        CandidateSource.arrOnly: 0,
      },
    );

    expect(report, contains('jellyfinLibrary : 120'));
    expect(report, contains('arrOnly : 0'));
  });

  test(
      'the Arr ranking is printed as its own section, separate from the Jellyfin one, even when empty',
      () {
    const profile = TasteProfile(weights: {}, catalogSize: 0);

    final report = buildRecommendationDebugReport(
      profile: profile,
      candidates: const [],
      arrOnlyCandidates: const [],
    );

    expect(report, contains('Recommandations (Jellyfin, 0)'));
    expect(report, contains('"Vous l\'aviez mis de côté" (Arr, 0)'));
  });

  test('the Arr ranking lists its own candidates independently', () {
    final genre = trait(TraitKind.genre, 'Thriller');
    final profile = TasteProfile(weights: {genre: 2.0}, catalogSize: 1);

    final report = buildRecommendationDebugReport(
      profile: profile,
      candidates: const [],
      arrOnlyCandidates: [
        ScoredCandidate(
          item: CandidateItem(
            id: 'arr:movie:1',
            title: 'Set Aside Movie',
            traits: const [],
            source: CandidateSource.arrOnly,
            added: DateTime(2025, 3, 12),
          ),
          score: 1.4,
          justification: genre,
        ),
      ],
    );

    expect(report, contains('1. Set Aside Movie — ajouté le 2025-03-12 — score 1.400'));
  });

  test('an Arr candidate with no known added date shows "date inconnue"', () {
    const profile = TasteProfile(weights: {}, catalogSize: 0);

    final report = buildRecommendationDebugReport(
      profile: profile,
      candidates: const [],
      arrOnlyCandidates: const [
        ScoredCandidate(
          item: CandidateItem(
            id: 'arr:movie:2',
            title: 'No Date Movie',
            traits: [],
            source: CandidateSource.arrOnly,
          ),
          score: 0.5,
          justification: null,
        ),
      ],
    );

    expect(report, contains('1. No Date Movie — date inconnue — score 0.500'));
  });

  test('the Arr section is omitted when arrOnlyCandidates is not provided',
      () {
    const profile = TasteProfile(weights: {}, catalogSize: 0);

    final report =
        buildRecommendationDebugReport(profile: profile, candidates: const []);

    expect(report, isNot(contains('mis de côté')));
  });

  test('raw sample values are printed for inspection', () {
    const profile = TasteProfile(weights: {}, catalogSize: 0);
    final lastPlayed = DateTime(2024, 3, 1);

    final report = buildRecommendationDebugReport(
      profile: profile,
      candidates: const [],
      sampleEvents: [
        WatchSignalSample(
          title: 'Some Movie',
          played: false,
          playCount: 0,
          playbackPositionTicks: 12345,
          progress: 15.5,
          lastPlayed: lastPlayed,
          classification: WatchClassification.abandonedEarly,
        ),
      ],
    );

    expect(report, contains('Some Movie'));
    expect(report, contains('played=false'));
    expect(report, contains('playCount=0'));
    expect(report, contains('playbackPositionTicks=12345'));
    expect(report, contains('progress=15.5%'));
    expect(report, contains('2024-03-01'));
    expect(report, contains('abandonedEarly'));
  });

  test('sample section is omitted when sampleEvents is not provided', () {
    const profile = TasteProfile(weights: {}, catalogSize: 0);

    final report =
        buildRecommendationDebugReport(profile: profile, candidates: const []);

    expect(report, isNot(contains('valeurs brutes')));
  });
}
