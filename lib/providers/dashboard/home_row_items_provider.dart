import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fladder/jellyfin/jellyfin_open_api.enums.swagger.dart';
import 'package:fladder/models/item_base_model.dart';
import 'package:fladder/models/settings/home_row_model.dart';
import 'package:fladder/providers/api_provider.dart';
import 'package:fladder/providers/dashboard/home_row_random_seed_provider.dart';

const _rowItemLimit = 16;

/// Taille du lot tiré du serveur avant mélange côté client, pour les
/// rangées "aléatoires" (cf. [_seededShuffle]). Un tri déterministe
/// (`SortName`) sur ce lot introduit un léger biais alphabétique par
/// rapport à un vrai tirage sur toute la bibliothèque, mais c'est le prix
/// de la stabilité pendant la session — cf. [homeRowRandomSeedProvider].
const _randomPoolLimit = 300;

/// Films et séries uniquement (cf. CLAUDE.md § Périmètre).
const _rowItemTypes = [BaseItemKind.movie, BaseItemKind.series];

const _rowImageTypes = [ImageType.primary, ImageType.backdrop, ImageType.thumb];

const _rowFields = [
  ItemFields.parentid,
  ItemFields.mediastreams,
  ItemFields.overview,
  ItemFields.primaryimageaspectratio,
];

/// Contenu d'une rangée configurable de l'accueil.
///
/// `autoDispose` : la requête ne part que lorsqu'un widget observe
/// effectivement cette rangée — donc seulement quand elle approche du
/// champ de vision (la rangée n'est construite par le [CustomScrollView]
/// qu'à ce moment-là), jamais au démarrage à froid. Elle se libère quand
/// plus personne ne l'observe (rangée scrollée hors champ puis retirée).
///
/// Une erreur réseau retombe sur une liste vide plutôt que de propager
/// l'exception : une rangée en échec doit disparaître silencieusement, pas
/// planter l'accueil ni afficher un état d'erreur.
final homeRowItemsProvider = FutureProvider.autoDispose
    .family<List<ItemBaseModel>, HomeRowModel>((ref, row) async {
  final api = ref.read(jellyApiProvider);
  final seed = ref.watch(homeRowRandomSeedProvider);

  try {
    switch (row.type) {
      case HomeRowType.genre:
        final id = row.params['genreId'];
        if (id == null) return const [];
        final response = await api.usersUserIdItemsGet(
          genreIds: [id],
          sortBy: [ItemSortBy.sortname],
          includeItemTypes: _rowItemTypes,
          recursive: true,
          limit: _randomPoolLimit,
          fields: _rowFields,
          enableImageTypes: _rowImageTypes,
        );
        return _seededShuffle(_toItems(ref, response.body?.items), seed)
            .take(_rowItemLimit)
            .toList();

      case HomeRowType.topRated:
        final response = await api.usersUserIdItemsGet(
          sortBy: [ItemSortBy.communityrating],
          sortOrder: [SortOrder.descending],
          minCommunityRating: 7,
          includeItemTypes: _rowItemTypes,
          recursive: true,
          limit: _rowItemLimit,
          fields: _rowFields,
          enableImageTypes: _rowImageTypes,
        );
        return _toItems(ref, response.body?.items);

      case HomeRowType.director:
        final id = row.params['personId'];
        if (id == null) return const [];
        final response = await api.usersUserIdItemsGet(
          personIds: [id],
          sortBy: [ItemSortBy.sortname],
          includeItemTypes: _rowItemTypes,
          recursive: true,
          limit: _randomPoolLimit,
          fields: _rowFields,
          enableImageTypes: _rowImageTypes,
        );
        return _seededShuffle(_toItems(ref, response.body?.items), seed)
            .take(_rowItemLimit)
            .toList();

      case HomeRowType.studio:
        final id = row.params['studioId'];
        if (id == null) return const [];
        final response = await api.usersUserIdItemsGet(
          studioIds: [id],
          sortBy: [ItemSortBy.sortname],
          includeItemTypes: _rowItemTypes,
          recursive: true,
          limit: _randomPoolLimit,
          fields: _rowFields,
          enableImageTypes: _rowImageTypes,
        );
        return _seededShuffle(_toItems(ref, response.body?.items), seed)
            .take(_rowItemLimit)
            .toList();

      case HomeRowType.unwatched:
        final response = await api.usersUserIdItemsGet(
          isPlayed: false,
          sortBy: [ItemSortBy.sortname],
          includeItemTypes: _rowItemTypes,
          recursive: true,
          limit: _randomPoolLimit,
          fields: _rowFields,
          enableImageTypes: _rowImageTypes,
        );
        return _seededShuffle(_toItems(ref, response.body?.items), seed)
            .take(_rowItemLimit)
            .toList();

      case HomeRowType.rediscover:
        final response = await api.usersUserIdItemsGet(
          isPlayed: true,
          sortBy: [ItemSortBy.sortname],
          includeItemTypes: _rowItemTypes,
          recursive: true,
          limit: _randomPoolLimit,
          fields: _rowFields,
          enableImageTypes: _rowImageTypes,
        );
        return _seededShuffle(_toItems(ref, response.body?.items), seed)
            .take(_rowItemLimit)
            .toList();

      case HomeRowType.decade:
        final decade = int.tryParse(row.params['decade'] ?? '');
        if (decade == null) return const [];
        final response = await api.usersUserIdItemsGet(
          years: List.generate(10, (i) => decade + i),
          sortBy: [ItemSortBy.sortname],
          includeItemTypes: _rowItemTypes,
          recursive: true,
          limit: _randomPoolLimit,
          fields: _rowFields,
          enableImageTypes: _rowImageTypes,
        );
        return _seededShuffle(_toItems(ref, response.body?.items), seed)
            .take(_rowItemLimit)
            .toList();

      case HomeRowType.similar:
        // "Le dernier item terminé" : le plus récent des items marqués vus.
        final lastPlayed = await api.usersUserIdItemsGet(
          isPlayed: true,
          sortBy: [ItemSortBy.dateplayed],
          sortOrder: [SortOrder.descending],
          includeItemTypes: _rowItemTypes,
          recursive: true,
          limit: 1,
        );
        final lastId = lastPlayed.body?.items?.firstOrNull?.id;
        if (lastId == null) return const [];
        final response = await api.itemsItemIdSimilarGet(
            itemId: lastId, limit: _rowItemLimit);
        return _toItems(ref, response.body?.items);

      case HomeRowType.collection:
        final id = row.params['boxSetId'];
        if (id == null) return const [];
        final response = await api.usersUserIdItemsGet(
          parentId: id,
          recursive: true,
          limit: _rowItemLimit,
          fields: _rowFields,
          enableImageTypes: _rowImageTypes,
        );
        return _toItems(ref, response.body?.items);
    }
  } catch (_) {
    return const [];
  }
});

List<ItemBaseModel> _toItems(Ref ref, List<dynamic>? dtos) =>
    dtos?.map((e) => ItemBaseModel.fromBaseDto(e, ref)).toList() ?? const [];

/// Mélange de Fisher-Yates déterministe : même [seed] et même [items]
/// d'entrée donnent toujours le même ordre en sortie. C'est ce qui rend une
/// rangée "aléatoire" stable pendant la session — cf.
/// [homeRowRandomSeedProvider] pour pourquoi `SortBy=Random` seul ne suffit
/// pas.
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
