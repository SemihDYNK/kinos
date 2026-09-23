import 'package:kinos/recommendations/models/candidate_item.dart';
import 'package:kinos/recommendations/models/trait.dart';

/// Un candidat noté — score normalisé et trait dominant (le trait qui a
/// le plus contribué au score, cf. spec « Justification »). `null` si le
/// candidat ne partage aucun trait avec le profil (score nul, jamais
/// vraiment produit en pratique puisque `RecommendationScorer` écarte
/// les candidats sans trait avant de scorer).
class ScoredCandidate {
  final CandidateItem item;
  final double score;
  final TraitKey? justification;

  const ScoredCandidate({
    required this.item,
    required this.score,
    required this.justification,
  });
}
