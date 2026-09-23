import 'package:kinos/recommendations/models/trait.dart';

/// Statistiques de fréquence des traits sur toute la bibliothèque
/// Jellyfin de l'utilisateur — base de comparaison de l'IDF (cf. spec :
/// "la base de comparaison doit être le catalogue, pas l'historique").
/// Calculé sur des milliers d'œuvres, jamais sur les seules œuvres ayant
/// produit un signal (33 dans le cas qui a motivé ce calibrage) : sur un
/// aussi petit échantillon, l'écart entre trait rare et trait courant
/// est écrasé.
class LibraryTraitStats {
  final int librarySize;
  final Map<TraitKey, int> traitDocFrequency;

  const LibraryTraitStats({
    required this.librarySize,
    required this.traitDocFrequency,
  });

  int frequencyOf(TraitKey trait) => traitDocFrequency[trait] ?? 0;
}
