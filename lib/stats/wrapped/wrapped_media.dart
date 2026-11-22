import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kinos/jellyfin/jellyfin_open_api.swagger.dart';
import 'package:kinos/models/item_base_model.dart';
import 'package:kinos/models/items/images_models.dart';
import 'package:kinos/providers/api_provider.dart';
import 'package:kinos/providers/theme/palette_service_provider.dart';
import 'package:kinos/upcoming/upcoming_models.dart' show tmdbImage;

import '../viewing_log.dart';
import 'wrapped_data.dart';
import 'wrapped_providers.dart';

/// L'affiche et l'image de fond d'un film du Wrapped.
typedef WrappedArt = ({ImageData? poster, ImageData? backdrop});

/// Les images des films d'une année, par identité du journal : Jellyfin
/// pour la bibliothèque, TMDB (par Seerr) pour le reste.
final wrappedArtProvider = FutureProvider.autoDispose
    .family<Map<String, WrappedArt>, int>((ref, year) async {
  final data = await ref.watch(wrappedDataProvider(year).future);
  final films = {for (final e in data.timeline) e.identity: e};
  final ids = {
    for (final e in films.values)
      if (e.jellyfinId case final id?) id
  }.toList();
  final api = ref.read(jellyApiProvider);
  final items = <String, ItemBaseModel>{};
  for (var i = 0; i < ids.length; i += 100) {
    final response = await api.usersUserIdItemsGet(
        ids: ids.sublist(i, (i + 100).clamp(0, ids.length)),
        enableUserData: false);
    for (final dto in response.body?.items ?? const <BaseItemDto>[]) {
      final item = ItemBaseModel.fromBaseDto(dto, ref);
      items[item.id] = item;
    }
  }
  ref.keepAlive();
  return {
    for (final e in films.values) e.identity: _artOf(e, items, data),
  };
});

WrappedArt _artOf(
    ViewingEvent e, Map<String, ItemBaseModel> items, WrappedData data) {
  final item = items[e.jellyfinId];
  final fact = e.tmdbId == null ? null : data.facts[e.tmdbId];
  ImageData? tmdb(String? path, String size) => path == null
      ? null
      : ImageData(
          path: tmdbImage(path, size: size), key: 'wrapped:$size:$path');
  return (
    poster: item?.images?.primary ?? tmdb(fact?.poster, 'w342'),
    backdrop: item?.images?.backDrop?.firstOrNull ??
        tmdb(fact?.backdrop, 'w1280') ??
        item?.images?.primary,
  );
}

/// La teinte dominante de chaque film d'une année (son image de fond),
/// extraite une fois puis gardée en cache par le service des palettes.
final wrappedTintsProvider = FutureProvider.autoDispose
    .family<Map<String, Color>, int>((ref, year) async {
  final art = await ref.watch(wrappedArtProvider(year).future);
  final service = ref.read(paletteServiceProvider);
  final tints = <String, Color>{};
  final queue = art.entries
      .where((e) => (e.value.backdrop ?? e.value.poster) != null)
      .toList();
  // Quatre à la fois : le décodage des images reste discret.
  Future<void> worker() async {
    while (queue.isNotEmpty) {
      final e = queue.removeLast();
      final image = (e.value.backdrop ?? e.value.poster)!;
      final palette =
          await service.forItem(itemId: e.key, image: image.imageProvider);
      if (!palette.isFallback) tints[e.key] = palette.tint;
    }
  }

  await Future.wait([for (var i = 0; i < 4; i++) worker()]);
  ref.keepAlive();
  return tints;
});
