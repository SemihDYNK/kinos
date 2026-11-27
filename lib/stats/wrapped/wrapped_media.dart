import 'dart:async';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kinos/jellyfin/jellyfin_open_api.swagger.dart';
import 'package:kinos/models/item_base_model.dart';
import 'package:kinos/models/items/images_models.dart';
import 'package:kinos/providers/api_provider.dart';
import 'package:kinos/providers/theme/palette_service_provider.dart';
import 'package:kinos/recommendations/providers/recommendation_providers.dart';
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
  // Les séries : l'épisode donne sa série, la série ses images.
  final episodes = [
    for (final s in data.allSeries.take(_maxSeries))
      if (s.episodes.firstWhere((e) => e.jellyfinId != null,
              orElse: () => s.episodes.first)
          case final e when e.jellyfinId != null)
        (s.name, e.jellyfinId!)
  ];
  final seriesArt = <String, WrappedArt>{};
  if (episodes.isNotEmpty) {
    final episodeItems = await api.usersUserIdItemsGet(
        ids: [for (final e in episodes) e.$2], enableUserData: false);
    final seriesOf = {
      for (final dto in episodeItems.body?.items ?? const <BaseItemDto>[])
        if (dto.seriesId != null) dto.id: dto.seriesId!
    };
    final ids = seriesOf.values.toSet().toList();
    if (ids.isNotEmpty) {
      final shows =
          await api.usersUserIdItemsGet(ids: ids, enableUserData: false);
      final byId = {
        for (final dto in shows.body?.items ?? const <BaseItemDto>[])
          dto.id: ItemBaseModel.fromBaseDto(dto, ref)
      };
      for (final (name, episode) in episodes) {
        final show = byId[seriesOf[episode]];
        if (show == null) continue;
        seriesArt['series:$name'] = (
          poster: show.images?.primary,
          backdrop: show.images?.backDrop?.firstOrNull ?? show.images?.primary,
        );
      }
    }
  }
  ref.keepAlive();
  return {
    for (final e in films.values) e.identity: _artOf(e, items, data),
    ...seriesArt,
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

/// Séries cherchées au plus pour les images et les séries terminées.
const _maxSeries = 40;

/// Une série terminée cette année.
typedef WrappedFinished = ({String name, int episodes});

/// Les séries finies cette année : tous leurs épisodes (hors spéciaux) vus
/// dans Jellyfin, dont au moins un cette année. Le journal ne connaît pas
/// le nombre total d'épisodes : on le demande à Jellyfin.
final wrappedFinishedProvider = FutureProvider.autoDispose
    .family<List<WrappedFinished>, int>((ref, year) async {
  final data = await ref.watch(wrappedDataProvider(year).future);
  final api = ref.read(jellyApiProvider);
  final firstEpisode = <String, String>{
    for (final s in data.allSeries.take(_maxSeries))
      if (s.episodes.firstWhere((e) => e.jellyfinId != null,
              orElse: () => s.episodes.first)
          case final e when e.jellyfinId != null)
        e.jellyfinId!: s.name
  };
  if (firstEpisode.isEmpty) return const [];
  final episodeItems = await api.usersUserIdItemsGet(
      ids: firstEpisode.keys.toList(), enableUserData: false);
  final seriesOf = <String, String>{
    for (final dto in episodeItems.body?.items ?? const <BaseItemDto>[])
      if (dto.seriesId != null && firstEpisode[dto.id] != null)
        dto.seriesId!: firstEpisode[dto.id]!
  };
  final finished = <WrappedFinished>[];
  for (final entry in seriesOf.entries) {
    final response = await api.usersUserIdItemsGet(
        parentId: entry.key,
        recursive: true,
        includeItemTypes: const [BaseItemKind.episode],
        enableUserData: true,
        enableImages: false);
    final episodes = [
      for (final dto in response.body?.items ?? const <BaseItemDto>[])
        if ((dto.parentIndexNumber ?? 1) > 0) dto
    ];
    if (episodes.isEmpty) continue;
    if (episodes.every((dto) => dto.userData?.played == true)) {
      finished.add((name: entry.value, episodes: episodes.length));
    }
  }
  ref.keepAlive();
  return finished..sort((a, b) => b.episodes.compareTo(a.episodes));
});

/// Un titre conseillé pour l'an prochain.
typedef WrappedPick = ({String title, int? year, ImageData? poster});

/// Trois films de la bibliothèque, pas encore vus, que le moteur de goûts
/// recommande : la diapo « Pour l'an prochain ». Seulement pour l'année en
/// cours (une année passée n'a pas d'« an prochain » à proposer).
final wrappedNextYearProvider = FutureProvider.autoDispose
    .family<List<WrappedPick>, int>((ref, year) async {
  if (year != DateTime.now().year) return const [];
  final result = await ref.watch(recommendationResultProvider.future);
  final picks = <WrappedPick>[];
  for (final scored in result.candidates) {
    final item = result.jellyfinItemsById[scored.item.id];
    if (item == null || item.type != KinosItemType.movie) continue;
    picks.add((
      title: item.name,
      year: item.overview.yearAired,
      poster: item.getPosters?.primary,
    ));
    if (picks.length == 3) break;
  }
  return picks;
});

/// La teinte dominante de chaque film d'une année, publiée au fil de
/// l'extraction : les titres des grandes diapos d'abord (film et série de
/// l'année, dauphins), puis le reste. Les teintes déjà en cache arrivent
/// tout de suite ; sur une connexion lente, le Wrapped n'attend pas les
/// centaines d'images de l'année pour se colorer.
final wrappedTintsProvider =
    StreamProvider.autoDispose.family<Map<String, Color>, int>((ref, year) {
  final dataFuture = ref.watch(wrappedDataProvider(year).future);
  final artFuture = ref.watch(wrappedArtProvider(year).future);
  final service = ref.read(paletteServiceProvider);
  final controller = StreamController<Map<String, Color>>();
  var disposed = false;
  ref.onDispose(() {
    disposed = true;
    controller.close();
  });

  Future<void> run() async {
    final data = await dataFuture;
    final art = await artFuture;
    final queue = wrappedTintOrder(data, art);
    final tints = <String, Color>{};
    var published = 0;
    final clock = Stopwatch()..start();
    void publish() {
      if (disposed || tints.length == published) return;
      published = tints.length;
      clock.reset();
      controller.add(Map.unmodifiable(tints));
    }

    // Quatre à la fois : le décodage des images reste discret.
    Future<void> worker() async {
      while (queue.isNotEmpty && !disposed) {
        final key = queue.removeAt(0);
        final source = art[key]!.backdrop ?? art[key]!.poster!;
        final palette = await service.forItem(
            itemId: key, image: paletteSource(source).imageProvider);
        if (!palette.isFallback) tints[key] = palette.tint;
        if (clock.elapsedMilliseconds > 400) publish();
      }
    }

    await Future.wait([for (var i = 0; i < 4; i++) worker()]);
    publish();
    if (!disposed) ref.keepAlive();
  }

  run().catchError((Object error, StackTrace stack) {
    if (!disposed) controller.addError(error, stack);
  });
  return controller.stream;
});

/// L'ordre d'extraction des teintes : celles que les grandes diapos
/// montrent en premier.
List<String> wrappedTintOrder(WrappedData data, Map<String, WrappedArt> art) {
  final first = [
    if (data.filmOfYear case final best?) best.event.identity,
    for (final r in data.runnersUp) r.event.identity,
    for (final s in data.series) 'series:${s.name}',
  ];
  final order = <String>{
    ...first,
    for (final e in data.timeline.reversed) e.identity,
    ...art.keys,
  };
  return [
    for (final key in order)
      if (art[key] case final a? when (a.backdrop ?? a.poster) != null) key
  ];
}

/// Une version légère de [image] pour en extraire la teinte : l'analyse
/// la réduit de toute façon à 100×150, inutile de télécharger l'image
/// pleine taille.
ImageData paletteSource(ImageData image) {
  final uri = Uri.tryParse(image.path);
  if (uri == null || !uri.hasScheme) return image;
  Uri? light;
  if (uri.host == 'image.tmdb.org') {
    final segments = [
      for (final s in uri.pathSegments)
        RegExp(r'^(w\d+|original)$').hasMatch(s) ? 'w300' : s
    ];
    light = uri.replace(pathSegments: segments);
  } else {
    final query = Map.of(uri.queryParameters);
    var changed = false;
    for (final (key, size) in const [
      ('fillWidth', '320'),
      ('fillHeight', '180'),
      ('maxWidth', '300'),
      ('maxHeight', '300'),
    ]) {
      if (query.containsKey(key)) {
        query[key] = size;
        changed = true;
      }
    }
    if (changed) light = uri.replace(queryParameters: query);
  }
  if (light == null) return image;
  return ImageData(path: light.toString(), key: '${image.key}:palette');
}
