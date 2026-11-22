import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import 'package:kinos/jellyfin/jellyfin_open_api.enums.swagger.dart';
import 'package:kinos/letterboxd/letterboxd_providers.dart'
    show letterboxdScopeProvider;
import 'package:kinos/models/item_base_model.dart';
import 'package:kinos/models/items/episode_model.dart';
import 'package:kinos/models/items/movie_model.dart';
import 'package:kinos/providers/api_provider.dart';
import 'package:kinos/providers/database_provider.dart';

import 'viewing_log.dart';

final _log = Logger('Viewing');

/// Le journal de visionnage du profil actif.
final viewingLogStoreProvider = Provider.autoDispose<ViewingLogStore?>((ref) {
  final scope = ref.watch(letterboxdScopeProvider);
  return scope == null
      ? null
      : ViewingLogStore(ref.watch(appDatabaseProvider),
          scope.replaceFirst('letterboxd:', 'kinos:'));
});

final viewingRecorderProvider =
    Provider<ViewingRecorder>((ref) => ViewingRecorder(ref));

/// Une séance plus courte n'est pas notée (un essai, une bande-annonce).
const minimumViewing = Duration(minutes: 2);

/// Part du titre au-delà de laquelle il compte comme vu en entier.
const completedFraction = .9;

/// Métadonnées d'un titre pour le journal, tirées de sa fiche Jellyfin.
({
  int? tmdbId,
  int? year,
  List<String> genres,
  List<String> directors,
  List<String> cast,
  List<String> studios,
}) viewingMetadata(ItemBaseModel item) {
  final overview = item.overview;
  return (
    tmdbId: int.tryParse(overview.tmdbId ?? ''),
    year: overview.yearAired,
    genres: [
      for (final g in overview.genreItems) g.name,
      if (overview.genreItems.isEmpty) ...overview.genres,
    ],
    directors: [for (final p in overview.directors) p.name],
    cast: [
      for (final p
          in overview.people.where((p) => p.type == PersonKind.actor).take(3))
        p.name
    ],
    studios: [for (final s in overview.studios) s.name],
  );
}

/// Note chaque lecture de Kinos dans le journal : son début, puis à son
/// arrêt, le temps regardé et le titre. Le mode incognito, déjà respecté en
/// amont, n'arrive jamais ici.
class ViewingRecorder {
  ViewingRecorder(this.ref);
  final Ref ref;

  final _sessions = <String, ({int startTicks, DateTime at})>{};

  void started(String? itemId, int positionTicks) {
    if (itemId == null) return;
    _sessions[itemId] = (startTicks: positionTicks, at: DateTime.now());
  }

  Future<void> stopped(String? itemId, int positionTicks) async {
    if (itemId == null) return;
    final session = _sessions.remove(itemId);
    if (session == null) return;
    try {
      await _record(itemId, session, positionTicks);
    } catch (error) {
      _log.warning('Séance non notée ($itemId) : $error');
    }
  }

  Future<void> _record(String itemId, ({int startTicks, DateTime at}) session,
      int positionTicks) async {
    final store = ref.read(viewingLogStoreProvider);
    if (store == null) return;
    // Le temps regardé : l'avance dans le titre, bornée par le temps écoulé
    // (un saut en avant ne compte pas comme regardé).
    final advanced =
        Duration(microseconds: (positionTicks - session.startTicks) ~/ 10);
    final elapsed = DateTime.now().difference(session.at);
    final watched = advanced < elapsed ? advanced : elapsed;
    if (watched < minimumViewing) return;
    final api = ref.read(jellyApiProvider);
    final item = (await api.usersUserIdItemsItemIdGet(itemId: itemId)).body;
    if (item is! MovieModel && item is! EpisodeModel) return;
    final runtime = item!.overview.runTime;
    final position = Duration(microseconds: positionTicks ~/ 10);
    final completed = item.userData.played ||
        (runtime != null &&
            runtime > Duration.zero &&
            position.inSeconds >= runtime.inSeconds * completedFraction);
    // Un épisode prend les genres et le casting de sa série.
    var meta = viewingMetadata(item);
    if (item is EpisodeModel && item.parentId != null) {
      final series =
          (await api.usersUserIdItemsItemIdGet(itemId: item.parentId)).body;
      if (series != null) {
        final s = viewingMetadata(series);
        meta = (
          tmdbId: s.tmdbId,
          year: meta.year ?? s.year,
          genres: s.genres,
          directors: meta.directors,
          cast: s.cast,
          studios: s.studios,
        );
      }
    }
    final movie = item is MovieModel;
    await store.add(ViewingEvent(
      identity: movie && meta.tmdbId != null
          ? 'tmdb:movie:${meta.tmdbId}'
          : 'jellyfin:${item.id}',
      kind: movie ? 'movie' : 'episode',
      title: item.name,
      seriesTitle: item is EpisodeModel ? item.seriesName : null,
      season: item is EpisodeModel ? item.season : null,
      episode: item is EpisodeModel ? item.episode : null,
      at: session.at,
      watchedSeconds: watched.inSeconds,
      runtimeSeconds: runtime?.inSeconds,
      completed: completed,
      sources: const {ViewingSource.kinos},
      jellyfinId: item.id,
      tmdbId: movie ? meta.tmdbId : null,
      year: meta.year,
      genres: meta.genres,
      directors: meta.directors,
      cast: meta.cast,
      studios: meta.studios,
    ));
  }
}
