import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kinos/jellyfin/jellyfin_open_api.enums.swagger.dart';
import 'package:kinos/letterboxd/friends/letterboxd_friends_parser.dart';
import 'package:kinos/letterboxd/friends/letterboxd_friends_providers.dart';
import 'package:kinos/letterboxd/letterboxd_providers.dart';
import 'package:kinos/models/item_base_model.dart';
import 'package:kinos/models/items/movie_model.dart';
import 'package:kinos/providers/api_provider.dart';
import 'package:kinos/providers/database_provider.dart';

import 'letterboxd_genres.dart';
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

/// Graine propre à un libellé, identique d'un lancement à l'autre (le
/// `hashCode` des chaînes n'est pas garanti stable).
int _stableSalt(String label) =>
    label.codeUnits.fold<int>(0, (sum, unit) => (sum * 31 + unit) & 0xffff);

/// Rangées Letterboxd d'une page de genre (libellé affiché du genre) :
/// conseils des amis, watchlist (disponible / à demander) et Top 500 dans
/// ce genre. Vide sans compte relié ni genre connu de Letterboxd. Les
/// lectures passent devant la synchronisation de fond : la page attend ses
/// propres rangées, pas les 3 000 notes d'amis.
final letterboxdGenreRowsProvider = FutureProvider.autoDispose
    .family<LetterboxdHomeRows, String>((ref, label) async {
  final seen = _seenFilter(ref);
  var disposed = false;
  ref.onDispose(() => disposed = true);
  bool cancelled() => disposed;
  final store = ref.watch(letterboxdHomeStoreProvider);
  final account = await ref.watch(letterboxdFriendsAccountProvider.future);
  final genre = letterboxdGenreSlug(label);
  if (store == null || account == null || genre == null) {
    return const LetterboxdHomeRows();
  }
  final index = await ref.watch(letterboxdFriendsIndexProvider.future);
  final refresh =
      LetterboxdHomeRefresh(ref.read(letterboxdFriendsClientProvider), store);
  final watched = (await store.list('watched')).slugs.toSet();
  final now = refresh.now;

  final results = await Future.wait([
    refresh.watchlistInGenre(account.username, genre, cancelled: cancelled),
    refresh.topInGenre(genre, cancelled: cancelled),
  ]);
  final watchlistPick = rotationPick(results[0], now,
      count: genreRowCount, salt: 2 + _stableSalt(label));
  final topPick = dailyPick(results[1], watched, now, count: genreRowCount);

  // Conseils d'amis : le réservoir dont on connaît déjà les genres.
  final candidates = <String>[];
  for (final slug in friendPicks(index, watched, limit: friendGenrePoolSize)) {
    final film = (await store.film(slug))?.film;
    if (film != null && filmInGenre(film, label)) candidates.add(slug);
  }
  final friendsPick = weightedRotationPick(candidates, now,
      count: genreRowCount, salt: 1 + _stableSalt(label));

  await refresh
      .resolve([...watchlistPick, ...topPick], cancelled, urgent: true);
  if (cancelled()) return const LetterboxdHomeRows();
  final films =
      await store.films([...watchlistPick, ...topPick, ...friendsPick]);
  final library =
      await _libraryByTmdb(ref, films.values.where((film) => film.isMovie));
  List<LetterboxdHomeEntry> entries(Iterable<String> slugs) =>
      _entries(slugs, films, library, seen);
  final watchlist = entries(watchlistPick);
  return LetterboxdHomeRows(
    friends: entries(friendsPick),
    watchlistLibrary: [
      for (final e in watchlist)
        if (e.item != null) e
    ],
    watchlistRequest: [
      for (final e in watchlist)
        if (e.item == null) e
    ],
    top: entries(topPick),
  );
});
