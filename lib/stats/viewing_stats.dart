import 'package:kinos/ratings/kinos_ratings.dart';

import 'viewing_log.dart';

/// Période affichée : une année, un mois d'une année, ou depuis toujours
/// ([year] null).
class StatsPeriod {
  const StatsPeriod({this.year, this.month});
  final int? year;
  final int? month;

  bool contains(DateTime at) =>
      (year == null || at.year == year) && (month == null || at.month == month);

  @override
  bool operator ==(Object other) =>
      other is StatsPeriod && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);
}

typedef Ranked = ({String name, int count});

/// Ce que la page Statistiques montre pour une période.
class ViewingStats {
  const ViewingStats({
    required this.films,
    required this.episodes,
    required this.series,
    required this.elsewhere,
    required this.seconds,
    required this.buckets,
    required this.days,
    required this.genres,
    required this.directors,
    required this.actors,
    required this.ratings,
    required this.average,
    required this.topRated,
    required this.longestNight,
    required this.longestFilm,
    required this.mostSeen,
    required this.busiestBucket,
    required this.years,
  });

  /// Séances de films, épisodes, séries différentes.
  final int films;
  final int episodes;
  final int series;

  /// Films vus hors de Kinos et de Jellyfin (cinéma, ailleurs) : seulement
  /// dans le journal Letterboxd.
  final int elsewhere;
  final int seconds;

  /// Secondes par mois (une année : 12 valeurs ; un mois : une par jour ;
  /// depuis toujours : une par année, de la première à la dernière).
  final List<int> buckets;

  /// Secondes par jour (calendrier).
  final Map<DateTime, int> days;
  final List<Ranked> genres;
  final List<Ranked> directors;
  final List<Ranked> actors;

  /// Nombre de notes par valeur, de ½ (indice 0) à 5 étoiles (indice 9).
  final List<int> ratings;
  final double? average;

  /// Les mieux notés de la période, du meilleur au moins bon.
  final List<({ViewingEvent event, int rating})> topRated;

  /// Le jour le plus chargé en épisodes.
  final ({DateTime day, int episodes, String? series})? longestNight;
  final ViewingEvent? longestFilm;

  /// Le titre vu le plus de fois (au moins deux).
  final ({ViewingEvent event, int times})? mostSeen;

  /// Indice de [buckets] le plus chargé.
  final int? busiestBucket;

  /// Années qui ont au moins une séance, de la plus récente à la plus
  /// ancienne.
  final List<int> years;

  bool get isEmpty => films + episodes == 0;
}

List<Ranked> _top(Map<String, int> counts, [int take = 6]) =>
    (counts.entries.toList()
          ..sort((a, b) => b.value != a.value
              ? b.value.compareTo(a.value)
              : a.key.compareTo(b.key)))
        .take(take)
        .map((e) => (name: e.key, count: e.value))
        .toList();

/// Calcule les statistiques de [period] à partir du journal et des notes.
ViewingStats computeStats(List<ViewingEvent> all,
    Map<String, KinosRating> ratings, StatsPeriod period) {
  final events = [
    for (final e in all)
      if (period.contains(e.at)) e
  ]..sort((a, b) => a.at.compareTo(b.at));
  final years = ({for (final e in all) e.at.year}.toList()
    ..sort((a, b) => b.compareTo(a)));

  final movies = [
    for (final e in events)
      if (e.isMovie) e
  ];
  final episodes = [
    for (final e in events)
      if (!e.isMovie) e
  ];

  // Les tranches de l'histogramme.
  final first = years.isEmpty ? DateTime.now().year : years.last;
  final last = years.isEmpty ? DateTime.now().year : years.first;
  final size = period.year == null
      ? last - first + 1
      : period.month == null
          ? 12
          : DateTime(period.year!, period.month! + 1, 0).day;
  int bucketOf(DateTime at) => period.year == null
      ? at.year - first
      : period.month == null
          ? at.month - 1
          : at.day - 1;
  final buckets = List.filled(size, 0);
  final days = <DateTime, int>{};
  for (final e in events) {
    final b = bucketOf(e.at);
    if (b >= 0 && b < size) buckets[b] += e.seconds;
    final day = DateTime(e.at.year, e.at.month, e.at.day);
    days[day] = (days[day] ?? 0) + e.seconds;
  }

  // Les goûts : les films comptent par séance, les séries une fois.
  final genres = <String, int>{};
  final directors = <String, int>{};
  final actors = <String, int>{};
  void count(Map<String, int> into, Iterable<String> names) {
    for (final n in names.toSet()) {
      into[n] = (into[n] ?? 0) + 1;
    }
  }

  for (final e in movies) {
    count(genres, e.genres);
    count(directors, e.directors);
    count(actors, e.cast);
  }
  final seriesSeen = <String, ViewingEvent>{
    for (final e in episodes) e.seriesTitle ?? e.identity: e
  };
  for (final e in seriesSeen.values) {
    count(genres, e.genres);
    count(actors, e.cast);
  }

  // Les notes : celles des films de la période, ou toutes.
  final rated = <String, ({ViewingEvent event, int rating})>{};
  for (final e in movies) {
    final r = ratings[e.identity] ??
        (e.jellyfinId == null ? null : ratings['jellyfin:${e.jellyfinId}']);
    if (r != null) rated[e.identity] = (event: e, rating: r.value);
  }
  final values = period.year == null
      ? [for (final r in ratings.values) r.value]
      : [for (final r in rated.values) r.rating];
  final distribution = List.filled(10, 0);
  for (final v in values) {
    distribution[v - 1]++;
  }
  final topRated = (rated.values.toList()
        ..sort((a, b) => b.rating != a.rating
            ? b.rating.compareTo(a.rating)
            : b.event.at.compareTo(a.event.at)))
      .take(16)
      .toList();

  // Les records.
  final perNight = <DateTime, List<ViewingEvent>>{};
  for (final e in episodes) {
    (perNight[DateTime(e.at.year, e.at.month, e.at.day)] ??= []).add(e);
  }
  final night = perNight.entries.isEmpty
      ? null
      : perNight.entries
          .reduce((a, b) => b.value.length > a.value.length ? b : a);
  final longest = movies
      .where((e) => e.runtimeSeconds != null)
      .fold<ViewingEvent?>(
          null,
          (best, e) => best == null || e.runtimeSeconds! > best.runtimeSeconds!
              ? e
              : best);
  final times = <String, List<ViewingEvent>>{};
  for (final e in movies) {
    (times[e.identity] ??= []).add(e);
  }
  final seen = times.values
      .where((l) => l.length > 1)
      .fold<List<ViewingEvent>?>(
          null, (best, l) => best == null || l.length > best.length ? l : best);
  var busiest = -1;
  for (var i = 0; i < buckets.length; i++) {
    if (buckets[i] > 0 && (busiest < 0 || buckets[i] > buckets[busiest])) {
      busiest = i;
    }
  }

  return ViewingStats(
    films: movies.length,
    episodes: episodes.length,
    series: seriesSeen.length,
    elsewhere: movies
        .where((e) =>
            e.sources.length == 1 &&
            e.sources.contains(ViewingSource.letterboxd) &&
            e.jellyfinId == null)
        .length,
    seconds: events.fold(0, (sum, e) => sum + e.seconds),
    buckets: buckets,
    days: days,
    genres: _top(genres),
    directors: _top(directors, 5),
    actors: _top(actors, 5),
    ratings: distribution,
    average: values.isEmpty
        ? null
        : values.reduce((a, b) => a + b) / values.length / 2,
    topRated: topRated,
    longestNight: night == null || night.value.length < 2
        ? null
        : (
            day: night.key,
            episodes: night.value.length,
            series: night.value.first.seriesTitle
          ),
    longestFilm: longest,
    mostSeen: seen == null ? null : (event: seen.last, times: seen.length),
    busiestBucket: busiest < 0 ? null : busiest,
    years: years,
  );
}
