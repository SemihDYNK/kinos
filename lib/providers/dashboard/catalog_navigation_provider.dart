import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinos/jellyfin/jellyfin_open_api.swagger.dart';
import 'package:kinos/models/item_base_model.dart';
import 'package:kinos/providers/api_provider.dart';
import 'package:kinos/providers/user_provider.dart';

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

final quickSearchProvider = FutureProvider.autoDispose
    .family<List<ItemBaseModel>, String>((ref, query) async {
  final account =
      ref.watch(userProvider.select((user) => (user?.id, user?.credentials)));
  if (account.$1 == null || query.trim().isEmpty) return [];
  final response = await ref
      .read(jellyApiProvider)
      .itemsGet(
        searchTerm: query.trim(),
        recursive: true,
        includeItemTypes: [BaseItemKind.movie, BaseItemKind.series],
        limit: 24,
        enableUserData: true,
        fields: [ItemFields.overview],
      )
      .timeout(const Duration(seconds: 30));
  if (!response.isSuccessful) throw StateError('Recherche indisponible');
  return response.body?.items ?? <ItemBaseModel>[];
});
