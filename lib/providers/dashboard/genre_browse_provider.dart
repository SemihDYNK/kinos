import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kinos/jellyfin/jellyfin_open_api.swagger.dart';
import 'package:kinos/models/item_base_model.dart';
import 'package:kinos/models/items/images_models.dart';
import 'package:kinos/providers/api_provider.dart';
import 'package:kinos/providers/dashboard/catalog_navigation_provider.dart';
import 'package:kinos/providers/user_provider.dart';
import 'package:kinos/recommendations/adapters/catalog_inventory.dart'
    show canonicalGenreLabel;

/// Un genre de la bibliothèque, variantes de taxonomie fusionnées
/// (« Action & Adventure », « Action et aventure »…) : libellé affiché,
/// noms bruts Jellyfin à filtrer, et une image d'un titre du genre.
typedef BrowseGenre = ({String label, List<String> names, ImageData? image});

List<BaseItemKind> _kinds(CatalogScope scope) => scope.kind == null
    ? const [BaseItemKind.movie, BaseItemKind.series]
    : [scope.kind!];

/// Fusions propres à cette rangée, par-dessus [canonicalGenreLabel] : le
/// moteur de recommandations garde « Action et aventure » (genre TV de
/// TMDB) à part ; ici, une tuile « Action » suffit et la page du genre
/// filtre sur toutes les variantes.
const _browseMerges = {
  'action et aventure': 'Action',
  'action/aventure': 'Action',
};

/// Libellé affiché d'un genre brut.
String browseGenreLabel(String rawGenre) {
  final label = canonicalGenreLabel(rawGenre);
  return _browseMerges[label.toLowerCase()] ?? label;
}

/// Regroupe des noms de genres bruts par libellé affiché, triés par
/// libellé.
Map<String, List<String>> groupGenreNames(Iterable<String> rawNames) {
  final groups = <String, List<String>>{};
  for (final raw in rawNames) {
    final name = raw.trim();
    if (name.isEmpty) continue;
    (groups[browseGenreLabel(name)] ??= []).add(name);
  }
  final labels = groups.keys.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return {for (final label in labels) label: groups[label]!};
}

/// Genres de la portée (tout, films, séries ou une bibliothèque), chacun
/// avec l'image de fond d'un titre plutôt bien noté, tirée au hasard une
/// fois par session et jamais deux fois la même dans la rangée. Un genre
/// sans image (aucun titre avec fond d'écran) garde une tuile sobre.
final browseGenresProvider = FutureProvider.autoDispose
    .family<List<BrowseGenre>, CatalogScope>((ref, scope) async {
  final account =
      ref.watch(userProvider.select((user) => (user?.id, user?.credentials)));
  if (account.$1 == null) return const [];
  final api = ref.read(jellyApiProvider);
  final kinds = _kinds(scope);
  final response = await api
      .genresGet(parentId: scope.libraryId, includeItemTypes: kinds)
      .timeout(const Duration(seconds: 30));
  final groups = groupGenreNames(
      (response.body?.items ?? const <BaseItemDto>[]).map((g) => g.name ?? ''));

  Future<List<ItemBaseModel>> sample(List<String> names,
      {num? minRating}) async {
    final result = await api
        .itemsGet(
          genres: names,
          parentId: scope.libraryId,
          includeItemTypes: kinds,
          recursive: true,
          limit: 8,
          sortBy: [ItemSortBy.random],
          imageTypes: [ImageType.backdrop],
          enableImageTypes: [ImageType.backdrop],
          minCommunityRating: minRating,
        )
        .timeout(const Duration(seconds: 30));
    return result.body?.items ?? const <ItemBaseModel>[];
  }

  final entries = groups.entries.toList();
  final samples = List<List<ItemBaseModel>>.filled(entries.length, const []);
  // Par petits lots : une vingtaine de genres, sans noyer le serveur.
  for (var i = 0; i < entries.length; i += 4) {
    await Future.wait([
      for (var j = i; j < i + 4 && j < entries.length; j++)
        () async {
          try {
            var items = await sample(entries[j].value, minRating: 6.5);
            if (items.isEmpty) items = await sample(entries[j].value);
            samples[j] = items;
          } catch (_) {
            // Genre sans image plutôt que rangée absente.
          }
        }()
    ]);
  }

  final used = <String>{};
  final genres = <BrowseGenre>[];
  for (final (i, entry) in entries.indexed) {
    final candidates = samples[i];
    final pick =
        candidates.where((item) => !used.contains(item.id)).firstOrNull ??
            candidates.firstOrNull;
    if (pick != null) used.add(pick.id);
    genres.add((
      label: entry.key,
      names: entry.value,
      image: pick?.images?.backDrop?.firstOrNull,
    ));
  }
  ref.keepAlive();
  return genres;
});

/// Clé d'une page de genre : portée et noms bruts du genre.
typedef GenrePageKey = ({CatalogScope scope, String names});

GenrePageKey genrePageKey(CatalogScope scope, List<String> names) =>
    (scope: scope, names: names.join('|'));

/// Rangées d'une page de genre, triées côté serveur.
typedef GenrePage = ({
  List<ItemBaseModel> topRated,
  List<ItemBaseModel> recent,
  List<ItemBaseModel> unvisited,
  List<ItemBaseModel> movies,
  List<ItemBaseModel> series,

  /// Décennie (1990, 2000…) → titres du genre, les mieux notés d'abord ;
  /// les plus récentes en premier, les trop petites écartées.
  Map<int, List<ItemBaseModel>> decades,
});

const _genreRowLimit = 16;

/// Plus petite décennie affichée sur une page de genre : une demi-rangée.
const _decadeMinItems = 5;

/// Titres des genres parcourus d'un coup pour les décennies.
const _genreAllLimit = 500;

/// Répartit [items] par décennie de sortie, ordre décroissant, en écartant
/// les décennies de moins de [minItems] titres.
Map<int, List<ItemBaseModel>> groupByDecade(Iterable<ItemBaseModel> items,
    {int minItems = _decadeMinItems, int perDecade = _genreRowLimit}) {
  final decades = <int, List<ItemBaseModel>>{};
  for (final item in items) {
    final year = item.overview.productionYear ?? item.overview.yearAired;
    if (year == null) continue;
    (decades[year ~/ 10 * 10] ??= []).add(item);
  }
  final keys = decades.keys.where((d) => decades[d]!.length >= minItems).toList()
    ..sort((a, b) => b.compareTo(a));
  return {for (final d in keys) d: decades[d]!.take(perDecade).toList()};
}

final genrePageProvider = FutureProvider.autoDispose
    .family<GenrePage, GenrePageKey>((ref, key) async {
  ref.watch(userProvider.select((user) => (user?.id, user?.credentials)));
  final api = ref.read(jellyApiProvider);
  final names = key.names.split('|');
  final scope = key.scope;

  Future<List<ItemBaseModel>> row(
      {required List<ItemSortBy> sortBy,
      List<BaseItemKind>? kinds,
      bool? isPlayed,
      int limit = _genreRowLimit,
      bool descending = true}) async {
    final result = await api
        .itemsGet(
          genres: names,
          parentId: scope.libraryId,
          includeItemTypes: kinds ?? _kinds(scope),
          recursive: true,
          limit: limit,
          sortBy: sortBy,
          sortOrder: [descending ? SortOrder.descending : SortOrder.ascending],
          isPlayed: isPlayed,
          enableUserData: true,
          fields: [ItemFields.overview],
        )
        .timeout(const Duration(seconds: 30));
    return result.body?.items ?? const <ItemBaseModel>[];
  }

  // Sur « À la une » (films et séries mêlés), une rangée par type en plus.
  final mixed = scope.kind == null;
  final rows = await Future.wait([
    row(sortBy: [ItemSortBy.communityrating]),
    row(sortBy: [ItemSortBy.datecreated]),
    row(sortBy: [ItemSortBy.random], isPlayed: false),
    if (mixed) row(sortBy: [ItemSortBy.random], kinds: [BaseItemKind.movie]),
    if (mixed) row(sortBy: [ItemSortBy.random], kinds: [BaseItemKind.series]),
    row(sortBy: [ItemSortBy.communityrating], limit: _genreAllLimit),
  ]);
  return (
    topRated: rows[0],
    recent: rows[1],
    unvisited: rows[2],
    movies: mixed ? rows[3] : const <ItemBaseModel>[],
    series: mixed ? rows[4] : const <ItemBaseModel>[],
    decades: groupByDecade(rows.last),
  );
});
