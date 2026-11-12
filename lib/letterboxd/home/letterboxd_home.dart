import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'package:kinos/letterboxd/friends/letterboxd_friends_client.dart';
import 'package:kinos/letterboxd/friends/letterboxd_friends_parser.dart';
import 'package:kinos/letterboxd/friends/letterboxd_friends_store.dart';
import 'package:kinos/models/syncing/database_item.dart';

/// Rangées d'accueil nourries par Letterboxd : conseils des amis, watchlist
/// et tirage du Top 500 officiel. Les listes viennent des pages publiques,
/// les fiches sont mises en cache pour toujours (un film ne change pas
/// d'identifiant TMDB).
const top500Path = 'official/list/letterboxds-top-500-films/';

/// Note sur 10 à partir de laquelle un ami « conseille » un film (4 étoiles).
const friendRecommendThreshold = 8;

/// Réservoir des meilleurs conseils d'amis, dans lequel la rangée tire.
const friendPoolSize = 40;

/// Films tirés pour chaque rangée : de quoi remplir une ligne même après
/// avoir écarté les films déjà vus (Jellyfin, import Letterboxd).
const friendDrawCount = 16;
const watchlistDrawCount = 30;
const topDailyCount = 10;

/// Fiches de la watchlist complète résolues par passage, après celles
/// des rangées (page « tout voir »).
const watchlistResolvePerRun = 120;

/// Les conseils des amis et la watchlist changent tous les 3 jours.
const rotationPeriod = Duration(days: 3);

/// Les slugs que l'accueil affiche, avant résolution des fiches.
class LetterboxdHomeLists {
  const LetterboxdHomeLists(
      {this.friends = const [],
      this.watchlist = const [],
      this.top = const [],
      this.watched = const {}});
  final List<String> friends;
  final List<String> watchlist;
  final List<String> top;
  final Set<String> watched;

  Iterable<String> get shown => {...friends, ...watchlist, ...top};
}

/// Numéro de la période de [period] contenant [now] : le même tirage pour
/// toute la période, un autre à la suivante.
int rotationIndex(DateTime now, Duration period) =>
    DateTime.utc(now.year, now.month, now.day)
        .difference(DateTime.utc(2026))
        .inDays ~/
    period.inDays;

/// Tirage uniforme de [count] éléments, stable sur la période.
List<String> rotationPick(List<String> slugs, DateTime now,
    {required int count, required int salt, Duration period = rotationPeriod}) {
  final pool = [...slugs]
    ..shuffle(Random(rotationIndex(now, period) * 7919 + salt));
  return pool.take(count).toList();
}

/// Tirage pondéré sans remise dans un réservoir déjà classé : les premiers
/// ont plus de chances, sans que la rangée soit toujours la même.
List<String> weightedRotationPick(List<String> ranked, DateTime now,
    {required int count, required int salt, Duration period = rotationPeriod}) {
  final random = Random(rotationIndex(now, period) * 7919 + salt);
  final pool = [
    for (final (i, slug) in ranked.indexed) (slug, ranked.length - i)
  ];
  final picked = <String>[];
  while (picked.length < count && pool.isNotEmpty) {
    final total = pool.fold<int>(0, (sum, e) => sum + e.$2);
    var target = random.nextInt(total);
    var index = 0;
    while (target >= pool[index].$2) {
      target -= pool[index].$2;
      index++;
    }
    picked.add(pool.removeAt(index).$1);
  }
  return picked;
}

const _friendsSalt = 1, _watchlistSalt = 2;

/// Films conseillés par les amis : au moins une note de 4 étoiles, classés
/// par nombre d'amis enthousiastes puis par moyenne ; jamais un film déjà
/// vu.
List<String> friendPicks(
    Map<String, List<FriendRating>> index, Set<String> watched,
    {int limit = friendPoolSize}) {
  final scored = <(String, int, double)>[];
  for (final MapEntry(key: slug, value: ratings) in index.entries) {
    if (watched.contains(slug)) continue;
    final fans =
        ratings.where((r) => r.rating >= friendRecommendThreshold).length;
    if (fans == 0) continue;
    final average =
        ratings.map((r) => r.rating).reduce((a, b) => a + b) / ratings.length;
    scored.add((slug, fans, average));
  }
  scored.sort(
      (a, b) => b.$2 != a.$2 ? b.$2.compareTo(a.$2) : b.$3.compareTo(a.$3));
  return [for (final s in scored.take(limit)) s.$1];
}

/// Tirage du jour : le même toute la journée, un autre le lendemain.
List<String> dailyPick(List<String> slugs, Set<String> watched, DateTime day,
    {int count = topDailyCount}) {
  final pool = slugs.where((s) => !watched.contains(s)).toList();
  pool.shuffle(Random(day.year * 10000 + day.month * 100 + day.day));
  return pool.take(count).toList();
}

typedef StoredSlugList = ({List<String> slugs, DateTime? at, DateTime? fullAt});

/// Persistance dans `Settings`, une portée par profil Kinos.
class LetterboxdHomeStore {
  LetterboxdHomeStore(this.db, String profileScope)
      : scope = '$profileScope:home:v1';
  final AppDatabase db;
  final String scope;

  Future<Object?> _json(String key) async {
    final row = await db.getSetting(key, scope: scope);
    if (row == null) return null;
    try {
      return jsonDecode(row.value);
    } on FormatException {
      return null;
    }
  }

  Future<void> _put(String key, Object value) =>
      db.setSetting(key, jsonEncode(value), scope: scope);

  static DateTime? _date(Object? value) =>
      value is int ? DateTime.fromMillisecondsSinceEpoch(value) : null;

  Future<StoredSlugList> list(String name) async {
    final json = await _json('list:$name');
    if (json is! Map || json['s'] is! List) {
      return (slugs: const <String>[], at: null, fullAt: null);
    }
    return (
      slugs: (json['s'] as List).whereType<String>().toList(),
      at: _date(json['t']),
      fullAt: _date(json['f']),
    );
  }

  Future<void> saveList(String name, List<String> slugs,
          {required DateTime at, DateTime? fullAt}) =>
      _put('list:$name', {
        's': slugs,
        't': at.millisecondsSinceEpoch,
        if (fullAt != null) 'f': fullAt.millisecondsSinceEpoch,
      });

  /// Fiche en cache : `(film: null)` si Letterboxd n'a pas de fiche TMDB
  /// pour ce slug, null si jamais demandée.
  Future<({LetterboxdFilmPage? film})?> film(String slug) async {
    final json = await _json('film:$slug');
    if (json == null) return null;
    return (film: LetterboxdFilmPage.fromJson(json));
  }

  Future<void> saveFilm(String slug, LetterboxdFilmPage? film) =>
      _put('film:$slug', film?.toJson() ?? {'none': true});

  Future<Map<String, LetterboxdFilmPage>> films(Iterable<String> slugs) async {
    final films = <String, LetterboxdFilmPage>{};
    for (final slug in slugs) {
      if ((await film(slug))?.film case final film?) films[slug] = film;
    }
    return films;
  }
}

/// Durées de rafraîchissement.
class LetterboxdHomeSchedule {
  const LetterboxdHomeSchedule(
      {this.daily = const Duration(hours: 20),
      this.weekly = const Duration(days: 7)});
  final Duration daily;
  final Duration weekly;
}

/// Met à jour les listes et résout les fiches à afficher. Chaque partie
/// est indépendante : une erreur réseau sur l'une garde le cache des
/// autres.
class LetterboxdHomeRefresh {
  LetterboxdHomeRefresh(this.client, this.store,
      {this.schedule = const LetterboxdHomeSchedule(), DateTime? now})
      : now = now ?? DateTime.now();
  final LetterboxdFriendsClient client;
  final LetterboxdHomeStore store;
  final LetterboxdHomeSchedule schedule;
  final DateTime now;

  bool _stale(DateTime? at, Duration every) =>
      at == null || now.difference(at) > every;

  Future<List<String>> _all(String path,
      {int maxPages = 20, bool Function()? cancelled}) async {
    final slugs = <String>[];
    for (var page = 1; page <= maxPages; page++) {
      if (cancelled?.call() ?? false) break;
      final result = await client.slugList(path, page);
      slugs.addAll(result.items);
      if (!result.hasNext) break;
    }
    return slugs;
  }

  /// Films vus : complet chaque semaine, sinon seulement les pages récentes
  /// jusqu'à la première sans nouveauté.
  Future<Set<String>> _watched(
      String username, bool Function() cancelled) async {
    final cached = await store.list('watched');
    final full = _stale(cached.fullAt, schedule.weekly);
    if (!full && !_stale(cached.at, schedule.daily)) {
      return cached.slugs.toSet();
    }
    final known = cached.slugs.toSet();
    final fetched = <String>[];
    var complete = false;
    for (var page = 1; page <= 100; page++) {
      if (cancelled()) return known;
      final result = await client.slugList('$username/films/by/date/', page);
      fetched.addAll(result.items);
      if (!result.hasNext || (!full && result.items.every(known.contains))) {
        complete = true;
        break;
      }
    }
    final slugs = full && complete ? fetched : {...fetched, ...known}.toList();
    await store.saveList('watched', slugs,
        at: now, fullAt: full && complete ? now : cached.fullAt);
    return slugs.toSet();
  }

  Future<LetterboxdHomeLists> run(String username,
      {required Map<String, List<FriendRating>> friendsIndex,
      required bool Function() cancelled}) async {
    Future<T> guarded<T>(
        String what, Future<T> Function() task, T fallback) async {
      try {
        return await task();
      } catch (error) {
        if (kDebugMode) debugPrint('[Letterboxd accueil] $what : $error');
        return fallback;
      }
    }

    final watched = await guarded(
        'films vus',
        () => _watched(username, cancelled),
        (await store.list('watched')).slugs.toSet());

    final watchlistCache = await store.list('watchlist');
    var watchlist = watchlistCache.slugs;
    if (_stale(watchlistCache.at, schedule.daily) && !cancelled()) {
      watchlist = await guarded('watchlist', () async {
        final slugs = await _all('$username/watchlist/', cancelled: cancelled);
        await store.saveList('watchlist', slugs, at: now);
        return slugs;
      }, watchlist);
    }

    final topCache = await store.list('top500');
    var top = topCache.slugs;
    if (_stale(topCache.at, schedule.weekly) && !cancelled()) {
      top = await guarded('top 500', () async {
        final slugs = await _all(top500Path, maxPages: 5, cancelled: cancelled);
        if (slugs.isNotEmpty) await store.saveList('top500', slugs, at: now);
        return slugs.isEmpty ? top : slugs;
      }, top);
    }

    // Calcul local et immédiat : refait à chaque passage, pour suivre les
    // films vus et les nouvelles notes des amis.
    var picks = (await store.list('friends')).slugs;
    if (friendsIndex.isNotEmpty) {
      picks = friendPicks(friendsIndex, watched);
      await store.saveList('friends', picks, at: now);
    }

    final lists = _lists(picks, watchlist, top, watched);
    // D'abord les fiches des rangées, puis, par lots, le reste de la
    // watchlist pour la page « tout voir ».
    await _resolve(lists.shown, cancelled);
    final rest = <String>[];
    for (final slug in watchlist) {
      if (rest.length >= watchlistResolvePerRun) break;
      if (await store.film(slug) == null) rest.add(slug);
    }
    await _resolve(rest, cancelled);
    return lists;
  }

  LetterboxdHomeLists _lists(List<String> picks, List<String> watchlist,
          List<String> top, Set<String> watched) =>
      LetterboxdHomeLists(
          friends: weightedRotationPick(
              picks.where((s) => !watched.contains(s)).toList(), now,
              count: friendDrawCount, salt: _friendsSalt),
          watchlist: rotationPick(watchlist, now,
              count: watchlistDrawCount, salt: _watchlistSalt),
          top: dailyPick(top, watched, now),
          watched: watched);

  Future<void> _resolve(
      Iterable<String> slugs, bool Function() cancelled) async {
    for (final slug in slugs) {
      if (cancelled()) return;
      if (await store.film(slug) != null) continue;
      try {
        await store.saveFilm(slug, await client.film(slug));
      } on LetterboxdUnavailable catch (error) {
        if (kDebugMode) debugPrint('[Letterboxd accueil] fiche $slug : $error');
      }
    }
  }

  /// Ce qui est déjà en cache, sans réseau.
  Future<LetterboxdHomeLists> cached() async {
    final watched = (await store.list('watched')).slugs.toSet();
    return _lists(
        (await store.list('friends')).slugs,
        (await store.list('watchlist')).slugs,
        (await store.list('top500')).slugs,
        watched);
  }
}
