import 'upcoming_models.dart';

/// Statuts TMDB d'un film annoncé mais pas sorti.
const _unreleased = {'Rumored', 'Planned', 'In Production', 'Post Production'};

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime? parseTmdbDate(Object? value) {
  if (value is! String || value.length < 10) return null;
  final parsed = DateTime.tryParse(value.substring(0, 10));
  return parsed == null ? null : _day(parsed);
}

/// Prochaine sortie d'un film dans [region] (code ISO, « FR ») d'après sa
/// fiche Seerr : la plus proche date à venir, salle, numérique, physique ou
/// télévision. Sans date dans la région, la date mondiale, marquée hors
/// région. Null si le film est déjà sorti.
({DateTime? date, UpcomingRelease release, bool outside})? movieRelease(
    Map<String, dynamic> details, String region, DateTime today) {
  final day = _day(today);
  final results = (details['releases'] as Map?)?['results'];
  final regional = results is List
      ? results
          .whereType<Map>()
          .where((r) => r['iso_3166_1'] == region)
          .expand((r) => (r['release_dates'] as List?) ?? const [])
          .whereType<Map>()
          .toList()
      : const <Map>[];
  DateTime? best;
  UpcomingRelease? kind;
  for (final release in regional) {
    final release0 = switch (release['type']) {
      2 || 3 => UpcomingRelease.theatrical,
      4 => UpcomingRelease.digital,
      5 => UpcomingRelease.physical,
      6 => UpcomingRelease.television,
      _ => null,
    };
    final date = parseTmdbDate(release['release_date']);
    if (release0 == null || date == null || date.isBefore(day)) continue;
    if (best == null || date.isBefore(best)) {
      best = date;
      kind = release0;
    }
  }
  if (best != null) return (date: best, release: kind!, outside: false);
  final primary = parseTmdbDate(details['releaseDate']);
  if (regional.isEmpty && primary != null && !primary.isBefore(day)) {
    return (date: primary, release: UpcomingRelease.theatrical, outside: true);
  }
  if (primary == null && _unreleased.contains(details['status'])) {
    return (date: null, release: UpcomingRelease.unknown, outside: false);
  }
  return null;
}

/// Prochaine diffusion d'une série : nouvel épisode, nouvelle saison ou
/// nouvelle série. Null si rien n'est annoncé.
({DateTime? date, UpcomingRelease release, int? season, int? episode})?
    tvRelease(Map<String, dynamic> details, DateTime today) {
  final day = _day(today);
  final next = details['nextEpisodeToAir'];
  if (next is Map) {
    final date = parseTmdbDate(next['airDate']);
    final season = next['seasonNumber'], episode = next['episodeNumber'];
    if (date != null &&
        !date.isBefore(day) &&
        season is int &&
        episode is int) {
      return (
        date: date,
        release: episode == 1
            ? (season <= 1 ? UpcomingRelease.premiere : UpcomingRelease.season)
            : UpcomingRelease.episode,
        season: season,
        episode: episode,
      );
    }
  }
  final first = parseTmdbDate(details['firstAirDate']);
  if (first != null && !first.isBefore(day)) {
    return (
      date: first,
      release: UpcomingRelease.premiere,
      season: 1,
      episode: 1
    );
  }
  if (first == null &&
      (details['status'] == 'In Production' ||
          details['status'] == 'Planned')) {
    return (
      date: null,
      release: UpcomingRelease.unknown,
      season: null,
      episode: null
    );
  }
  return null;
}

final _notARole = RegExp(
    r'^(self|himself|herself|themselves|lui-même|elle-même)\b|\(voice\)|uncredited|\(archive',
    caseSensitive: false);

/// Rôle principal de [personId] dans une fiche : parmi les cinq premiers
/// du générique, ou un personnage nommé parmi les huit premiers (le second
/// rôle de la promo). Jamais une apparition dans son propre rôle ni une
/// voix.
bool isMainRole(Map<String, dynamic> details, int personId) {
  final cast = (details['credits'] as Map?)?['cast'];
  if (cast is! List) return false;
  for (final member in cast.whereType<Map>()) {
    if (member['id'] != personId) continue;
    final order = member['order'];
    final character = member['character'];
    if (order is! int) return false;
    if (character is String && _notARole.hasMatch(character)) return false;
    if (order <= 4) return true;
    return order <= 7 &&
        character is String &&
        character.trim().isNotEmpty &&
        !RegExp(r'#\d|\d+$').hasMatch(character.trim());
  }
  return false;
}

/// Fusionne les doublons (même titre trouvé par plusieurs suivis) : une
/// seule entrée, toutes ses raisons.
List<UpcomingEntry> mergeUpcoming(Iterable<UpcomingEntry> entries) {
  final merged = <String, UpcomingEntry>{};
  for (final entry in entries) {
    final known = merged[entry.identity];
    merged[entry.identity] = known == null
        ? entry
        : known.copyWith(
            reasons: {...known.reasons, ...entry.reasons}.toList(),
            big: known.big || entry.big);
  }
  return merged.values.toList();
}

/// Ordre d'affichage : par date, sans date en dernier ; à date égale, les
/// suivis puis les plus attendus.
int compareUpcoming(UpcomingEntry a, UpcomingEntry b) {
  final da = a.date, db = b.date;
  if (da == null || db == null) {
    if (da != db) return da == null ? 1 : -1;
  } else if (da != db) {
    return da.compareTo(db);
  }
  if (a.reasons.isEmpty != b.reasons.isEmpty) {
    return a.reasons.isEmpty ? 1 : -1;
  }
  return b.popularity.compareTo(a.popularity);
}

enum UpcomingTypeFilter { all, movies, series }

enum UpcomingScopeFilter { both, followed, big }

List<UpcomingEntry> filterUpcoming(List<UpcomingEntry> entries,
        {UpcomingTypeFilter type = UpcomingTypeFilter.all,
        UpcomingScopeFilter scope = UpcomingScopeFilter.both}) =>
    [
      for (final e in entries)
        if ((type == UpcomingTypeFilter.all ||
                (type == UpcomingTypeFilter.movies) == e.isMovie) &&
            (scope == UpcomingScopeFilter.both ||
                (scope == UpcomingScopeFilter.followed
                    ? e.reasons.isNotEmpty
                    : e.big)))
          e
    ];

enum UpcomingSectionKind {
  thisWeek,
  nextWeek,
  week,
  thisMonth,
  month,
  later,
  unknown
}

class UpcomingSection {
  const UpcomingSection(this.kind, this.entries, {this.start, this.end});
  final UpcomingSectionKind kind;

  /// Début et fin (inclus) de la période, pour son titre.
  final DateTime? start;
  final DateTime? end;
  final List<UpcomingEntry> entries;
}

/// Semaines affichées une par une avant « Plus tard ».
const upcomingWeeks = 12;

/// Mois affichés un par un avant « Plus tard ».
const upcomingMonths = 12;

/// Découpe la frise, à la semaine (lundi → dimanche) ou au mois.
List<UpcomingSection> groupUpcoming(List<UpcomingEntry> entries, DateTime today,
    {bool byMonth = false}) {
  final day = _day(today);
  final sorted = [...entries]..sort(compareUpcoming);
  final monday = day.subtract(Duration(days: day.weekday - 1));
  final buckets = <int, List<UpcomingEntry>>{};
  final later = <UpcomingEntry>[];
  final unknown = <UpcomingEntry>[];
  for (final entry in sorted) {
    final date = entry.date;
    if (date == null) {
      unknown.add(entry);
      continue;
    }
    final index = byMonth
        ? (date.year - day.year) * 12 + date.month - day.month
        : _day(date).difference(monday).inDays ~/ 7;
    if (index < 0) continue;
    if (index >= (byMonth ? upcomingMonths : upcomingWeeks)) {
      later.add(entry);
    } else {
      (buckets[index] ??= []).add(entry);
    }
  }
  final sections = <UpcomingSection>[];
  for (final index in buckets.keys.toList()..sort()) {
    final start = byMonth
        ? DateTime(day.year, day.month + index)
        : monday.add(Duration(days: 7 * index));
    final end = byMonth
        ? DateTime(day.year, day.month + index + 1, 0)
        : start.add(const Duration(days: 6));
    final kind = byMonth
        ? (index == 0
            ? UpcomingSectionKind.thisMonth
            : UpcomingSectionKind.month)
        : switch (index) {
            0 => UpcomingSectionKind.thisWeek,
            1 => UpcomingSectionKind.nextWeek,
            _ => UpcomingSectionKind.week,
          };
    sections
        .add(UpcomingSection(kind, buckets[index]!, start: start, end: end));
  }
  if (later.isNotEmpty) {
    sections.add(UpcomingSection(UpcomingSectionKind.later, later));
  }
  if (unknown.isNotEmpty) {
    sections.add(UpcomingSection(UpcomingSectionKind.unknown, unknown));
  }
  return sections;
}

/// Les diapos du bandeau : les prochains titres suivis, puis les plus
/// attendues des grandes sorties des deux mois à venir, avec une image de
/// fond.
List<UpcomingEntry> upcomingFeatured(List<UpcomingEntry> entries,
    {DateTime? today, int followed = 3, int total = 8}) {
  final now = today ?? DateTime.now();
  final horizon = DateTime(now.year, now.month + 2, now.day);
  final dated = [
    for (final e in entries)
      if (e.date != null && e.backdropPath != null) e
  ];
  final mine = [
    for (final e in dated)
      if (e.reasons.isNotEmpty) e
  ]..sort(compareUpcoming);
  final picked = mine.take(followed).toList();
  final big = [
    for (final e in dated)
      if (e.big && !picked.contains(e) && !e.date!.isAfter(horizon)) e
  ]..sort((a, b) => b.popularity.compareTo(a.popularity));
  picked.addAll(big.take(total - picked.length));
  return picked;
}

/// Ce que l'on peut suivre depuis la fiche Seerr d'un film ou d'une série :
/// réalisation, rôles principaux, saga, studios, chaînes, la série.
List<UpcomingFollow> followCandidates(
    String type, int id, Map<String, dynamic> details) {
  List<Map> list(Object? value) =>
      value is List ? value.whereType<Map>().toList() : const [];
  final follows = <UpcomingFollow>[];
  void add(UpcomingFollow follow) {
    if (follows.every((f) => f.key != follow.key)) follows.add(follow);
  }

  if (type == 'tv') {
    final name = details['name'];
    if (name is String) {
      add(UpcomingFollow(
          kind: UpcomingFollowKind.tv,
          id: id,
          name: name,
          image: tmdbPath(details['posterPath'])));
    }
  }
  final credits = details['credits'] as Map?;
  for (final crew in list(credits?['crew'])) {
    if (crew['job'] == 'Director' &&
        crew['id'] is int &&
        crew['name'] is String) {
      add(UpcomingFollow(
          kind: UpcomingFollowKind.person,
          id: crew['id'] as int,
          name: crew['name'] as String,
          image: tmdbPath(crew['profilePath']),
          role: UpcomingRole.directing));
    }
  }
  final cast = list(credits?['cast'])
    ..sort((a, b) =>
        ((a['order'] as num?) ?? 999).compareTo((b['order'] as num?) ?? 999));
  for (final actor in cast.take(5)) {
    if (actor['id'] is int && actor['name'] is String) {
      add(UpcomingFollow(
          kind: UpcomingFollowKind.person,
          id: actor['id'] as int,
          name: actor['name'] as String,
          image: tmdbPath(actor['profilePath']),
          role: UpcomingRole.acting));
    }
  }
  final collection = details['collection'];
  if (collection is Map &&
      collection['id'] is int &&
      collection['name'] is String) {
    add(UpcomingFollow(
        kind: UpcomingFollowKind.collection,
        id: collection['id'] as int,
        name: collection['name'] as String,
        image: tmdbPath(collection['posterPath'])));
  }
  for (final network in list(details['networks']).take(2)) {
    if (network['id'] is int && network['name'] is String) {
      add(UpcomingFollow(
          kind: UpcomingFollowKind.network,
          id: network['id'] as int,
          name: network['name'] as String,
          image: tmdbPath(network['logoPath'])));
    }
  }
  for (final company in list(details['productionCompanies']).take(3)) {
    if (company['id'] is int && company['name'] is String) {
      add(UpcomingFollow(
          kind: UpcomingFollowKind.company,
          id: company['id'] as int,
          name: company['name'] as String,
          image: tmdbPath(company['logoPath'])));
    }
  }
  return follows;
}
