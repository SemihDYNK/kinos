import 'package:kinos/recommendations/models/trait.dart';

/// D'où vient un candidat — distingue les entrées Radarr/Sonarr
/// présentes mais jamais lancées (pure intention, cf. spec du lot) du
/// reste de la bibliothèque Jellyfin, pour qu'un lot futur (rangée
/// dédiée) puisse les séparer sans recalculer quoi que ce soit.
enum CandidateSource { jellyfinLibrary, arrOnly }

/// Une œuvre candidate à la recommandation — bibliothèque Jellyfin non
/// vue, ou entrée Radarr/Sonarr présente mais jamais lancée. Mêmes
/// [TraitKey] que [WatchEvent] : c'est ce qui permet le produit scalaire
/// avec le profil de goût.
class CandidateItem {
  final String id;
  final String title;
  final List<TraitKey> traits;
  final CandidateSource source;

  /// Clés de regroupement franchise/collection — titre normalisé, tags
  /// de mots-clés, collection TMDB si connue (cf.
  /// `lib/recommendations/adapters/franchise_key.dart`). Plusieurs clés
  /// possibles par candidat : un candidat peut appartenir à un
  /// regroupement par son titre (ex. "Moi, moche et méchant 2") ET à un
  /// autre par un mot-clé partagé (ex. "james bond", qui ne se retrouve
  /// dans aucun titre de la franchise). Vide par défaut — aucun
  /// regroupement, comportement d'avant le calibrage.
  final List<String> franchiseKeys;

  /// Année de sortie/production, quand connue — sert au dédoublonnage
  /// Arr/Jellyfin (cf. `arr_jellyfin_dedup.dart`, filet de sécurité
  /// contre une collision de titre entre deux œuvres distinctes), pas
  /// au scoring lui-même (cf. `TraitKind.decade` pour l'équivalent
  /// utilisé dans le vecteur de traits).
  final int? year;

  /// Date d'ajout à la bibliothèque d'origine, quand connue — critère
  /// de tri principal de la rangée Arr "Vous l'aviez mis de côté" (cf.
  /// `arr_added_date_ranking.dart`) ; sans objet pour un candidat
  /// Jellyfin, laissé `null`.
  final DateTime? added;

  const CandidateItem({
    required this.id,
    required this.title,
    required this.traits,
    required this.source,
    this.franchiseKeys = const [],
    this.year,
    this.added,
  });
}
