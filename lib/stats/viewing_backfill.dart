import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import 'package:kinos/jellyfin/jellyfin_open_api.swagger.dart';
import 'package:kinos/letterboxd/letterboxd_model.dart';
import 'package:kinos/letterboxd/letterboxd_providers.dart';
import 'package:kinos/letterboxd/letterboxd_store.dart';
import 'package:kinos/models/item_base_model.dart';
import 'package:kinos/models/items/episode_model.dart';
import 'package:kinos/models/items/movie_model.dart';
import 'package:kinos/providers/api_provider.dart';
import 'package:kinos/providers/database_provider.dart';
import 'package:kinos/recommendations/models/trait.dart';

import 'package:kinos/ratings/kinos_ratings.dart';

import 'viewing_log.dart';
import 'viewing_recorder.dart';

final _log = Logger('Viewing');

/// « science fiction » → « Science Fiction » : les traits Letterboxd sont
/// normalisés en minuscules, l'affichage reprend des majuscules.
String _display(String value) => value
    .split(' ')
    .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
    .join(' ');

List<String> _traits(LetterboxdWork? work, TraitKind kind, [int? take]) {
  final values = [
    for (final t in work?.traits ?? const <TraitKey>[])
      if (t.kind == kind) _display(t.value)
  ];
  return take == null ? values : values.take(take).toList();
}

/// Les séances du journal Letterboxd : une par date du journal (les films
/// sans date ne vont pas dans la frise). [library] donne les métadonnées
/// Jellyfin des films de la bibliothèque, plus justes que les traits.
List<ViewingEvent> letterboxdViewings(LetterboxdSnapshot snapshot,
    {Map<String, ItemBaseModel> library = const {}}) {
  final events = <ViewingEvent>[];
  for (final record in snapshot.records) {
    final film = record.film;
    final work = record.work;
    final item = work?.jellyfinId == null ? null : library[work!.jellyfinId];
    final meta = item == null ? null : viewingMetadata(item);
    final tmdb = work?.tmdbId ?? meta?.tmdbId;
    final slug = Uri.parse(film.uri).pathSegments.where((s) => s.isNotEmpty);
    final identity = tmdb != null
        ? 'tmdb:movie:$tmdb'
        : work?.jellyfinId != null
            ? 'jellyfin:${work!.jellyfinId}'
            : 'letterboxd:${slug.isEmpty ? film.uri : slug.last}';
    final runtime = item?.overview.runTime?.inSeconds;
    // Un import antérieur aux dates du journal n'a que la dernière séance.
    final dates = film.viewings.isNotEmpty
        ? film.viewings
        : [if (film.watchedAt case final at?) at];
    for (final (index, date) in dates.indexed) {
      events.add(ViewingEvent(
        identity: identity,
        kind: 'movie',
        title: item?.name ?? film.title,
        at: DateTime(date.year, date.month, date.day),
        runtimeSeconds: runtime,
        sources: const {ViewingSource.letterboxd},
        jellyfinId: work?.jellyfinId,
        tmdbId: tmdb,
        year: film.year ?? meta?.year,
        genres: meta?.genres ?? _traits(work, TraitKind.genre),
        directors: meta?.directors ?? _traits(work, TraitKind.director),
        cast: meta?.cast ?? _traits(work, TraitKind.actor, 3),
        studios: meta?.studios ?? _traits(work, TraitKind.studio),
        rewatch: index > 0,
      ));
    }
  }
  return events;
}

/// Les séances déduites de Jellyfin : sa dernière date de lecture, pour ce
/// qui est vu (un film, un épisode).
List<ViewingEvent> jellyfinViewings(Iterable<ItemBaseModel> items) => [
      for (final item in items)
        if (item.userData.played && item.userData.lastPlayed != null)
          if (item is MovieModel || item is EpisodeModel)
            _jellyfinEvent(item, item.userData.lastPlayed!.toLocal()),
    ];

ViewingEvent _jellyfinEvent(ItemBaseModel item, DateTime at) {
  final meta = viewingMetadata(item);
  final movie = item is MovieModel;
  return ViewingEvent(
    identity: movie && meta.tmdbId != null
        ? 'tmdb:movie:${meta.tmdbId}'
        : 'jellyfin:${item.id}',
    kind: movie ? 'movie' : 'episode',
    title: item.name,
    seriesTitle: item is EpisodeModel ? item.seriesName : null,
    season: item is EpisodeModel ? item.season : null,
    episode: item is EpisodeModel ? item.episode : null,
    at: at,
    runtimeSeconds: item.overview.runTime?.inSeconds,
    sources: const {ViewingSource.jellyfin},
    jellyfinId: item.id,
    tmdbId: movie ? meta.tmdbId : null,
    year: meta.year,
    genres: meta.genres,
    directors: meta.directors,
    cast: meta.cast,
    studios: meta.studios,
  );
}

/// Écarte une séance Jellyfin quand la même œuvre a déjà une séance à un
/// jour près (Letterboxd, Kinos) : sa « dernière lecture » la décrit déjà,
/// à un fuseau ou une heure tardive près.
List<ViewingEvent> withoutNearDuplicates(
    List<ViewingEvent> candidates, List<ViewingEvent> known) {
  final days = <String, List<DateTime>>{};
  for (final e in known) {
    if (e.sources.length == 1 && e.sources.contains(ViewingSource.jellyfin)) {
      continue;
    }
    (days[e.identity] ??= []).add(DateTime(e.at.year, e.at.month, e.at.day));
  }
  return [
    for (final e in candidates)
      if (!(days[e.identity] ?? const <DateTime>[]).any((d) =>
          DateTime(e.at.year, e.at.month, e.at.day)
              .difference(d)
              .inDays
              .abs() <=
          1))
        e
  ];
}

final viewingBackfillProvider =
    Provider<ViewingBackfill>((ref) => ViewingBackfill(ref));

/// Remplit le journal avec le passé : Letterboxd (chaque date du journal)
/// et Jellyfin (dernière lecture de ce qui est vu).
class ViewingBackfill {
  ViewingBackfill(this.ref);
  final Ref ref;
  bool _running = false;

  static const _fields = [
    ItemFields.genres,
    ItemFields.people,
    ItemFields.studios,
    ItemFields.providerids,
  ];

  Future<List<ItemBaseModel>> _items(
      {List<String>? ids,
      required List<BaseItemKind> kinds,
      bool played = false,
      bool details = true}) async {
    final response = await ref.read(jellyApiProvider).usersUserIdItemsGet(
        ids: ids,
        recursive: true,
        isPlayed: played ? true : null,
        includeItemTypes: kinds,
        fields: details ? _fields : const [ItemFields.providerids],
        enableImages: false,
        enableUserData: true);
    return [
      for (final dto in response.body?.items ?? const <BaseItemDto>[])
        ItemBaseModel.fromBaseDto(dto, ref)
    ];
  }

  /// Relit tout : les séances Letterboxd et Jellyfin sont remplacées, celles
  /// de Kinos gardées.
  Future<void> rebuild() async {
    if (_running) return;
    final store = ref.read(viewingLogStoreProvider);
    final scope = ref.read(letterboxdScopeProvider);
    if (store == null || scope == null) return;
    _running = true;
    try {
      final snapshot =
          await LetterboxdStore(ref.read(appDatabaseProvider), scope).read();
      // Les notes Letterboxd deviennent des notes Kinos (jamais par-dessus
      // une note donnée dans Kinos).
      await ref
          .read(kinosRatingsProvider.notifier)
          .seed(letterboxdRatings(snapshot));
      final ids = {
        for (final r in snapshot.records)
          if (r.work?.jellyfinId case final id?) id
      }.toList();
      final library = <String, ItemBaseModel>{};
      for (var i = 0; i < ids.length; i += 100) {
        for (final item in await _items(
            ids: ids.sublist(i, (i + 100).clamp(0, ids.length)),
            kinds: const [BaseItemKind.movie])) {
          library[item.id] = item;
        }
      }
      final played = [
        ...await _items(kinds: const [BaseItemKind.movie], played: true),
        // Les épisodes sans le casting : il viendrait par milliers.
        ...await _items(
            kinds: const [BaseItemKind.episode], played: true, details: false),
      ];
      final letterboxd = letterboxdViewings(snapshot, library: library);
      await store.removeSource(ViewingSource.letterboxd);
      await store.removeSource(ViewingSource.jellyfin);
      await store.addAll([
        ...letterboxd,
        ...withoutNearDuplicates(
            jellyfinViewings(played), [...letterboxd, ...await store.all()]),
      ]);
    } catch (error) {
      _log.warning('Journal de visionnage non rempli : $error');
    } finally {
      _running = false;
    }
  }
}
