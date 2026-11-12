import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kinos/jellyfin/jellyfin_open_api.enums.swagger.dart';
import 'package:kinos/letterboxd/friends/letterboxd_friends_parser.dart';
import 'package:kinos/letterboxd/friends/letterboxd_friends_providers.dart';
import 'package:kinos/letterboxd/letterboxd_providers.dart';
import 'package:kinos/models/item_base_model.dart';
import 'package:kinos/models/items/movie_model.dart';
import 'package:kinos/providers/api_provider.dart';
import 'package:kinos/providers/database_provider.dart';

import 'letterboxd_home.dart';

/// Un film d'une rangée Letterboxd et sa fiche Jellyfin s'il est dans la
/// bibliothèque.
typedef LetterboxdHomeEntry = ({LetterboxdFilmPage film, ItemBaseModel? item});

/// Les quatre rangées d'accueil nourries par Letterboxd.
class LetterboxdHomeRows {
  const LetterboxdHomeRows(
      {this.friends = const [],
      this.watchlistLibrary = const [],
      this.watchlistRequest = const [],
      this.top = const []});
  final List<LetterboxdHomeEntry> friends;
  final List<LetterboxdHomeEntry> watchlistLibrary;
  final List<LetterboxdHomeEntry> watchlistRequest;
  final List<LetterboxdHomeEntry> top;
}

final letterboxdHomeStoreProvider =
    Provider.autoDispose<LetterboxdHomeStore?>((ref) {
  final scope = ref.watch(letterboxdScopeProvider);
  return scope == null
      ? null
      : LetterboxdHomeStore(ref.watch(appDatabaseProvider), scope);
});

String? _tmdbOf(ItemBaseModel item) {
  final ids = item is MovieModel ? item.providerIds : null;
  if (ids == null) return null;
  for (final entry in ids.entries) {
    if (entry.key.toLowerCase() == 'tmdb') return '${entry.value}';
  }
  return null;
}

/// Films de la bibliothèque par identifiant TMDB, pour les années des
/// [films] (Jellyfin ne filtre pas par identifiant externe).
Future<Map<String, ItemBaseModel>> _libraryByTmdb(
    Ref ref, Iterable<LetterboxdFilmPage> films) async {
  final api = ref.read(jellyApiProvider);
  final years = films.map((f) => f.year).whereType<int>().toSet().toList()
    ..sort();
  final byTmdb = <String, ItemBaseModel>{};
  for (var i = 0; i < years.length; i += 8) {
    final response = await api
        .itemsGet(
          years: years.sublist(i, (i + 8).clamp(0, years.length)),
          includeItemTypes: [BaseItemKind.movie],
          recursive: true,
          enableUserData: true,
          fields: [ItemFields.providerids, ItemFields.overview],
        )
        .timeout(const Duration(seconds: 30));
    for (final item in response.body?.items ?? const <ItemBaseModel>[]) {
      if (_tmdbOf(item) case final id?) byTmdb[id] = item;
    }
  }
  return byTmdb;
}

/// Films vus d'après l'import Letterboxd : par identifiant TMDB quand
/// l'import l'a rapproché, sinon par titre et année. Lu avant toute
/// attente : relu dès que l'import est chargé.
bool Function(LetterboxdFilmPage) _seenFilter(Ref ref) {
  final records =
      ref.watch(letterboxdSnapshotProvider).valueOrNull?.records ?? const [];
  final seenTmdb = {
    for (final r in records)
      if (r.work?.tmdbId case final id?) '$id'
  };
  final seenTitles = {
    for (final r in records) (r.film.title.toLowerCase(), r.film.year)
  };
  return (film) =>
      seenTmdb.contains(film.tmdbId) ||
      seenTitles.contains((film.title.toLowerCase(), film.year));
}

/// Films seulement ; jamais un film déjà vu (Jellyfin ou import).
List<LetterboxdHomeEntry> _entries(
    Iterable<String> slugs,
    Map<String, LetterboxdFilmPage> films,
    Map<String, ItemBaseModel> library,
    bool Function(LetterboxdFilmPage) seen) {
  final result = <LetterboxdHomeEntry>[];
  for (final slug in slugs) {
    final film = films[slug];
    if (film == null || !film.isMovie || seen(film)) continue;
    final item = library[film.tmdbId];
    if (item?.userData.played ?? false) continue;
    result.add((film: film, item: item));
  }
  return result;
}

final letterboxdHomeRowsProvider =
    FutureProvider.autoDispose<LetterboxdHomeRows>((ref) async {
  final seen = _seenFilter(ref);
  final store = ref.watch(letterboxdHomeStoreProvider);
  final account = await ref.watch(letterboxdFriendsAccountProvider.future);
  if (store == null || account == null) return const LetterboxdHomeRows();
  final lists = await LetterboxdHomeRefresh(
          ref.read(letterboxdFriendsClientProvider), store)
      .cached();
  final films = await store.films(lists.shown);

  final library =
      await _libraryByTmdb(ref, films.values.where((film) => film.isMovie));
  ref.keepAlive();

  List<LetterboxdHomeEntry> entries(Iterable<String> slugs) =>
      _entries(slugs, films, library, seen);

  final watchlist = entries(lists.watchlist);
  return LetterboxdHomeRows(
    friends: entries(lists.friends),
    watchlistLibrary: [
      for (final e in watchlist)
        if (e.item != null) e
    ],
    watchlistRequest: [
      for (final e in watchlist)
        if (e.item == null) e
    ],
    top: entries(lists.top),
  );
});

final letterboxdHomeRefreshProvider =
    StateNotifierProvider.autoDispose<LetterboxdHomeRefreshController, bool>(
        (ref) {
  ref.keepAlive();
  return LetterboxdHomeRefreshController(ref);
});

/// Rafraîchit les listes en arrière-plan (chaque partie selon sa propre
/// fréquence) puis relit les rangées. État : vrai pendant le travail.
class LetterboxdHomeRefreshController extends StateNotifier<bool> {
  LetterboxdHomeRefreshController(this.ref) : super(false) {
    ref.listen(letterboxdScopeProvider, (previous, next) {
      if (previous != next) _generation++;
    });
  }
  final Ref ref;
  int _generation = 0;

  Future<void> ensure() async {
    if (state) return;
    final store = ref.read(letterboxdHomeStoreProvider);
    final account = await ref.read(letterboxdFriendsStoreProvider)?.account();
    if (store == null || account == null || !mounted) return;
    final generation = ++_generation;
    bool cancelled() => !mounted || generation != _generation;
    state = true;
    try {
      final index = await ref.read(letterboxdFriendsIndexProvider.future);
      await LetterboxdHomeRefresh(
              ref.read(letterboxdFriendsClientProvider), store)
          .run(account.username, friendsIndex: index, cancelled: cancelled);
    } catch (_) {
      // Rien à montrer : les rangées gardent ce qui est en cache.
    } finally {
      if (mounted) state = false;
      if (!cancelled()) ref.invalidate(letterboxdHomeRowsProvider);
    }
  }
}

/// Watchlist complète (page « tout voir ») : disponibles et à demander,
/// dans l'ordre de la watchlist, et le nombre de fiches encore à résoudre.
final letterboxdWatchlistProvider = FutureProvider.autoDispose<
    ({
      List<LetterboxdHomeEntry> library,
      List<LetterboxdHomeEntry> request,
      int pending
    })>((ref) async {
  final seen = _seenFilter(ref);
  ref.watch(letterboxdHomeRowsProvider);
  final store = ref.watch(letterboxdHomeStoreProvider);
  if (store == null) {
    return (
      library: <LetterboxdHomeEntry>[],
      request: <LetterboxdHomeEntry>[],
      pending: 0
    );
  }
  final slugs = (await store.list('watchlist')).slugs;
  final films = await store.films(slugs);
  var pending = 0;
  for (final slug in slugs) {
    if (!films.containsKey(slug) && await store.film(slug) == null) {
      pending++;
    }
  }
  final library =
      await _libraryByTmdb(ref, films.values.where((film) => film.isMovie));
  final all = _entries(slugs, films, library, seen);
  return (
    library: [
      for (final e in all)
        if (e.item != null) e
    ],
    request: [
      for (final e in all)
        if (e.item == null) e
    ],
    pending: pending,
  );
});
