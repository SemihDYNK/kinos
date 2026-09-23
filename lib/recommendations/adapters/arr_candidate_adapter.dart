import 'package:kinos/arr/models/arr_library_entry.dart';
import 'package:kinos/arr/models/arr_media_detail.dart' show extractArrGenres;
import 'package:kinos/recommendations/adapters/franchise_key.dart';
import 'package:kinos/recommendations/models/candidate_item.dart';
import 'package:kinos/recommendations/models/trait.dart';

/// Construit les candidats "intention pure" (cf. spec) à partir de la
/// bibliothèque Radarr/Sonarr — genres, décennie et studio/network : les
/// entrées de bibliothèque Arr (`ArrMovie`/`ArrSeries`) ne portent ni
/// réalisateur ni distribution ni mots-clés (ce client ne les récupère
/// pas, et Radarr/Sonarr eux-mêmes n'exposent pas de casting — c'est une
/// limite de leur API, pas un oubli de récupération), un candidat Arr
/// reste donc structurellement moins riche qu'un candidat Jellyfin même
/// une fois enrichi de tout ce qui est réellement disponible. C'est
/// pourquoi ces candidats sont notés séparément des candidats Jellyfin
/// (cf. `RecommendationScorer` appelé deux fois dans
/// `recommendation_providers.dart`, jamais sur une liste fusionnée) :
/// les mettre en compétition directe désavantagerait structurellement
/// Arr quelle que soit la richesse ajoutée ici.
///
/// Le JSON brut déjà conservé sur chaque entrée (`raw`, gardé pour les
/// `PUT` — cf. `arr_library_item.dart`) évite un second appel réseau :
/// genres, studio/network et collection y sont déjà présents.
///
/// Seules les entrées avec du contenu (`hasContent`) sont retenues —
/// "jamais lancées" suppose qu'il y a quelque chose à lancer ; une
/// entrée sans fichier n'est encore qu'une intention de suivi, pas une
/// recommandation possible.
///
/// Ne filtre pas par "déjà vu/déjà connu de Jellyfin" — c'est
/// `excludeArrCandidatesKnownToJellyfin` (`arr_jellyfin_dedup.dart`) qui
/// s'en charge, appliqué par l'appelant sur les candidats déjà
/// construits (comparaison titre/année en mémoire, jamais une recherche
/// réseau par entrée, prohibitif sur plusieurs milliers d'entrées).
/// Identifiant d'un candidat Arr — même règle des deux côtés qui en ont
/// besoin (`buildArrCandidates` ci-dessous, et
/// `recommendation_providers.dart` pour retrouver l'[ArrLibraryEntry]
/// d'origine derrière un candidat noté, ex. pour la navigation depuis
/// une rangée d'accueil) : une seule fonction, jamais deux
/// constructions du même format qui pourraient diverger.
String arrCandidateId(ArrLibraryEntry entry) =>
    'arr:${entry.isMovie ? 'movie' : 'series'}:${entry.id}';

List<CandidateItem> buildArrCandidates(List<ArrLibraryEntry> entries) {
  final candidates = <CandidateItem>[];
  for (final entry in entries) {
    if (!entry.hasContent) continue;

    final raw = entry.isMovie ? entry.movie!.raw : entry.series!.raw;
    final traits = <TraitKey>[
      for (final genre in extractArrGenres(raw['genres']))
        if (genre.isNotEmpty) trait(TraitKind.genre, genre),
    ];
    final decade = decadeTrait(entry.year);
    if (decade != null) traits.add(decade);
    // Radarr : `studio` (chaîne). Sonarr : `network` (chaîne, la chaîne
    // de diffusion — même rôle de "marque de production" pour une
    // série qu'un studio pour un film).
    final studioOrNetwork = entry.isMovie ? raw['studio'] : raw['network'];
    if (studioOrNetwork is String && studioOrNetwork.isNotEmpty) {
      traits.add(trait(TraitKind.studio, studioOrNetwork));
    }
    if (traits.isEmpty) continue;

    // Radarr expose la collection TMDB directement sur la ressource
    // film (`{name, tmdbId}`) — la source la plus fiable de franchise
    // pour un candidat Arr, quand elle existe (absente pour beaucoup de
    // films, et Sonarr n'a pas d'équivalent pour les séries).
    final collection = entry.isMovie ? raw['collection'] : null;
    final tmdbCollectionId = collection is Map && collection['tmdbId'] != null
        ? collection['tmdbId'].toString()
        : null;

    candidates.add(CandidateItem(
      id: arrCandidateId(entry),
      title: entry.title,
      traits: traits,
      source: CandidateSource.arrOnly,
      franchiseKeys: franchiseKeysFor(entry.title, traits,
          tmdbCollectionId: tmdbCollectionId),
      year: entry.year,
      added: entry.added,
    ));
  }
  return candidates;
}
