import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinos/jellyfin/jellyfin_open_api.swagger.dart';
import 'package:kinos/models/item_base_model.dart';
import 'package:kinos/providers/api_provider.dart';
import 'package:kinos/providers/seerr_api_provider.dart';
import 'package:kinos/providers/user_provider.dart';
import 'package:kinos/models/seerr/seerr_dashboard_model.dart';

/// Session-only destination: all, media type, or a server library.
typedef CatalogScope = ({BaseItemKind? kind, String? libraryId});
const allCatalog = (kind: null, libraryId: null);
final catalogScopeProvider = StateProvider<CatalogScope>((ref) {
  ref.watch(userProvider.select((user) => (user?.id, user?.credentials)));
  return allCatalog;
});
typedef CatalogHome = ({
  List<ItemBaseModel> hero,
  List<ItemBaseModel> recent,
  List<ItemBaseModel> resume
});
final catalogHomeProvider =
    FutureProvider.family<CatalogHome, CatalogScope>((ref, scope) async {
  final account =
      ref.watch(userProvider.select((user) => (user?.id, user?.credentials)));
  if (account.$1 == null) {
    return (
      hero: <ItemBaseModel>[],
      recent: <ItemBaseModel>[],
      resume: <ItemBaseModel>[]
    );
  }
  final api = ref.read(jellyApiProvider);
  final types = scope.kind == null
      ? [BaseItemKind.movie, BaseItemKind.series]
      : [scope.kind!];
  Future<List<ItemBaseModel>> load(
      {required bool resume,
      required ItemSortBy sort,
      required int limit}) async {
    final response = await api
        .itemsGet(
          parentId: scope.libraryId,
          recursive: true,
          includeItemTypes: resume && scope.kind == BaseItemKind.series
              ? [BaseItemKind.episode]
              : types,
          filters: resume ? [ItemFilter.isresumable] : null,
          sortBy: [sort],
          sortOrder: [SortOrder.descending],
          limit: limit,
          enableUserData: true,
          enableImageTypes: [
            ImageType.backdrop,
            ImageType.primary,
            ImageType.logo,
            ImageType.thumb
          ],
          fields: [
            ItemFields.overview,
            ItemFields.mediastreams,
            ItemFields.mediasources
          ],
        )
        .timeout(const Duration(seconds: 30));
    if (!response.isSuccessful) throw StateError('Catalogue indisponible');
    final items = response.body?.items ?? <ItemBaseModel>[];
    return resume
        ? items
            .where((item) =>
                item.userData.playbackPositionTicks > 0 &&
                !item.userData.played)
            .toList()
        : items;
  }

  final lists = await Future.wait([
    load(resume: false, sort: ItemSortBy.random, limit: 8),
    load(resume: false, sort: ItemSortBy.datecreated, limit: 24),
    load(resume: true, sort: ItemSortBy.dateplayed, limit: 16),
  ]);
  return (hero: lists[0], recent: lists[1], resume: lists[2]);
});

/// Requête de recherche rapide : texte saisi et langue de l'interface
/// (balise BCP 47), utilisée pour retrouver les titres traduits.
typedef QuickSearchQuery = ({String query, String language});

const _quickSearchLimit = 24;
const _outsideLimit = 8;

/// Résultats de la recherche rapide, en deux groupes : les fiches de la
/// bibliothèque Jellyfin, et les titres que Seerr connaît hors bibliothèque
/// (à demander, ou déjà demandés).
typedef QuickSearchResults = ({
  List<ItemBaseModel> library,
  List<SeerrDashboardPosterModel> outside,
});

final quickSearchProvider = FutureProvider.autoDispose
    .family<QuickSearchResults, QuickSearchQuery>((ref, search) async {
  final account =
      ref.watch(userProvider.select((user) => (user?.id, user?.credentials)));
  final query = search.query.trim();
  const empty = (
    library: <ItemBaseModel>[],
    outside: <SeerrDashboardPosterModel>[]
  );
  if (account.$1 == null || query.isEmpty) return empty;
  final seerrConfigured = ref.read(userProvider
          .select((user) => user?.seerrCredentials?.isConfigured)) ??
      false;
  // Jellyfin ne cherche que dans le titre de ses propres métadonnées :
  // Seerr (TMDB) cherche en parallèle dans la langue de l'interface, ce qui
  // retrouve les titres traduits déjà présents et ceux à demander.
  final seerr = seerrConfigured
      ? _seerrSearch(ref, query, search.language)
      : Future.value(const <SeerrDashboardPosterModel>[]);
  final api = ref.read(jellyApiProvider);
  final response = await api
      .itemsGet(
        searchTerm: query,
        recursive: true,
        includeItemTypes: [BaseItemKind.movie, BaseItemKind.series],
        limit: _quickSearchLimit,
        enableUserData: true,
        fields: [ItemFields.overview],
      )
      .timeout(const Duration(seconds: 30));
  if (!response.isSuccessful) throw StateError('Recherche indisponible');
  final items = response.body?.items ?? <ItemBaseModel>[];
  final posters = await seerr;
  final outside = posters
      .where((poster) => poster.jellyfinItemId?.isNotEmpty != true)
      .take(_outsideLimit)
      .toList();
  final known = items.map((item) => _normalizedId(item.id)).toSet();
  final missing = [
    for (final poster in posters)
      if (poster.jellyfinItemId case final id? when id.isNotEmpty)
        if (known.add(_normalizedId(id))) id,
  ].take(_quickSearchLimit - items.length).toList();
  if (missing.isEmpty) return (library: items, outside: outside);
  try {
    final extra = await api
        .itemsGet(
          ids: missing,
          recursive: true,
          includeItemTypes: [BaseItemKind.movie, BaseItemKind.series],
          enableUserData: true,
          fields: [ItemFields.overview],
        )
        .timeout(const Duration(seconds: 15));
    if (!extra.isSuccessful) return (library: items, outside: outside);
    final byId = {
      for (final item in extra.body?.items ?? <ItemBaseModel>[])
        _normalizedId(item.id): item
    };
    return (
      library: [
        ...items,
        for (final id in missing)
          if (byId[_normalizedId(id)] case final item?) item,
      ],
      outside: outside,
    );
  } catch (_) {
    return (library: items, outside: outside);
  }
});

String _normalizedId(String id) => id.replaceAll('-', '').toLowerCase();

/// Films et séries que Seerr trouve pour [query] dans [language].
/// Best-effort : une erreur Seerr ne prive jamais l'utilisateur des
/// résultats Jellyfin.
Future<List<SeerrDashboardPosterModel>> _seerrSearch(
    Ref ref, String query, String language) async {
  try {
    return await ref
        .read(seerrApiProvider)
        .searchPosters(query: query, language: language)
        .timeout(const Duration(seconds: 10));
  } catch (_) {
    return const [];
  }
}
