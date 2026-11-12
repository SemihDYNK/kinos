import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinos/jellyfin/jellyfin_open_api.swagger.dart';
import 'package:kinos/models/item_base_model.dart';
import 'package:kinos/providers/api_provider.dart';
import 'package:kinos/providers/user_provider.dart';

/// One server-side random selection per session and active profile. Profile
/// information refreshes and returning home do not reshuffle the carousel.
final heroItemsProvider = FutureProvider<List<ItemBaseModel>>((ref) async {
  final connection = ref.watch(
      userProvider.select((account) => (account?.id, account?.credentials)));
  if (connection.$1 == null) return const [];
  final api = ref.read(jellyApiProvider);
  final response = await api
      .usersUserIdItemsGet(
        recursive: true,
        includeItemTypes: [BaseItemKind.movie],
        sortBy: [ItemSortBy.random],
        limit: 8,
        enableTotalRecordCount: false,
        enableUserData: true,
        enableImageTypes: [
          ImageType.backdrop,
          ImageType.primary,
          ImageType.logo
        ],
        fields: [
          ItemFields.overview,
          ItemFields.mediastreams,
          ItemFields.mediasources,
          // Identifiant TMDB : précharge les notes Letterboxd des amis.
          ItemFields.providerids,
        ],
      )
      .timeout(const Duration(seconds: 30));
  if (!response.isSuccessful) return const [];
  final seen = <String>{};
  return [
    for (final item in response.body?.items ?? <BaseItemDto>[])
      if (item.type == BaseItemKind.movie &&
          item.id != null &&
          seen.add(item.id!))
        ItemBaseModel.fromBaseDto(item, ref),
  ];
});
