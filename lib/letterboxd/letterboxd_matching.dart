import 'package:kinos/models/item_base_model.dart';
import 'package:kinos/recommendations/adapters/jellyfin_trait_extraction.dart';
import 'package:kinos/recommendations/engine/arr_jellyfin_dedup.dart';
import 'package:kinos/recommendations/models/watch_event.dart';
import 'package:kinos/recommendations/models/watch_signal.dart';
import 'package:kinos/recommendations/models/trait.dart';
import 'package:kinos/recommendations/seerr/discovery_client.dart';
import 'package:kinos/recommendations/seerr/discovery_models.dart';
import 'letterboxd_model.dart';

List<LetterboxdWork> letterboxdLibraryWorks(List<ItemBaseModel> items) => [
      for (final item in items)
        if (item.type == KinosItemType.movie)
          LetterboxdWork(
              title: item.name,
              year: item.overview.yearAired,
              jellyfinId: item.id,
              aliases: [
                if (item.originalTitle?.isNotEmpty == true) item.originalTitle!
              ],
              tmdbId: int.tryParse(item.overview.tmdbId ?? ''),
              traits: traitsFromOverview(item.overview))
    ];

String _titleKey(String title) {
  final normalized = normalizeTitleForMatching(title);
  return normalized.isEmpty ? title.trim().toLowerCase() : normalized;
}

class LetterboxdMatcher {
  final _byTitle = <(String, int?), Map<String, LetterboxdWork>>{};
  LetterboxdMatcher(List<LetterboxdWork> works) {
    for (final work in works) {
      for (final title in [work.title, ...work.aliases]) {
        _byTitle.putIfAbsent(
            (_titleKey(title), work.year), () => {})[work.identity] = work;
      }
    }
  }
  List<LetterboxdWork> choices(LetterboxdFilm film) => film.year == null
      ? []
      : _byTitle[(_titleKey(film.title), film.year)]?.values.toList() ?? [];

  /// Même titre, année exacte ou voisine (cf. [closeLetterboxdMatch]).
  List<LetterboxdWork> nearby(LetterboxdFilm film) {
    final year = film.year;
    if (year == null) return [];
    final key = _titleKey(film.title);
    return {
      for (var d = 0; d <= letterboxdYearTolerance; d++)
        for (final y in {year - d, year + d}) ...?_byTitle[(key, y)],
    }.values.toList();
  }
}

LetterboxdWork? exactLetterboxdMatch(
    LetterboxdFilm film, List<LetterboxdWork> works) {
  final matches = LetterboxdMatcher(works).choices(film);
  return matches.length == 1 ? matches.single : null;
}

/// Écart d'années toléré : Letterboxd retient souvent la première sortie
/// (festival, pays d'origine), TMDB parfois une autre.
const letterboxdYearTolerance = 2;

/// Le titre exact à la bonne année ; sinon, le plus proche de même titre
/// à [letterboxdYearTolerance] ans près, et à écart égal le premier de
/// [works] (TMDB les rend par popularité). Deux titres identiques à la
/// bonne année restent sans réponse : on ne devine pas.
LetterboxdWork? closeLetterboxdMatch(
    LetterboxdFilm film, List<LetterboxdWork> works) {
  final exact = exactLetterboxdMatch(film, works);
  final year = film.year;
  if (exact != null || year == null) return exact;
  final key = _titleKey(film.title);
  final near = {
    for (final work in works)
      if (work.year != null &&
          (work.year! - year).abs() <= letterboxdYearTolerance &&
          [work.title, ...work.aliases].any((t) => _titleKey(t) == key))
        work.identity: work
  }.values.toList();
  if (near.isEmpty || near.any((w) => w.year == year)) return null;
  var best = near.first;
  for (final work in near.skip(1)) {
    if ((work.year! - year).abs() < (best.year! - year).abs()) best = work;
  }
  return best;
}

/// Les titres de [library] dont le nom contient [query] (sans accents ni
/// ponctuation), pour l'identification à la main.
List<LetterboxdWork> searchLetterboxdLibrary(
    List<LetterboxdWork> library, String query,
    {int limit = 8}) {
  final key = _titleKey(query);
  if (key.isEmpty) return [];
  return {
    for (final work in library)
      if ([work.title, ...work.aliases].any((t) => _titleKey(t).contains(key)))
        work.identity: work
  }.values.take(limit).toList();
}

class LetterboxdResolver {
  final DiscoveryClient client;
  LetterboxdResolver(this.client);
  Future<List<LetterboxdWork>> search(LetterboxdFilm film) =>
      searchTitle(film.title);

  Future<List<LetterboxdWork>> searchTitle(String title) async {
    // Seerr validates an encoded title after the HTTP query has been decoded.
    final json = await client.get('search',
        query: {'query': Uri.encodeComponent(title), 'page': '1'},
        language: 'en');
    final results = <LetterboxdWork>[];
    for (final item in objects(json['results'])) {
      final id = item['id'];
      // Films, et séries : Letterboxd liste certaines mini-séries.
      final type = item['mediaType'];
      final series = type == 'tv';
      final title = item[series ? 'name' : 'title'];
      if ((type != 'movie' && !series) ||
          id is! int ||
          id <= 0 ||
          title is! String ||
          title.isEmpty) {
        continue;
      }
      final date = item[series ? 'firstAirDate' : 'releaseDate'] as String?;
      final original = item[series ? 'originalName' : 'originalTitle'];
      results.add(LetterboxdWork(
          title: title,
          year: date == null ? null : int.tryParse(date.split('-').first),
          tmdbId: id,
          mediaType: series ? 'tv' : 'movie',
          aliases: [if (original is String) original],
          traits: const []));
    }
    return results.take(12).toList();
  }

  Future<LetterboxdWork> details(int id, {String mediaType = 'movie'}) async {
    final type = mediaType == 'tv' ? 'tv' : 'movie';
    final json = await client.get('$type/$id', language: 'en');
    final item = DiscoveryItem.fromDetails((type: type, id: id), json);
    final original = json[type == 'tv' ? 'originalName' : 'originalTitle'];
    return LetterboxdWork(
        title: item.title,
        year: item.year,
        tmdbId: id,
        mediaType: type,
        traits: item.traits,
        aliases: [if (original is String) original]);
  }
}

Set<String> letterboxdWatchedLibraryIds(
    List<LetterboxdRecord> records, List<LetterboxdWork> library) {
  final ids = <String>{};
  final byIdentity = <String, List<LetterboxdWork>>{};
  for (final item in library) {
    byIdentity.putIfAbsent(item.identity, () => []).add(item);
  }
  final matcher = LetterboxdMatcher(library);
  for (final record in records) {
    final work = record.work;
    if (work?.jellyfinId != null) ids.add(work!.jellyfinId!);
    final linked = work == null
        ? const <LetterboxdWork>[]
        : byIdentity[work.identity] ?? const <LetterboxdWork>[];
    final matches = linked.isNotEmpty ? linked : matcher.choices(record.film);
    if (linked.isNotEmpty || matches.length == 1) {
      final editions = linked.isNotEmpty
          ? linked
          : byIdentity[matches.single.identity] ?? matches;
      ids.addAll(editions.map((item) => item.jellyfinId).whereType<String>());
    }
  }
  return ids;
}

List<WatchEvent> mergeLetterboxdEvents(List<WatchEvent> original,
    List<LetterboxdRecord> records, List<LetterboxdWork> library) {
  if (records.isEmpty) return original;
  final result = {for (final event in original) event.itemId: event};
  final unique = <String, LetterboxdRecord>{};
  for (final record in records) {
    final work = record.work;
    if (work == null || work.traits.isEmpty) continue;
    final previous = unique[work.identity];
    final previousDate = previous?.film.ratedAt;
    if (previous == null ||
        (record.film.rating != null &&
            (previous.film.rating == null ||
                previousDate == null ||
                (record.film.ratedAt?.isAfter(previousDate) ?? false)))) {
      unique[work.identity] = record;
    }
  }
  final byIdentity = <String, List<LetterboxdWork>>{};
  final localGenres = <TraitKey, Set<TraitKey>>{};
  for (final work in library) {
    byIdentity.putIfAbsent(work.identity, () => []).add(work);
    if (work.jellyfinId != null) {
      byIdentity.putIfAbsent('jellyfin:${work.jellyfinId}', () => []).add(work);
    }
    for (final t in work.traits) {
      if (t.kind == TraitKind.genre) {
        localGenres.putIfAbsent(discoveryTrait(t), () => {}).add(t);
      }
    }
  }
  for (final record in unique.values) {
    final work = record.work!;
    final film = record.film;
    final matches = byIdentity[work.identity] ?? const <LetterboxdWork>[];
    final ids = {
      ...matches.map((w) => w.jellyfinId).whereType<String>(),
      work.identity
    };
    final old = [
      for (final id in ids)
        if (result.containsKey(id)) result.remove(id)!
    ];
    var weight = film.weight;
    var signal =
        film.watches > 1 ? WatchSignal.rewatched : WatchSignal.completedNeutral;
    DateTime? date = film.watchedAt;
    for (final event in old) {
      if (film.rating == null && event.baseWeight > weight) {
        weight = event.baseWeight;
        signal = event.signal;
      }
      if (event.occurredAt != null &&
          (date == null || event.occurredAt!.isAfter(date))) {
        date = event.occurredAt;
      }
    }
    final traits = <TraitKey>{};
    for (final t in work.traits) {
      traits.addAll(t.kind == TraitKind.genre
          ? localGenres[discoveryTrait(t)] ?? {t}
          : {t});
    }
    final id = matches.firstOrNull?.jellyfinId ?? work.identity;
    result[id] = WatchEvent(
        itemId: id,
        traits: traits.toList(),
        signal: signal,
        explicitWeight: weight,
        occurredAt: date);
  }
  return result.values.toList();
}
