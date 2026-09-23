import 'package:kinos/jellyfin/jellyfin_open_api.enums.swagger.dart';
import 'package:kinos/models/item_base_model.dart';
import 'package:kinos/models/items/overview_model.dart';
import 'package:kinos/recommendations/models/library_trait_stats.dart';
import 'package:kinos/recommendations/models/trait.dart';

/// Nombre d'acteurs principaux retenus par œuvre — au-delà, "c'est du
/// bruit" (cf. spec). Suppose que Jellyfin renvoie `People` dans l'ordre
/// de billing (c'est le cas en pratique : l'ordre vient tel quel du
/// fournisseur de métadonnées configuré côté serveur).
const _maxActors = 4;

/// Traits d'une œuvre Jellyfin, communs au profil de goût (côté
/// historique) et aux candidats (côté bibliothèque) — c'est ce qui
/// permet au produit scalaire du moteur de les comparer. Genres,
/// réalisateur(s), [_maxActors] premiers acteurs, décennie, studios, et
/// les tags Jellyfin en guise de mots-clés (l'API n'expose rien de plus
/// spécifique).
List<TraitKey> traitsFromOverview(OverviewModel overview) {
  final traits = <TraitKey>[];

  for (final genre in overview.genres) {
    if (genre.isNotEmpty) traits.add(trait(TraitKind.genre, genre));
  }

  for (final studio in overview.studios) {
    if (studio.name.isNotEmpty) {
      traits.add(trait(TraitKind.studio, studio.name));
    }
  }

  for (final tag in overview.tags) {
    if (tag.isNotEmpty) traits.add(trait(TraitKind.keyword, tag));
  }

  // `yearAired`, pas `productionYear` : les deux coexistent sur
  // `OverviewModel`, mais seul `yearAired` est réellement peuplé par
  // `OverviewModel.fromBaseItemDto` pour un item chargé depuis le
  // serveur — `productionYear` y reste toujours `null` (cf. calibrage :
  // le trait "décennie" ne se déclenchait jamais, silencieusement,
  // depuis l'origine de ce lot).
  final decade = decadeTrait(overview.yearAired);
  if (decade != null) traits.add(decade);

  for (final director in overview.directors) {
    if (director.name.isNotEmpty) {
      traits.add(trait(TraitKind.director, director.name));
    }
  }

  final actors = overview.people
      .where((p) => p.type == PersonKind.actor && p.name.isNotEmpty)
      .take(_maxActors);
  for (final actor in actors) {
    traits.add(trait(TraitKind.actor, actor.name));
  }

  return traits;
}

/// Statistiques de traits (fréquence documentaire, base de l'IDF — cf.
/// [LibraryTraitStats]) sur un ensemble d'œuvres déjà en mémoire. Pure
/// fonction, aucun accès réseau : remplace, depuis le calibrage de
/// performance, un aller-retour dédié (`_fullLibraryTraitStatsProvider`,
/// supprimé) qui refaisait une requête complète sur toute la
/// bibliothèque — 44 s mesurées sur un serveur distant pour ~1200
/// items — alors que [items] = `played` ∪ `unwatched` (déjà récupérés
/// par ailleurs pour construire les candidats et le profil de goût)
/// couvre exactement le même ensemble : tout film/série de la
/// bibliothèque est soit vu, soit pas, jamais les deux, jamais ni l'un
/// ni l'autre.
LibraryTraitStats buildLibraryTraitStats(List<ItemBaseModel> items) {
  final traitDocFrequency = <TraitKey, int>{};
  for (final item in items) {
    // Set : une seule fois par œuvre, même si `traitsFromOverview`
    // renvoyait un doublon (cf. même précaution dans
    // TasteProfileBuilder pour la fréquence documentaire côté
    // historique).
    for (final trait in traitsFromOverview(item.overview).toSet()) {
      traitDocFrequency.update(trait, (v) => v + 1, ifAbsent: () => 1);
    }
  }
  return LibraryTraitStats(
      librarySize: items.length, traitDocFrequency: traitDocFrequency);
}
