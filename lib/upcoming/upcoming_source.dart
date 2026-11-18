import 'package:kinos/models/seerr/seerr_dashboard_model.dart'
    show SeerrMediaStatus;

import 'upcoming_logic.dart';
import 'upcoming_models.dart';

/// Une requête à l'API Seerr (`/api/v1/<path>`).
typedef SeerrGet = Future<Map<String, dynamic>> Function(String path,
    {Map<String, String> query});

/// Exécute les fiches à lire, avec la concurrence du client.
typedef SeerrMap = Future<List<R>> Function<T, R>(
    List<T> input, Future<R> Function(T) action);

class _Candidate {
  _Candidate(this.type, this.id, this.popularity);
  final String type;
  final int id;
  double popularity;

  /// Raison → personne dont le rôle principal reste à vérifier, ou null.
  final reasons = <String, int?>{};
  bool big = false;

  /// Séries d'une chaîne suivie : nouvelles séries et nouvelles saisons
  /// seulement, pas chaque épisode.
  bool seasonsOnly = true;

  String get identity => 'tmdb:$type:$id';
}

/// Rassemble les titres à venir : ceux des suivis, puis les grandes
/// sorties, chacun complété par sa fiche (date dans la région, rôle
/// principal, statut de la demande).
class UpcomingSource {
  UpcomingSource(this.get,
      {required this.map,
      required this.region,
      required this.today,
      this.maxDetails = 160});

  final SeerrGet get;
  final SeerrMap map;
  final String region;
  final DateTime today;
  final int maxDetails;

  /// Grandes sorties retenues : films, séries.
  static const bigMovies = 30;
  static const bigSeries = 12;

  /// Séries d'un acteur dont on surveille la prochaine saison.
  static const actorSeries = 5;

  String get _today => _iso(today);
  String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  bool _future(Object? date) {
    final parsed = parseTmdbDate(date);
    return parsed == null ||
        !parsed.isBefore(DateTime(today.year, today.month, today.day));
  }

  final _candidates = <String, _Candidate>{};

  _Candidate _add(String type, Object? id, {Object? popularity}) {
    final key = 'tmdb:$type:$id';
    final candidate =
        _candidates.putIfAbsent(key, () => _Candidate(type, id as int, 0));
    if (popularity is num && popularity > candidate.popularity) {
      candidate.popularity = popularity.toDouble();
    }
    return candidate;
  }

  static List<Map<String, dynamic>> _list(Object? value) => value is List
      ? value.whereType<Map<String, dynamic>>().toList()
      : const [];

  /// « Dune Collection », « Dune - Saga » → « Saga Dune ».
  static String sagaReason(String name) =>
      'Saga ${name.replaceAll(RegExp(r'\s*[-–:]?\s*(collection|saga)$', caseSensitive: false), '').replaceAll(RegExp(r'^(saga|collection)\s*[-–:]?\s*', caseSensitive: false), '').trim()}';

  Future<void> _collect(UpcomingFollow follow) async {
    switch (follow.kind) {
      case UpcomingFollowKind.person:
        final credits = await get('person/${follow.id}/combined_credits');
        if (follow.role == UpcomingRole.directing) {
          for (final c in _list(credits['crew'])) {
            if (c['job'] != 'Director' || c['mediaType'] != 'movie') continue;
            if (c['id'] is! int || !_future(c['releaseDate'])) continue;
            _add('movie', c['id'], popularity: c['popularity'])
                .reasons[follow.name] = null;
          }
        } else {
          final series = <Map<String, dynamic>>[];
          for (final c in _list(credits['cast'])) {
            if (c['id'] is! int) continue;
            if (c['mediaType'] == 'movie' && _future(c['releaseDate'])) {
              _add('movie', c['id'], popularity: c['popularity'])
                  .reasons[follow.name] = follow.id;
            } else if (c['mediaType'] == 'tv') {
              final episodes = c['episodeCount'];
              if (_future(c['firstAirDate']) ||
                  (episodes is int && episodes >= 5)) {
                series.add(c);
              }
            }
          }
          series.sort((a, b) => ((b['popularity'] as num?) ?? 0)
              .compareTo((a['popularity'] as num?) ?? 0));
          for (final c in series.take(actorSeries)) {
            _add('tv', c['id'], popularity: c['popularity'])
                .reasons[follow.name] = follow.id;
          }
        }
      case UpcomingFollowKind.company:
        final found = await get('discover/movies', query: {
          'studio': '${follow.id}',
          'primaryReleaseDateGte': _today,
          'sortBy': 'primary_release_date.asc',
        });
        for (final r in _list(found['results'])) {
          if (r['id'] is! int) continue;
          _add('movie', r['id'], popularity: r['popularity'])
              .reasons[follow.name] = null;
        }
      case UpcomingFollowKind.network:
        for (final query in [
          {'firstAirDateGte': _today},
          {'sortBy': 'popularity.desc'},
        ]) {
          final found = await get('discover/tv',
              query: {'network': '${follow.id}', ...query});
          for (final r in _list(found['results']).take(12)) {
            if (r['id'] is! int) continue;
            _add('tv', r['id'], popularity: r['popularity'])
                .reasons[follow.name] = null;
          }
        }
      case UpcomingFollowKind.collection:
        final collection = await get('collection/${follow.id}');
        final reason = sagaReason(follow.name);
        for (final part in _list(collection['parts'])) {
          if (part['id'] is! int || !_future(part['releaseDate'])) continue;
          _add('movie', part['id'], popularity: part['popularity'])
              .reasons[reason] = null;
        }
      case UpcomingFollowKind.tv:
        final candidate = _add('tv', follow.id)..seasonsOnly = false;
        candidate.reasons['Série suivie'] = null;
    }
  }

  Future<void> _collectBig() async {
    final horizon = _iso(today.add(const Duration(days: 180)));
    final movies = <Map<String, dynamic>>[];
    for (final page in ['1', '2']) {
      final found = await get('discover/movies', query: {
        'primaryReleaseDateGte': _today,
        'primaryReleaseDateLte': horizon,
        'sortBy': 'popularity.desc',
        'page': page,
      });
      movies.addAll(_list(found['results']));
    }
    for (final r in movies.take(bigMovies)) {
      if (r['id'] is int) {
        _add('movie', r['id'], popularity: r['popularity']).big = true;
      }
    }
    final series = await get('discover/tv', query: {
      'firstAirDateGte': _today,
      'firstAirDateLte': horizon,
      'sortBy': 'popularity.desc',
    });
    for (final r in _list(series['results']).take(bigSeries)) {
      if (r['id'] is int) {
        _add('tv', r['id'], popularity: r['popularity']).big = true;
      }
    }
  }

  /// [failed] reçoit chaque suivi illisible : les autres passent quand même.
  Future<List<UpcomingEntry>> load(List<UpcomingFollow> follows,
      {void Function(UpcomingFollow follow)? failed}) async {
    _candidates.clear();
    for (final follow in follows) {
      try {
        await _collect(follow);
      } catch (_) {
        failed?.call(follow);
      }
    }
    try {
      await _collectBig();
    } catch (_) {
      // Les suivis restent affichés.
    }
    final ordered = _candidates.values.toList()
      ..sort((a, b) {
        if (a.reasons.isEmpty != b.reasons.isEmpty) {
          return a.reasons.isEmpty ? 1 : -1;
        }
        return b.popularity.compareTo(a.popularity);
      });
    final entries = await map<_Candidate, UpcomingEntry?>(
        ordered.take(maxDetails).toList(), (candidate) async {
      try {
        return entryFor(candidate.type, candidate.id,
            await get('${candidate.type}/${candidate.id}'),
            reasons: candidate.reasons,
            big: candidate.big,
            seasonsOnly: candidate.seasonsOnly && candidate.type == 'tv');
      } catch (_) {
        return null;
      }
    });
    return mergeUpcoming(entries.nonNulls);
  }

  /// L'entrée d'une fiche, ou null si rien n'est à venir pour elle.
  UpcomingEntry? entryFor(String type, int id, Map<String, dynamic> details,
      {Map<String, int?> reasons = const {},
      bool big = false,
      bool seasonsOnly = false}) {
    final kept = [
      for (final MapEntry(key: reason, value: person) in reasons.entries)
        if (person == null || isMainRole(details, person)) reason
    ];
    if (kept.isEmpty && !big) return null;
    final title = details[type == 'movie' ? 'title' : 'name'];
    if (title is! String || title.isEmpty) return null;
    DateTime? date;
    UpcomingRelease release;
    var outside = false;
    int? season, episode;
    if (type == 'movie') {
      final next = movieRelease(details, region, today);
      if (next == null) return null;
      (date, release, outside) = (next.date, next.release, next.outside);
    } else {
      final next = tvRelease(details, today);
      if (next == null) return null;
      (date, release, season, episode) =
          (next.date, next.release, next.season, next.episode);
      if (seasonsOnly && release == UpcomingRelease.episode) {
        // Une nouvelle saison en cours de diffusion : seulement si on
        // suit la série elle-même.
        return null;
      }
    }
    if (kept.isEmpty && date == null) return null;
    final info = details['mediaInfo'];
    final status = info is Map
        ? SeerrMediaStatus.fromRaw(info['status'] as int?)
        : SeerrMediaStatus.unknown;
    final jellyfin = info is Map ? info['jellyfinMediaId'] : null;
    final popularity = details['popularity'];
    return UpcomingEntry(
        type: type,
        id: id,
        title: title,
        date: date,
        release: release,
        outsideRegion: outside,
        season: season,
        episode: episode,
        posterPath: tmdbPath(details['posterPath']),
        backdropPath: tmdbPath(details['backdropPath']),
        reasons: kept,
        big: big,
        status: status,
        jellyfinId: jellyfin is String && jellyfin.isNotEmpty ? jellyfin : null,
        popularity: popularity is num ? popularity.toDouble() : 0,
        overview: details['overview'] is String
            ? (details['overview'] as String).trim()
            : '',
        genres: [
          for (final g in _list(details['genres']))
            if (g['name'] is String) g['name'] as String
        ]);
  }
}
