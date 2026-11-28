import 'package:kinos/letterboxd/friends/letterboxd_friends_parser.dart'
    show LetterboxdFriend;
import 'package:kinos/ratings/kinos_ratings.dart';
import 'package:kinos/recommendations/adapters/catalog_inventory.dart';

import '../viewing_log.dart';
import '../viewing_stats.dart';
import 'film_facts.dart';

/// Cette année face à l'an dernier : le temps, les films, le genre, et les
/// réalisateurs découverts.
typedef WrappedVersus = ({
  int seconds,
  int lastSeconds,
  int films,
  int lastFilms,
  String? genre,
  String? lastGenre,

  /// Réalisateurs des films de l'année jamais croisés avant.
  int newDirectors,
});

/// Séances l'an dernier en dessous desquelles la comparaison ne dit rien.
const _minLastYear = 10;

WrappedVersus? wrappedVersus(
    List<ViewingEvent> all, Map<String, KinosRating> ratings, int year) {
  final last = computeStats(all, ratings, StatsPeriod(year: year - 1));
  if (last.films + last.episodes < _minLastYear || last.seconds == 0) {
    return null;
  }
  final now = computeStats(all, ratings, StatsPeriod(year: year));
  final before = {
    for (final e in all)
      if (e.isMovie && e.at.year < year) ...e.directors
  };
  final discovered = {
    for (final e in all)
      if (e.isMovie && e.at.year == year)
        for (final d in e.directors)
          if (!before.contains(d)) d
  };
  String? genre(ViewingStats s) => s.genres.firstOrNull == null
      ? null
      : canonicalGenreLabel(s.genres.first.name);
  return (
    seconds: now.seconds,
    lastSeconds: last.seconds,
    films: now.films,
    lastFilms: last.films,
    genre: genre(now),
    lastGenre: genre(last),
    newDirectors: discovered.length,
  );
}

/// Une note d'ami face à la vôtre, sur un film de l'année.
typedef SharedRating = ({ViewingEvent film, int mine, int theirs});

/// L'ami Letterboxd dont les notes collent le plus aux vôtres, et celui
/// qui s'en écarte le plus. Écarts moyens en étoiles.
typedef WrappedSoulmate = ({
  LetterboxdFriend friend,
  double gap,
  List<SharedRating> shared,
  LetterboxdFriend? opposite,
  double? oppositeGap,
});

/// Films notés en commun au minimum pour juger un ami.
const _minShared = 4;

WrappedSoulmate? wrappedSoulmate(
    Iterable<
            ({
              ViewingEvent film,
              int mine,
              List<({LetterboxdFriend friend, int rating})> ratings
            })>
        takes) {
  final byFriend = <String, (LetterboxdFriend, List<SharedRating>)>{};
  for (final t in takes) {
    for (final r in t.ratings) {
      (byFriend[r.friend.username] ??= (r.friend, []))
          .$2
          .add((film: t.film, mine: t.mine, theirs: r.rating));
    }
  }
  double gap(List<SharedRating> shared) =>
      shared.fold(0, (sum, s) => sum + (s.mine - s.theirs).abs()) /
      shared.length /
      2;
  final judged = [
    for (final (friend, shared) in byFriend.values)
      if (shared.length >= _minShared) (friend, shared, gap(shared))
  ]..sort((a, b) {
      final byGap = a.$3.compareTo(b.$3);
      return byGap != 0 ? byGap : b.$2.length.compareTo(a.$2.length);
    });
  if (judged.isEmpty) return null;
  final (friend, shared, best) = judged.first;
  final far =
      judged.length > 1 && judged.last.$3 - best >= .5 ? judged.last : null;
  // Les films où vous vous rejoignez le mieux, les plus aimés d'abord.
  final ordered = [...shared]..sort((a, b) {
      final byGap =
          (a.mine - a.theirs).abs().compareTo((b.mine - b.theirs).abs());
      return byGap != 0 ? byGap : (b.mine + b.theirs) - (a.mine + a.theirs);
    });
  return (
    friend: friend,
    gap: best,
    shared: ordered,
    opposite: far?.$1,
    oppositeGap: far?.$3,
  );
}

/// Les records de l'année : le film le plus long, le plus court, le plus
/// revu.
typedef WrappedRecords = ({
  ViewingEvent longest,
  ViewingEvent shortest,
  ViewingEvent? mostSeen,
  int times,
});

/// Films à la durée connue au minimum pour parler de records.
const _minTimedFilms = 5;

WrappedRecords? wrappedRecords(List<ViewingEvent> timeline) {
  final films = <String, ViewingEvent>{};
  final viewings = <String, int>{};
  for (final e in timeline) {
    films[e.identity] = e;
    viewings[e.identity] = (viewings[e.identity] ?? 0) + 1;
  }
  final timed = [
    for (final e in films.values)
      if ((e.runtimeSeconds ?? 0) > 0) e
  ]..sort((a, b) => b.runtimeSeconds!.compareTo(a.runtimeSeconds!));
  if (timed.length < _minTimedFilms) return null;
  final most = viewings.entries
      .where((e) => e.value > 1)
      .fold<MapEntry<String, int>?>(
          null, (a, b) => a == null || b.value > a.value ? b : a);
  return (
    longest: timed.first,
    shortest: timed.last,
    mostSeen: most == null ? null : films[most.key],
    times: most?.value ?? 1,
  );
}

/// Le tour du monde : les pays de production des films de l'année, du plus
/// représenté au moins.
typedef WrappedWorld = ({
  List<({String code, int films})> countries,

  /// Films dont on connaît les pays.
  int films,
});

/// Pays distincts au minimum pour un tour du monde.
const _minCountries = 3;

WrappedWorld? wrappedWorld(
    Iterable<ViewingEvent> films, Map<int, FilmFacts> facts) {
  final counts = <String, int>{};
  var known = 0;
  for (final e in films) {
    final countries = e.tmdbId == null ? null : facts[e.tmdbId]?.countries;
    if (countries == null || countries.isEmpty) continue;
    known++;
    for (final c in countries.toSet()) {
      counts[c] = (counts[c] ?? 0) + 1;
    }
  }
  if (counts.length < _minCountries) return null;
  final ranked = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return (
    countries: [for (final e in ranked) (code: e.key, films: e.value)],
    films: known,
  );
}

/// La chaîne de l'année : le diffuseur (studio Jellyfin des séries) qui a
/// pris le plus d'épisodes.
typedef WrappedChannel = ({
  String name,
  int episodes,
  List<String> series,
});

/// Épisodes au minimum pour une chaîne de l'année.
const _minChannelEpisodes = 8;

WrappedChannel? wrappedChannel(
    List<({String name, List<ViewingEvent> episodes})> series) {
  final episodes = <String, int>{};
  final shows = <String, List<String>>{};
  for (final s in series) {
    final studios = {
      for (final e in s.episodes)
        for (final studio in e.studios)
          if (studio.trim().isNotEmpty) studio.trim()
    };
    for (final studio in studios) {
      episodes[studio] = (episodes[studio] ?? 0) + s.episodes.length;
      (shows[studio] ??= []).add(s.name);
    }
  }
  final top = episodes.entries.fold<MapEntry<String, int>?>(
      null, (a, b) => a == null || b.value > a.value ? b : a);
  if (top == null || top.value < _minChannelEpisodes) return null;
  return (name: top.key, episodes: top.value, series: shows[top.key]!);
}

/// Les séries commencées cette année : aucune séance avant.
Set<String> seriesStartedIn(Iterable<ViewingEvent> all, int year) {
  final first = <String, int>{};
  for (final e in all) {
    if (e.isMovie) continue;
    final name = e.seriesTitle ?? e.title;
    final y = first[name];
    if (y == null || e.at.year < y) first[name] = e.at.year;
  }
  return {
    for (final e in first.entries)
      if (e.value == year) e.key
  };
}

/// Le nom français d'un pays (code ISO 3166-1), le code à défaut.
String countryName(String code) => _countries[code] ?? code;

const _countries = {
  'AR': 'Argentine',
  'AT': 'Autriche',
  'AU': 'Australie',
  'BE': 'Belgique',
  'BR': 'Brésil',
  'CA': 'Canada',
  'CH': 'Suisse',
  'CL': 'Chili',
  'CN': 'Chine',
  'CO': 'Colombie',
  'CZ': 'Tchéquie',
  'DE': 'Allemagne',
  'DK': 'Danemark',
  'EG': 'Égypte',
  'ES': 'Espagne',
  'FI': 'Finlande',
  'FR': 'France',
  'GB': 'Royaume-Uni',
  'GR': 'Grèce',
  'HK': 'Hong Kong',
  'HU': 'Hongrie',
  'ID': 'Indonésie',
  'IE': 'Irlande',
  'IL': 'Israël',
  'IN': 'Inde',
  'IR': 'Iran',
  'IS': 'Islande',
  'IT': 'Italie',
  'JP': 'Japon',
  'KR': 'Corée du Sud',
  'LB': 'Liban',
  'LU': 'Luxembourg',
  'MA': 'Maroc',
  'MX': 'Mexique',
  'NG': 'Nigeria',
  'NL': 'Pays-Bas',
  'NO': 'Norvège',
  'NZ': 'Nouvelle-Zélande',
  'PE': 'Pérou',
  'PH': 'Philippines',
  'PL': 'Pologne',
  'PT': 'Portugal',
  'RO': 'Roumanie',
  'RU': 'Russie',
  'SE': 'Suède',
  'SN': 'Sénégal',
  'SU': 'URSS',
  'TH': 'Thaïlande',
  'TN': 'Tunisie',
  'TR': 'Turquie',
  'TW': 'Taïwan',
  'UA': 'Ukraine',
  'US': 'États-Unis',
  'VN': 'Viêt Nam',
  'XC': 'Tchécoslovaquie',
  'XG': 'RDA',
  'YU': 'Yougoslavie',
  'ZA': 'Afrique du Sud',
};
