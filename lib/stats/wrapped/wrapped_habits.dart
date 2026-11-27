import '../viewing_log.dart';

/// Quand on regarde : les séances dont l'heure est connue (lues dans
/// Kinos ; Letterboxd ne donne que le jour), par heure et par jour.
typedef WrappedHours = ({
  /// Séances par heure de début (0 à 23).
  List<int> hours,

  /// Séances par jour de la semaine (0 = lundi).
  List<int> weekdays,
  int timed,
});

/// Au moins tant de séances à l'heure connue pour parler d'habitudes.
const wrappedMinTimed = 10;

WrappedHours? wrappedHours(Iterable<ViewingEvent> events) {
  final hours = List.filled(24, 0);
  final weekdays = List.filled(7, 0);
  var timed = 0;
  for (final e in events) {
    if (!e.sources.contains(ViewingSource.kinos)) continue;
    hours[e.at.hour]++;
    weekdays[e.at.weekday - 1]++;
    timed++;
  }
  if (timed < wrappedMinTimed) return null;
  return (hours: hours, weekdays: weekdays, timed: timed);
}

/// La tranche de trois heures la plus regardée, son heure de début.
int peakHour(WrappedHours h) {
  var best = 0;
  var bestCount = -1;
  for (var start = 0; start < 24; start++) {
    final count =
        h.hours[start] + h.hours[(start + 1) % 24] + h.hours[(start + 2) % 24];
    if (count > bestCount) {
      best = start;
      bestCount = count;
    }
  }
  return best;
}

/// Part des séances commencées entre 23 h et 4 h.
double lateShare(WrappedHours h) {
  final late = [23, 0, 1, 2, 3].fold(0, (sum, i) => sum + h.hours[i]);
  return late / h.timed;
}

/// Part des séances du week-end (samedi, dimanche).
double weekendShare(WrappedHours h) =>
    (h.weekdays[5] + h.weekdays[6]) / h.timed;

/// Le jour de la semaine le plus regardé (0 = lundi).
int peakWeekday(WrappedHours h) {
  var best = 0;
  for (var i = 1; i < 7; i++) {
    if (h.weekdays[i] > h.weekdays[best]) best = i;
  }
  return best;
}

/// La saison avalée le plus vite : au moins [minEpisodes] épisodes vus
/// cette année, le plus d'épisodes par jour.
typedef WrappedPace = ({
  String series,
  int season,
  int episodes,
  int days,
});

const _minPaceEpisodes = 5;

WrappedPace? fastestSeason(
    List<({String name, List<ViewingEvent> episodes})> series) {
  WrappedPace? best;
  double rate(WrappedPace p) => p.episodes / p.days;
  for (final s in series) {
    final bySeason = <int, List<ViewingEvent>>{};
    for (final e in s.episodes) {
      if (e.season case final season? when season > 0) {
        (bySeason[season] ??= []).add(e);
      }
    }
    for (final entry in bySeason.entries) {
      // Un épisode revu ne compte qu'une fois.
      final distinct = {for (final e in entry.value) e.episode ?? e.identity};
      if (distinct.length < _minPaceEpisodes) continue;
      final dates = [for (final e in entry.value) _day(e.at)]..sort();
      final days = dates.last.difference(dates.first).inDays + 1;
      final pace = (
        series: s.name,
        season: entry.key,
        episodes: distinct.length,
        days: days,
      );
      if (best == null ||
          rate(pace) > rate(best) ||
          (rate(pace) == rate(best) && pace.episodes > best.episodes)) {
        best = pace;
      }
    }
  }
  return best;
}

/// Part des épisodes vus un jour où l'on en a enchaîné au moins trois de
/// la même série : le goût du binge.
double? bingeShare(List<({String name, List<ViewingEvent> episodes})> series) {
  var total = 0;
  var binged = 0;
  for (final s in series) {
    final perDay = <DateTime, int>{};
    for (final e in s.episodes) {
      final day = _day(e.at);
      perDay[day] = (perDay[day] ?? 0) + 1;
    }
    for (final count in perDay.values) {
      total += count;
      if (count >= 3) binged += count;
    }
  }
  return total < 20 ? null : binged / total;
}

DateTime _day(DateTime at) => DateTime(at.year, at.month, at.day);

/// Le profil de spectateur de l'année : une étiquette, une phrase, et les
/// chiffres qui la justifient.
typedef WrappedProfile = ({
  String id,
  String title,
  String line,
  List<String> facts,
});

/// Les signaux du profil, tous facultatifs : chaque trait n'est pesé que
/// si ses données existent.
class ProfileSignals {
  const ProfileSignals({
    required this.year,
    required this.films,
    required this.episodes,
    this.filmSeconds = 0,
    this.episodeSeconds = 0,
    this.hours,
    this.binge,
    this.genres = 0,
    this.foreignShare,
    this.medianYear,
    this.rewatched = 0,
  });

  final int year;
  final int films;
  final int episodes;
  final int filmSeconds;
  final int episodeSeconds;
  final WrappedHours? hours;
  final double? binge;

  /// Genres distincts parmi les films de l'année.
  final int genres;
  final double? foreignShare;
  final int? medianYear;
  final int rewatched;
}

/// Le trait le plus marqué de l'année, l'éclectique à défaut. Chaque trait
/// a un seuil ; le score est l'écart relatif à ce seuil, pour comparer des
/// traits d'unités différentes.
WrappedProfile wrappedProfile(ProfileSignals s) {
  final candidates = <(double, WrappedProfile)>[];
  void weigh(double value, double threshold, WrappedProfile profile) {
    if (value >= threshold) {
      candidates.add(((value - threshold) / threshold, profile));
    }
  }

  String percent(double share) => '${(share * 100).round()} %';

  if (s.hours case final h?) {
    final late = lateShare(h);
    weigh(late, .3, (
      id: 'night',
      title: 'Noctambule',
      line: 'Vos plus belles séances commencent quand la ville dort.',
      facts: ['${percent(late)} de vos séances après 23 h'],
    ));
    final weekend = weekendShare(h);
    weigh(weekend, .5, (
      id: 'weekend',
      title: 'Spectateur du week-end',
      line: 'La semaine attend ; le samedi et le dimanche sont à l\'écran.',
      facts: ['${percent(weekend)} de vos séances le week-end'],
    ));
  }
  if (s.binge case final binge?) {
    weigh(binge, .45, (
      id: 'binge',
      title: 'Binge-watcher',
      line: 'Un épisode n\'a jamais suffi.',
      facts: ['${percent(binge)} de vos épisodes enchaînés par trois ou plus'],
    ));
  }
  if (s.filmSeconds + s.episodeSeconds > 0 && s.episodes >= 20) {
    final share = s.episodeSeconds / (s.filmSeconds + s.episodeSeconds);
    weigh(share, .6, (
      id: 'series',
      title: 'Sériephile',
      line: 'Les longues histoires vous tiennent, saison après saison.',
      facts: ['${percent(share)} de votre temps devant des séries'],
    ));
  }
  if (s.films >= 20) {
    weigh(s.genres.toDouble(), 12, (
      id: 'explorer',
      title: 'Explorateur',
      line: 'Aucun genre ne vous retient longtemps.',
      facts: ['${s.genres} genres différents cette année'],
    ));
  }
  if (s.foreignShare case final foreign? when s.films >= 15) {
    weigh(foreign, .35, (
      id: 'world',
      title: 'Voyageur',
      line: 'Le cinéma du monde entier, dans sa langue.',
      facts: ['${percent(foreign)} de films non anglophones'],
    ));
  }
  if (s.medianYear case final median? when s.films >= 15) {
    weigh((s.year - median).toDouble(), 25, (
      id: 'classic',
      title: 'Nostalgique',
      line: 'Le présent peut attendre : les classiques d\'abord.',
      facts: ['Votre film moyen est sorti en $median'],
    ));
  }
  if (s.films >= 10) {
    weigh(s.rewatched / s.films, .15, (
      id: 'faithful',
      title: 'Fidèle',
      line: 'Vos films préférés, vous les revoyez.',
      facts: ['${s.rewatched} films revus cette année'],
    ));
  }
  weigh(s.films.toDouble(), 150, (
    id: 'cinephile',
    title: 'Cinéphile',
    line: 'Une année au cinéma, presque tous les jours.',
    facts: ['${s.films} films cette année'],
  ));
  if (candidates.isEmpty) {
    return (
      id: 'eclectic',
      title: 'Éclectique',
      line: 'Un peu de tout, au gré des envies.',
      facts: [
        if (s.films > 0) '${s.films} ${s.films > 1 ? 'films' : 'film'}',
        if (s.episodes > 0)
          '${s.episodes} ${s.episodes > 1 ? 'épisodes' : 'épisode'}',
      ],
    );
  }
  candidates.sort((a, b) => b.$1.compareTo(a.$1));
  final best = candidates.first.$2;
  // Le deuxième trait, s'il y en a un, nuance le premier.
  final second = candidates.length > 1 ? candidates[1].$2 : null;
  return (
    id: best.id,
    title: best.title,
    line: best.line,
    facts: [...best.facts, if (second != null) ...second.facts],
  );
}
