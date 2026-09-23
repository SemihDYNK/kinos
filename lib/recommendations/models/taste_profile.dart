import 'package:kinos/recommendations/models/trait.dart';

/// Profil de goût d'un utilisateur Jellyfin — un poids par trait,
/// jamais partagé entre profils (cf. spec : un profil par utilisateur,
/// les goûts de l'un ne doivent pas fuiter chez l'autre). Construit par
/// `TasteProfileBuilder`, consommé par `RecommendationScorer`.
class TasteProfile {
  final Map<TraitKey, double> weights;

  /// Nombre d'œuvres distinctes ayant contribué au moins un signal
  /// exploitable (l'historique, pas la bibliothèque) — gardé pour
  /// l'entrée de mise au point, pas utilisé par le scoring lui-même.
  final int catalogSize;

  /// Taille de la base utilisée pour l'IDF — la bibliothèque Jellyfin
  /// complète quand elle est fournie (cf. `LibraryTraitStats`), sinon
  /// repli sur [catalogSize]. Distinct de [catalogSize] : sur un petit
  /// historique, la base IDF doit rester la bibliothèque pour que
  /// l'écart rare/courant ne soit pas écrasé (cf. spec du calibrage).
  final int idfBaseSize;

  const TasteProfile({
    required this.weights,
    required this.catalogSize,
    int? idfBaseSize,
  }) : idfBaseSize = idfBaseSize ?? catalogSize;

  double weightOf(TraitKey trait) => weights[trait] ?? 0.0;

  /// Traits triés par poids décroissant — pour l'entrée de mise au
  /// point et pour toute inspection manuelle du profil.
  List<MapEntry<TraitKey, double>> get sortedByWeight =>
      weights.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
}
