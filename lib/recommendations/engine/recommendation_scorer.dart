import 'dart:math';

import 'package:kinos/recommendations/models/candidate_item.dart';
import 'package:kinos/recommendations/models/library_trait_stats.dart';
import 'package:kinos/recommendations/models/scored_candidate.dart';
import 'package:kinos/recommendations/models/taste_profile.dart';
import 'package:kinos/recommendations/models/trait.dart';

/// Spécificité d'un type de trait, du plus générique (0) au plus
/// spécifique (le plus grand) — pilote le choix de la justification (cf.
/// [RecommendationScorer._pickJustification]) : "parce que : genre
/// action" n'apprend rien, un genre ne doit servir de justification
/// qu'en dernier recours. Les mots-clés sont classés juste sous le
/// réalisateur : c'est par ce canal qu'une franchise sans titre commun
/// (ex. James Bond, dont aucun titre ne se ressemble) redevient
/// identifiable — cf. `franchise_key.dart`.
const Map<TraitKind, int> _traitSpecificity = {
  TraitKind.director: 5,
  TraitKind.keyword: 4,
  TraitKind.actor: 3,
  TraitKind.studio: 2,
  TraitKind.decade: 1,
  TraitKind.genre: 0,
};

/// Mots-clés connus pour ne rien décrire (humeur, format de production)
/// plutôt qu'un thème ou un contenu — écartés du choix de justification
/// quel que soit leur poids (cf. calibrage : "Le Retour du Jedi parce
/// que excited", "Alvin parce que live action and animation"). Liste de
/// démarrage, pas exhaustive — à étendre au fil des rapports plutôt que
/// de deviner à l'avance tout ce qui pourrait apparaître dans un
/// catalogue de mots-clés TMDb libres.
const defaultExcludedJustificationKeywords = {
  'excited',
  'live action and animation',
  'duringcreditsstinger',
  'aftercreditsstinger',
};

/// Studios/networks connus pour être trop génériques (gros diffuseurs,
/// agrégateurs) pour signaler un goût personnel, même quand
/// l'information est exacte — cf. calibrage : "Toho ou Recorded Picture
/// Company ne disent rien de mon goût". Liste de démarrage, pas
/// exhaustive — cf. [maxStudioDocFrequencyFraction] pour le cas général
/// (trop courant dans *cette* bibliothèque), cette liste couvre les cas
/// génériques même dans une petite bibliothèque où ils resteraient sous
/// le seuil de fréquence.
const defaultGenericStudioNames = {
  'netflix',
  'amazon studios',
  'amazon content services',
  'apple studios',
  'apple tv+',
  'hulu',
  'walt disney pictures',
  'disney',
  'paramount pictures',
  'paramount',
  'universal pictures',
  'warner bros. pictures',
  'warner bros.',
  'warner bros',
  'sony pictures',
  'columbia pictures',
  'twentieth century fox',
  '20th century fox',
  '20th century studios',
  'lionsgate',
  'metro-goldwyn-mayer',
  'mgm',
  'bbc',
  'bbc studios',
};

/// Note des candidats contre un [TasteProfile] — produit scalaire entre
/// le vecteur de traits du candidat (binaire : 1 si présent, 0 sinon) et
/// le profil, avec les correctifs suivants (cf. spec) :
///
/// 1. Normalisation par la norme du vecteur candidat (`sqrt(nombre de
///    traits)`) — sans elle, les œuvres les plus documentées gagnent
///    mécaniquement.
/// 2. Diversité par trait dominant, imposée après le tri : au plus
///    [maxPerDominantTrait] candidats partageant leur justification (cf.
///    point 3 — c'est délibérément le même trait qui sert à la fois de
///    justification affichée et de clé de diversité, pas deux calculs
///    distincts qui pourraient diverger).
/// 3. Justification choisie séparément du score : à contribution
///    comparable (cf. [comparableTolerance]), le trait le plus
///    spécifique l'emporte plutôt que le trait de plus grande valeur
///    absolue brute — cf. [_pickJustification].
/// 4. Diversité par franchise, imposée en plus de la diversité par
///    trait dominant : au plus [maxPerFranchise] candidats partageant
///    une même clé de franchise (cf. `CandidateItem.franchiseKeys`) —
///    attrape les suites/franchises que la diversité par trait dominant
///    laisse passer (leurs traits dominants respectifs diffèrent
///    souvent, ex. deux James Bond dont l'un est justifié par son
///    réalisateur et l'autre par un acteur).
class RecommendationScorer {
  final int maxPerDominantTrait;
  final int maxPerFranchise;

  /// Marge en deçà du maximum de contribution absolue dans laquelle un
  /// trait est considéré "à contribution comparable" pour le choix de
  /// la justification — 0.25 : un trait à au moins 75% de la
  /// contribution maximale du candidat est éligible, même s'il n'est
  /// pas strictement le plus fort.
  final double comparableTolerance;

  /// Statistiques de bibliothèque, pour écarter des mots-clés trop rares
  /// et des studios trop courants du choix de la justification (cf.
  /// [minKeywordDocFrequencyForJustification]/[maxStudioDocFrequencyFraction])
  /// — jamais du score lui-même, qui continue d'utiliser l'IDF complète.
  /// `null` : ces deux filtres de fréquence sont inactifs (les listes
  /// nommées ci-dessous restent actives quoi qu'il arrive).
  final LibraryTraitStats? libraryStats;

  /// Un mot-clé présent dans moins d'œuvres que ce seuil, dans toute la
  /// bibliothèque, n'est jamais choisi comme justification — même s'il
  /// a le poids le plus fort (cf. spec du calibrage : un mot-clé
  /// quasi-unique a un IDF énorme et remonte des raisons qui ne veulent
  /// rien dire, ex. "parce que : chipmunk"). Il continue de compter
  /// dans le score, seul son usage comme raison affichée est filtré.
  final int minKeywordDocFrequencyForJustification;

  /// Mots-clés jamais retenus comme justification, quel que soit leur
  /// poids ou leur fréquence — cf. [defaultExcludedJustificationKeywords].
  final Set<String> excludedJustificationKeywords;

  /// Un studio présent dans une proportion de la bibliothèque supérieure
  /// à cette fraction n'est jamais choisi comme justification — un gros
  /// distributeur qui produit un peu de tout ne dit rien du goût
  /// personnel (cf. calibrage). 0.05 = 5% : une bibliothèque de 1000
  /// œuvres tolère jusqu'à 50 œuvres du même studio avant de
  /// l'considérer trop générique — un studio de niche en reste très
  /// loin, un grand distributeur le dépasse largement.
  final double maxStudioDocFrequencyFraction;

  /// Studios jamais retenus comme justification, quel que soit leur
  /// poids ou leur fréquence dans *cette* bibliothèque — cf.
  /// [defaultGenericStudioNames].
  final Set<String> genericStudioNames;

  const RecommendationScorer({
    this.maxPerDominantTrait = 2,
    this.maxPerFranchise = 2,
    this.comparableTolerance = 0.25,
    this.libraryStats,
    this.minKeywordDocFrequencyForJustification = 6,
    this.excludedJustificationKeywords = defaultExcludedJustificationKeywords,
    this.maxStudioDocFrequencyFraction = 0.05,
    this.genericStudioNames = defaultGenericStudioNames,
  });

  /// [excludedIds] : vu, en cours, ou déjà en file d'attente de lecture
  /// (cf. spec) — filtré avant tout calcul, jamais après : un candidat
  /// exclu ne doit pas compter dans le classement ni la diversité des
  /// autres.
  ///
  /// [seed] : mélange les candidats avant le tri par score — sans effet
  /// sur le classement lui-même (le tri par score prime toujours), mais
  /// rend l'ordre des égalités strictes reproductible d'un appel à
  /// l'autre plutôt que dépendant de l'ordre d'itération de la liste
  /// d'entrée. Même graine que les rangées aléatoires de l'accueil (cf.
  /// `homeRowRandomSeedProvider`).
  List<ScoredCandidate> score(
    TasteProfile profile,
    List<CandidateItem> candidates, {
    Set<String> excludedIds = const {},
    int? limit,
    int? seed,
  }) {
    final input = seed == null ? candidates : _seededShuffle(candidates, seed);
    final scored = <ScoredCandidate>[
      for (final candidate in input)
        if (!excludedIds.contains(candidate.id) && candidate.traits.isNotEmpty)
          scoreCandidate(profile, candidate),
    ];

    scored.sort((a, b) => b.score.compareTo(a.score));

    final result = <ScoredCandidate>[];
    final dominantCounts = <TraitKey, int>{};
    final franchiseCounts = <String, int>{};
    for (final candidate in scored) {
      final trait = candidate.justification;
      if (trait != null && (dominantCounts[trait] ?? 0) >= maxPerDominantTrait) {
        continue;
      }
      final franchiseKeys = candidate.item.franchiseKeys;
      final blockedByFranchise = franchiseKeys
          .any((key) => (franchiseCounts[key] ?? 0) >= maxPerFranchise);
      if (blockedByFranchise) continue;

      if (trait != null) dominantCounts[trait] = (dominantCounts[trait] ?? 0) + 1;
      for (final key in franchiseKeys) {
        franchiseCounts[key] = (franchiseCounts[key] ?? 0) + 1;
      }

      result.add(candidate);
      if (limit != null && result.length >= limit) break;
    }
    return result;
  }

  /// Note un seul candidat — produit scalaire normalisé + justification
  /// (cf. [_pickJustification]), sans diversité ni tri. Extrait de
  /// [score] pour être réutilisable ailleurs qu'un classement complet —
  /// cf. `arr_added_date_ranking.dart`, qui trie par date d'ajout et ne
  /// se sert du score que comme critère secondaire, sans vouloir de la
  /// diversité par trait dominant/franchise (une rangée "ce que vous
  /// avez mis de côté" doit rester un inventaire honnête, pas une
  /// recommandation qui cacherait délibérément une suite que vous avez
  /// pourtant bien ajoutée).
  ScoredCandidate scoreCandidate(TasteProfile profile, CandidateItem candidate) {
    final contributions = <MapEntry<TraitKey, double>>[];
    var raw = 0.0;
    for (final t in candidate.traits) {
      final weight = profile.weightOf(t);
      raw += weight;
      contributions.add(MapEntry(t, weight));
    }

    final norm = sqrt(candidate.traits.length);
    final normalized = norm == 0 ? 0.0 : raw / norm;

    return ScoredCandidate(
      item: candidate,
      score: normalized,
      justification: _pickJustification(contributions),
    );
  }

  /// Choisit la justification parmi les contributions d'un candidat —
  /// pas simplement la plus forte en valeur absolue : parmi celles à au
  /// moins `(1 - comparableTolerance)` de la contribution maximale, la
  /// plus spécifique l'emporte (cf. [_traitSpecificity]), un genre
  /// n'étant retenu que si rien de plus spécifique n'est "comparable".
  ///
  /// Mots-clés et studios non crédibles sont écartés avant même de
  /// chercher le maximum (cf. [_isEligibleForJustification]) — sans ça,
  /// un trait bruyant mais au poids élevé (mot-clé quasi unique, ou
  /// simplement une erreur de métadonnées côté studio) fixerait lui-même
  /// le plafond de comparaison et resterait la seule justification
  /// "comparable" possible.
  ///
  /// Si plus aucune contribution n'est éligible, la justification est
  /// `null` — délibérément, pas un repli sur l'ensemble complet (cf.
  /// calibrage : "n'invente pas de justification, affiche la rangée
  /// sans, plutôt qu'avec une raison fausse"). Un score reste calculé
  /// et affiché normalement ; seule la raison affichée disparaît.
  TraitKey? _pickJustification(List<MapEntry<TraitKey, double>> contributions) {
    if (contributions.isEmpty) return null;

    final eligible =
        contributions.where((e) => _isEligibleForJustification(e.key)).toList();
    if (eligible.isEmpty) return null;

    final maxAbs = eligible.map((e) => e.value.abs()).fold(0.0, max);
    if (maxAbs == 0) return null;

    final threshold = maxAbs * (1 - comparableTolerance);
    final comparable =
        eligible.where((e) => e.value.abs() >= threshold).toList();
    comparable.sort((a, b) {
      final specificityDiff = (_traitSpecificity[b.key.kind] ?? 0)
          .compareTo(_traitSpecificity[a.key.kind] ?? 0);
      if (specificityDiff != 0) return specificityDiff;
      return b.value.abs().compareTo(a.value.abs());
    });
    return comparable.first.key;
  }

  /// Filtres de crédibilité, indépendants du poids/score — s'appliquent
  /// toujours (listes nommées), les seuils de fréquence seulement quand
  /// [libraryStats] est fourni.
  bool _isEligibleForJustification(TraitKey trait) {
    switch (trait.kind) {
      case TraitKind.keyword:
        if (excludedJustificationKeywords.contains(trait.value)) return false;
        if (libraryStats != null &&
            libraryStats!.frequencyOf(trait) <
                minKeywordDocFrequencyForJustification) {
          return false;
        }
        return true;
      case TraitKind.studio:
        if (genericStudioNames.contains(trait.value)) return false;
        if (libraryStats != null && libraryStats!.librarySize > 0) {
          final df = libraryStats!.frequencyOf(trait);
          final maxAllowed =
              (libraryStats!.librarySize * maxStudioDocFrequencyFraction)
                  .ceil();
          if (df > maxAllowed) return false;
        }
        return true;
      default:
        return true;
    }
  }
}

/// Mélange de Fisher-Yates déterministe — même principe et même raison
/// que `_seededShuffle` dans `home_row_items_provider.dart` : même
/// [seed] et même [items] d'entrée donnent toujours le même ordre en
/// sortie.
List<T> _seededShuffle<T>(List<T> items, int seed) {
  final random = Random(seed);
  final shuffled = [...items];
  for (var i = shuffled.length - 1; i > 0; i--) {
    final j = random.nextInt(i + 1);
    final swap = shuffled[i];
    shuffled[i] = shuffled[j];
    shuffled[j] = swap;
  }
  return shuffled;
}
