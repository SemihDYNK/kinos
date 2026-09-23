import 'package:drift/drift.dart' show Value;

import 'package:kinos/arr/models/arr_library_entry.dart';
import 'package:kinos/models/item_base_model.dart';
import 'package:kinos/models/syncing/database_item.dart';
import 'package:kinos/recommendations/adapters/justification_label.dart';
import 'package:kinos/recommendations/models/scored_candidate.dart';

/// Nombre d'entrées persistées par rangée — jamais le classement complet
/// (potentiellement des centaines) : la table ne sert qu'à afficher une
/// grille d'une douzaine de jaquettes le temps qu'un calcul frais
/// aboutisse, une marge au-delà de ce qu'une grille affiche jamais à
/// n'importe quelle largeur d'écran suffit.
const persistedRecommendationCacheLimit = 20;

/// Companions prêts à persister pour la rangée "Pour vous" — la
/// justification est déjà traduite ([justificationLabel]) pour qu'une
/// entrée en cache n'ait plus besoin du profil de goût ni d'un
/// `TraitKey` pour s'afficher (cf. `recommendation_row_section.dart`,
/// qui la réaffiche telle quelle).
List<RecommendationCacheEntriesCompanion> buildJellyfinCacheEntries(
  String userId,
  List<ScoredCandidate> candidates,
  Map<String, ItemBaseModel> itemsById,
) {
  final entries = <RecommendationCacheEntriesCompanion>[];
  for (final scored in candidates) {
    final item = itemsById[scored.item.id];
    if (item == null) continue;
    entries.add(RecommendationCacheEntriesCompanion.insert(
      userId: userId,
      rowKind: RecommendationRowKind.forYou,
      position: entries.length,
      source: RecommendationEntrySource.jellyfin,
      jellyfinItemId: Value(item.id),
      jellyfinItemType: Value(item.jellyType?.name),
      title: item.name,
      // `yearAired`, pas `productionYear` — jamais peuplé pour un item
      // chargé depuis le serveur (cf. `OverviewModel.fromBaseItemDto`,
      // même calibrage qu'ailleurs dans ce module).
      year: Value(item.overview.yearAired),
      justification: Value(justificationLabel(scored.justification)),
    ));
    if (entries.length >= persistedRecommendationCacheLimit) break;
  }
  return entries;
}

/// Companions prêts à persister pour la rangée "Vous l'aviez mis de
/// côté" — ne persiste pas la redirection vers Jellyfin
/// (`arrJellyfinMatchesById`) : une entrée en cache qui pointerait
/// encore vers Arr pendant les quelques secondes avant que le calcul
/// frais n'aboutisse est un désagrément mineur, pas une régression sur
/// la fuite entre profils ou un blocage — hors du périmètre de ce
/// branchement.
List<RecommendationCacheEntriesCompanion> buildArrCacheEntries(
  String userId,
  List<ScoredCandidate> candidates,
  Map<String, ArrLibraryEntry> entriesById,
) {
  final entries = <RecommendationCacheEntriesCompanion>[];
  for (final scored in candidates) {
    final entry = entriesById[scored.item.id];
    if (entry == null) continue;
    entries.add(RecommendationCacheEntriesCompanion.insert(
      userId: userId,
      rowKind: RecommendationRowKind.setAside,
      position: entries.length,
      source: RecommendationEntrySource.arr,
      arrId: Value(entry.id),
      arrService: Value(entry.isMovie ? 'radarr' : 'sonarr'),
      title: entry.title,
      year: Value(entry.year),
      justification: Value(justificationLabel(scored.justification)),
    ));
    if (entries.length >= persistedRecommendationCacheLimit) break;
  }
  return entries;
}

/// Vrai si [fresh] correspond exactement à [cached], même ordre, mêmes
/// entrées — pas seulement le même ensemble. "Ne reconstruis rien" si le
/// résultat est identique n'a de sens que si "identique" tient compte du
/// rang de chaque entrée, pas seulement de sa présence : un même
/// ensemble réordonné doit être traité comme un changement réel.
bool sameCacheEntries(
  List<RecommendationCacheEntriesCompanion> fresh,
  List<RecommendationCacheEntry> cached,
) {
  if (fresh.length != cached.length) return false;
  for (var i = 0; i < fresh.length; i++) {
    final f = fresh[i];
    final c = cached[i];
    if (f.source.value != c.source) return false;
    if (f.jellyfinItemId.value != c.jellyfinItemId) return false;
    if (f.arrId.value != c.arrId) return false;
    if (f.justification.value != c.justification) return false;
  }
  return true;
}
