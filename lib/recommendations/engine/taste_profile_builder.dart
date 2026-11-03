import 'dart:math';

import 'package:kinos/recommendations/models/accumulation_saturation.dart';
import 'package:kinos/recommendations/models/library_trait_stats.dart';
import 'package:kinos/recommendations/models/taste_profile.dart';
import 'package:kinos/recommendations/models/trait.dart';
import 'package:kinos/recommendations/models/watch_event.dart';

/// Coefficient par type de trait — appliqué après saturation et IDF.
/// Les genres sont volontairement sous-pondérés par défaut : trop larges
/// pour discriminer un goût (cf. spec du calibrage — "les genres
/// écrasent tout"), même une fois saturés et corrigés par IDF. Les
/// autres types restent à 1.0 (neutres) par défaut.
const Map<TraitKind, double> defaultTraitKindWeights = {
  TraitKind.genre: 0.4,
  TraitKind.decade: 0.7,
  TraitKind.studio: 0.8,
  TraitKind.actor: 1.0,
  TraitKind.keyword: 1.0,
  TraitKind.director: 1.2,
};

/// Décroissance temporelle (demi-vie [halfLife]) appliquée à un
/// événement — top-level et publique pour être réutilisée par
/// [sourceEventForTrait] sans dupliquer la formule.
double decayFactor(DateTime? occurredAt, DateTime now,
    {Duration halfLife = const Duration(days: 182)}) {
  // Non daté : poids plein plutôt qu'un événement silencieusement
  // exclu (cf. WatchEvent.occurredAt).
  if (occurredAt == null) return 1.0;
  final daysSince = now.difference(occurredAt).inHours / 24.0;
  if (daysSince <= 0) return 1.0;
  final halfLifeDays = halfLife.inHours / 24.0;
  if (halfLifeDays <= 0) return 1.0;
  return pow(0.5, daysSince / halfLifeDays).toDouble();
}

/// L'événement dont la contribution à [seed] est maximale — exactement
/// la contribution individuelle que [TasteProfileBuilder.build] additionne
/// pour construire le poids du trait (même formule, pas une
/// approximation) : `signal.baseWeight * decayFactor(...)`. Utilisé pour
/// titrer une rangée par graine depuis l'œuvre qui y a le plus contribué
/// (`seedRowTitle`, "Car vous avez aimé..."). Retourne `null` si aucun
/// événement ne porte ce trait.
WatchEvent? sourceEventForTrait(
  TraitKey seed,
  List<WatchEvent> events, {
  DateTime? now,
  Duration halfLife = const Duration(days: 182),
}) {
  final reference = now ?? DateTime.now();
  WatchEvent? best;
  double bestContribution = double.negativeInfinity;
  for (final event in events) {
    if (event.baseWeight == 0) continue;
    if (!event.traits.contains(seed)) continue;
    final contribution = event.baseWeight *
        decayFactor(event.occurredAt, reference, halfLife: halfLife);
    if (contribution > bestContribution) {
      bestContribution = contribution;
      best = event;
    }
  }
  return best;
}

/// Construit un [TasteProfile] à partir d'un historique de visionnages —
/// cœur du lot, pure fonction de [WatchEvent] vers poids de traits.
///
/// Trois corrections s'enchaînent sur la somme brute d'un trait :
/// 1. [saturation] — corrige la fréquence dans l'*historique* (un trait
///    présent dans 22 œuvres sur 33 ne doit pas peser 22x plus qu'un
///    trait présent une fois).
/// 2. IDF — corrige la fréquence dans le *catalogue* ([libraryStats] si
///    fourni, sinon repli sur l'historique lui-même).
/// 3. [traitKindWeights] — corrige le type de trait (un genre reste
///    structurellement moins discriminant qu'un réalisateur, même rare).
///
/// Et une décroissance temporelle (demi-vie [halfLife]) est appliquée
/// par événement, avant toute agrégation.
class TasteProfileBuilder {
  final Duration halfLife;
  final AccumulationSaturation saturation;
  final Map<TraitKind, double> traitKindWeights;

  const TasteProfileBuilder({
    this.halfLife = const Duration(days: 182),
    this.saturation = AccumulationSaturation.sqrt,
    this.traitKindWeights = defaultTraitKindWeights,
  });

  /// [now] : injectable pour les tests (sinon `DateTime.now()`).
  /// [libraryStats] : base de l'IDF — la bibliothèque Jellyfin complète
  /// quand elle est fournie (cf. spec), sinon repli sur l'historique
  /// (comportement d'origine, gardé pour les tests qui isolent le
  /// builder sans dépendre d'une bibliothèque entière).
  TasteProfile build(
    List<WatchEvent> events, {
    DateTime? now,
    LibraryTraitStats? libraryStats,
  }) {
    final reference = now ?? DateTime.now();

    // abandonedLate (poids brut nul) exclu tôt : il ne doit compter ni
    // dans les scores de trait, ni dans la fréquence de l'historique —
    // un abandon tardif ne dit rien du goût dans un sens ou l'autre
    // (cf. WatchSignal.abandonedLate).
    final relevant = events.where((e) => e.baseWeight != 0).toList();

    final rawScores = <TraitKey, double>{};
    final historyDocFrequency = <TraitKey, int>{};
    final catalogItemIds = <String>{};

    for (final event in relevant) {
      catalogItemIds.add(event.itemId);
      final decay =
          decayFactor(event.occurredAt, reference, halfLife: halfLife);
      final contribution = event.baseWeight * decay;

      // Un trait compté une seule fois par œuvre pour la fréquence
      // documentaire, même s'il apparaissait en double dans sa liste de
      // traits.
      final seenInThisEvent = <TraitKey>{};
      for (final trait in event.traits) {
        rawScores.update(trait, (v) => v + contribution,
            ifAbsent: () => contribution);
        if (seenInThisEvent.add(trait)) {
          historyDocFrequency.update(trait, (v) => v + 1, ifAbsent: () => 1);
        }
      }
    }

    final historySize = catalogItemIds.length;
    final idfBaseSize = libraryStats?.librarySize ?? historySize;

    final weights = <TraitKey, double>{};
    rawScores.forEach((trait, raw) {
      final saturated = saturation.apply(raw);

      final df = libraryStats != null
          ? libraryStats.frequencyOf(trait)
          : (historyDocFrequency[trait] ?? 0);
      // IDF lissé (même formule que scikit-learn) : toujours
      // strictement positif, même quand df == idfBaseSize (trait
      // présent partout) — un multiplicateur négatif ou nul
      // inverserait ou effacerait le signe d'un trait déjà faible,
      // plutôt que de simplement le neutraliser sans le trahir.
      final idf = log((1 + idfBaseSize) / (1 + df)) + 1;

      final kindWeight = traitKindWeights[trait.kind] ?? 1.0;

      weights[trait] = saturated * idf * kindWeight;
    });

    return TasteProfile(
      weights: weights,
      catalogSize: historySize,
      idfBaseSize: idfBaseSize,
    );
  }
}
