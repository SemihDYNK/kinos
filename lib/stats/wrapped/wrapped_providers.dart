import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kinos/letterboxd/friends/letterboxd_friends_client.dart'
    show LetterboxdPaused;
import 'package:kinos/letterboxd/friends/letterboxd_friends_providers.dart';
import 'package:kinos/letterboxd/letterboxd_model.dart';
import 'package:kinos/letterboxd/letterboxd_providers.dart';
import 'package:kinos/letterboxd/letterboxd_store.dart';
import 'package:kinos/providers/database_provider.dart';
import 'package:kinos/ratings/kinos_ratings.dart';

import '../stats_screen.dart' show viewingEventsProvider;
import '../viewing_log.dart';
import 'film_facts.dart';
import 'wrapped_data.dart';

/// Le slug Letterboxd d'une adresse de film (« letterboxd.com/film/dune/ »),
/// null pour un lien court (boxd.it) ou une autre adresse.
String? letterboxdSlugOf(String uri) {
  final segments =
      Uri.tryParse(uri)?.pathSegments.where((s) => s.isNotEmpty).toList();
  if (segments == null || segments.length < 2) return null;
  final film = segments.indexOf('film');
  return film >= 0 && film + 1 < segments.length ? segments[film + 1] : null;
}

/// Le slug Letterboxd de chaque film de [events] : le journal lui-même
/// (`letterboxd:<slug>`), l'import (adresse du film), puis les slugs déjà
/// résolus pour les notes des amis. Aucune requête.
Map<String, String> wrappedSlugs(List<ViewingEvent> events,
    {LetterboxdSnapshot? snapshot, Map<int, String> resolved = const {}}) {
  final byTmdb = <int, String>{...resolved};
  for (final record in snapshot?.records ?? const <LetterboxdRecord>[]) {
    final slug = letterboxdSlugOf(record.film.uri);
    final tmdb = record.work?.tmdbId;
    if (slug != null && tmdb != null) byTmdb[tmdb] = slug;
  }
  return {
    for (final e in events)
      if (e.identity.startsWith('letterboxd:'))
        e.identity: e.identity.substring('letterboxd:'.length)
      else if (e.tmdbId != null && byTmdb[e.tmdbId] != null)
        e.identity: byTmdb[e.tmdbId]!
  };
}

/// Le Wrapped d'une année : le journal, vos notes, les faits du public
/// (TMDB par Seerr, en cache) et les notes de vos amis Letterboxd.
final wrappedDataProvider =
    FutureProvider.autoDispose.family<WrappedData, int>((ref, year) async {
  // Tout ce qu'on surveille, avant la première attente.
  final ratings = ref.watch(kinosRatingsProvider);
  final store = ref.watch(letterboxdFriendsStoreProvider);
  final scope = ref.watch(letterboxdScopeProvider);
  final db = ref.watch(appDatabaseProvider);
  final eventsFuture = ref.watch(viewingEventsProvider.future);
  final friendsFuture = ref.watch(letterboxdFriendsIndexProvider.future);

  final events = await eventsFuture;
  final ids = {
    for (final e in events)
      if (e.isMovie && e.at.year == year && e.tmdbId != null) e.tmdbId!
  }.toList()
    ..sort();
  final facts = await ref.watch(filmFactsProvider(ids.join(',')).future);
  final friends = await friendsFuture;
  final snapshot =
      scope == null ? null : await LetterboxdStore(db, scope).read();
  final slugs = wrappedSlugs(events,
      snapshot: snapshot, resolved: await store?.slugs() ?? const {});
  return computeWrapped(events, ratings, year,
      facts: facts, friends: friends, slugs: slugs);
});

/// Au plus tant d'adresses Letterboxd demandées par préparation, une
/// toutes les [_slugSpacing] : le site n'aime pas les rafales.
const _slugBatch = 40;
const _slugSpacing = Duration(seconds: 2);

/// Demande à Letterboxd l'adresse des films notés de [year] qu'on ne
/// connaît pas encore, pour comparer vos notes à celles de vos amis. En
/// arrière-plan, lentement ; s'arrête à la première pause demandée par le
/// site. Rend le nombre d'adresses trouvées.
Future<int> resolveWrappedSlugs(WidgetRef ref, int year) async {
  final store = ref.read(letterboxdFriendsStoreProvider);
  final scope = ref.read(letterboxdScopeProvider);
  if (store == null || scope == null || await store.account() == null) {
    return 0;
  }
  final ratings = ref.read(kinosRatingsProvider);
  final events = await ref.read(viewingEventsProvider.future);
  final snapshot =
      await LetterboxdStore(ref.read(appDatabaseProvider), scope).read();
  final known =
      wrappedSlugs(events, snapshot: snapshot, resolved: await store.slugs());
  final wanted = <int>{
    for (final e in events)
      if (e.isMovie &&
          e.at.year == year &&
          e.tmdbId != null &&
          !known.containsKey(e.identity) &&
          (ratings[e.identity] ?? ratings['jellyfin:${e.jellyfinId}']) != null)
        e.tmdbId!
  };
  final client = ref.read(letterboxdFriendsClientProvider);
  var found = 0;
  for (final tmdb in wanted.take(_slugBatch)) {
    // Déjà demandé (même sans réponse) : on ne redemande pas.
    if (await store.slug('$tmdb', maxAge: const Duration(days: 30)) != null) {
      continue;
    }
    await Future<void>.delayed(_slugSpacing);
    try {
      final slug = await client.filmSlug('$tmdb');
      await store.saveSlug('$tmdb', slug);
      if (slug != null) found++;
    } on LetterboxdPaused {
      break;
    } catch (_) {
      continue;
    }
  }
  return found;
}
