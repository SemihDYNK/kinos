import 'package:kinos/recommendations/models/candidate_item.dart';
import 'package:kinos/recommendations/models/taste_profile.dart';
import 'package:kinos/recommendations/models/trait.dart';

/// Sélectionne jusqu'à [maxSeeds] traits pour titrer des rangées "par
/// graine" sur l'accueil — restreints à un seul trait chacun (contraste
/// avec "Pour vous", qui note sur l'ensemble du profil). Deux problèmes
/// à éviter à la fois :
///
/// 1. Des quasi-doublons ("james bond" / "007" / "mi6" / "british
///    secret service" portent quasiment le même ensemble d'œuvres) —
///    résolu par un regroupement en composantes connexes sur la
///    similarité de Jaccard des ensembles de candidats portés par
///    chaque trait, au-delà de [correlationThreshold]. Un genre large
///    (des centaines de candidats) a par construction une similarité
///    quasi nulle avec un trait rare (l'union explose), donc ne
///    "capture" jamais un trait plus spécifique par accident — pas de
///    traitement particulier par type de trait nécessaire.
/// 2. Une rangée trop courte pour être crédible — un plancher de
///    qualité : `RecommendationScorer.scoreCandidate` avec un profil
///    restreint à `{trait: poids}` donne un score strictement positif
///    si et seulement si le candidat porte ce trait, donc "candidats au
///    score positif" équivaut exactement à "candidats qui partagent ce
///    trait" — jamais une comparaison de poids entre traits de types
///    différents.
///
/// Le classement des représentants retenus est déterministe (poids
/// décroissant) — la rotation de l'*ordre d'affichage* est une
/// responsabilité de l'appelant (mélange par
/// `homeRowRandomSeedProvider`, cf. `home_catalog_providers.dart`), pas
/// de cette fonction.
List<TraitKey> selectSeedTraits(
  TasteProfile profile,
  List<CandidateItem> candidates, {
  int topWeightPoolSize = 20,
  double correlationThreshold = 0.5,
  int maxSeeds = 4,
  int minSharedCandidates = 8,
}) {
  final pool = profile.sortedByWeight
      .where((e) => e.value > 0)
      .take(topWeightPoolSize)
      .map((e) => e.key)
      .toList();
  if (pool.isEmpty) return const [];

  final idsByTrait = <TraitKey, Set<String>>{
    for (final t in pool) t: _sharingIds(t, candidates),
  };

  final clusters = _clusterByJaccard(pool, idsByTrait, correlationThreshold);

  final representatives = clusters.map((cluster) {
    return cluster
        .reduce((a, b) => profile.weightOf(b) > profile.weightOf(a) ? b : a);
  }).toList()
    ..sort((a, b) => profile.weightOf(b).compareTo(profile.weightOf(a)));

  final selected = <TraitKey>[];
  for (final rep in representatives) {
    if (selected.length >= maxSeeds) break;
    if (idsByTrait[rep]!.length >= minSharedCandidates) {
      selected.add(rep);
    }
  }
  return selected;
}

Set<String> _sharingIds(TraitKey trait, List<CandidateItem> candidates) => {
      for (final c in candidates)
        if (c.traits.contains(trait)) c.id,
    };

double _jaccard(Set<String> a, Set<String> b) {
  if (a.isEmpty && b.isEmpty) return 0;
  final intersection = a.intersection(b).length;
  final union = a.union(b).length;
  return union == 0 ? 0 : intersection / union;
}

/// Union-find minimal, local à cette fonction — pas besoin d'une
/// structure générique ailleurs dans le moteur.
List<List<TraitKey>> _clusterByJaccard(
  List<TraitKey> pool,
  Map<TraitKey, Set<String>> idsByTrait,
  double threshold,
) {
  final parent = <TraitKey, TraitKey>{for (final t in pool) t: t};
  TraitKey find(TraitKey t) {
    var root = t;
    while (parent[root] != root) {
      root = parent[root]!;
    }
    var current = t;
    while (parent[current] != root) {
      final next = parent[current]!;
      parent[current] = root;
      current = next;
    }
    return root;
  }

  void union(TraitKey a, TraitKey b) {
    final rootA = find(a);
    final rootB = find(b);
    if (rootA != rootB) parent[rootA] = rootB;
  }

  for (var i = 0; i < pool.length; i++) {
    for (var j = i + 1; j < pool.length; j++) {
      final a = pool[i];
      final b = pool[j];
      if (_jaccard(idsByTrait[a]!, idsByTrait[b]!) >= threshold) {
        union(a, b);
      }
    }
  }

  final groups = <TraitKey, List<TraitKey>>{};
  for (final t in pool) {
    groups.putIfAbsent(find(t), () => []).add(t);
  }
  return groups.values.toList();
}
