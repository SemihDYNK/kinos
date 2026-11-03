import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinos/models/item_base_model.dart';

/// Registry bridge only: the inventory never observes the discovery computation.
final discoveryRegistryProvider =
    StateProvider.autoDispose.family<Map<Object, Set<String>>, String>(
  (ref, scope) => const {},
);

String? discoveryIdentityOf(ItemBaseModel item) {
  final id = item.overview.tmdbId;
  if (id == null || id.isEmpty) return null;
  if (item.type == KinosItemType.movie) return 'tmdb:movie:$id';
  if (item.type == KinosItemType.series) return 'tmdb:tv:$id';
  return null;
}
