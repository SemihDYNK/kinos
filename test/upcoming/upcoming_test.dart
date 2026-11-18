import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/models/seerr/seerr_dashboard_model.dart';
import 'package:kinos/upcoming/upcoming_logic.dart';
import 'package:kinos/upcoming/upcoming_models.dart';
import 'package:kinos/upcoming/upcoming_source.dart';

final today = DateTime(2026, 11, 18);

Map<String, dynamic> movie(
        {String? releaseDate,
        String status = 'Released',
        Map<String, List<(String, int)>> releases = const {},
        List<Map<String, dynamic>> cast = const [],
        Map<String, dynamic>? mediaInfo}) =>
    {
      'title': 'Film',
      'releaseDate': releaseDate,
      'status': status,
      'popularity': 10,
      'posterPath': '/p.jpg',
      'releases': {
        'results': [
          for (final MapEntry(key: country, value: dates) in releases.entries)
            {
              'iso_3166_1': country,
              'release_dates': [
                for (final (date, type) in dates)
                  {'release_date': '${date}T00:00:00.000Z', 'type': type}
              ]
            }
        ]
      },
      'credits': {'cast': cast, 'crew': const []},
      if (mediaInfo != null) 'mediaInfo': mediaInfo,
    };

void main() {
  group('movie release', () {
    test('regional date first, nearest future type', () {
      final r = movieRelease(
          movie(releaseDate: '2026-11-01', releases: {
            'FR': [('2026-11-01', 3), ('2027-02-10', 4), ('2027-03-01', 5)],
            'US': [('2026-10-01', 3)],
          }),
          'FR',
          today)!;
      expect(r.date, DateTime(2027, 2, 10));
      expect(r.release, UpcomingRelease.digital);
      expect(r.outside, isFalse);
    });
    test('already out in the region: not upcoming', () {
      expect(
          movieRelease(
              movie(releaseDate: '2026-12-01', releases: {
                'FR': [('2026-10-01', 3)]
              }),
              'FR',
              today),
          isNull);
    });
    test('no regional date: world date, marked outside', () {
      final r = movieRelease(
          movie(releaseDate: '2026-12-05', releases: {
            'US': [('2026-12-05', 3)]
          }),
          'FR',
          today)!;
      expect(r.date, DateTime(2026, 12, 5));
      expect(r.outside, isTrue);
    });
    test('announced without date', () {
      final r = movieRelease(movie(status: 'In Production'), 'FR', today)!;
      expect(r.date, isNull);
      expect(r.release, UpcomingRelease.unknown);
    });
  });

  test('tv release: episode, season, premiere', () {
    Map<String, dynamic> tv(int s, int e) => {
          'nextEpisodeToAir': {
            'airDate': '2026-12-01',
            'seasonNumber': s,
            'episodeNumber': e
          }
        };
    expect(tvRelease(tv(2, 4), today)!.release, UpcomingRelease.episode);
    expect(tvRelease(tv(3, 1), today)!.release, UpcomingRelease.season);
    expect(tvRelease(tv(1, 1), today)!.release, UpcomingRelease.premiere);
    expect(tvRelease({'status': 'Ended'}, today), isNull);
  });

  test('main roles: top five, a named role up to eighth, never self', () {
    Map<String, dynamic> credits(int order, String character) => movie(cast: [
          {'id': 7, 'order': order, 'character': character}
        ]);
    expect(isMainRole(credits(2, 'Paul'), 7), isTrue);
    expect(isMainRole(credits(6, 'Chani'), 7), isTrue);
    expect(isMainRole(credits(6, 'Guard #2'), 7), isFalse);
    expect(isMainRole(credits(9, 'Chani'), 7), isFalse);
    expect(isMainRole(credits(0, 'Herself'), 7), isFalse);
    expect(isMainRole(credits(1, 'Paul'), 8), isFalse);
  });

  test('grouping by week, later and unknown', () {
    UpcomingEntry e(int id, DateTime? date, {double pop = 0}) => UpcomingEntry(
        type: 'movie',
        id: id,
        title: '$id',
        date: date,
        release: UpcomingRelease.theatrical,
        popularity: pop);
    final sections = groupUpcoming([
      e(1, DateTime(2026, 11, 19)),
      e(2, DateTime(2026, 11, 24)),
      e(3, DateTime(2026, 12, 3), pop: 5),
      e(4, DateTime(2027, 6, 1)),
      e(5, null),
    ], today);
    expect(sections.map((s) => s.kind), [
      UpcomingSectionKind.thisWeek,
      UpcomingSectionKind.nextWeek,
      UpcomingSectionKind.week,
      UpcomingSectionKind.later,
      UpcomingSectionKind.unknown,
    ]);
    expect(sections[2].start, DateTime(2026, 11, 30));
    final months = groupUpcoming(
        [e(1, DateTime(2026, 11, 30)), e(2, DateTime(2027, 1, 2))], today,
        byMonth: true);
    expect(months.map((s) => s.kind),
        [UpcomingSectionKind.thisMonth, UpcomingSectionKind.month]);
  });

  test('duplicates merge their reasons', () {
    const a = UpcomingEntry(
        type: 'movie',
        id: 1,
        title: 'A',
        release: UpcomingRelease.theatrical,
        reasons: ['Denis Villeneuve']);
    final merged = mergeUpcoming([
      a,
      a.copyWith(reasons: ['Saga Dune'], big: true)
    ]);
    expect(merged.single.reasons, ['Denis Villeneuve', 'Saga Dune']);
    expect(merged.single.big, isTrue);
  });

  test('saga reason', () {
    expect(UpcomingSource.sagaReason('Dune Collection'), 'Saga Dune');
    expect(UpcomingSource.sagaReason('Dune - Saga'), 'Saga Dune');
  });

  test('follow candidates from a film', () {
    final follows = followCandidates('movie', 1, {
      'credits': {
        'cast': [
          for (var i = 0; i < 8; i++)
            {'id': 100 + i, 'name': 'Actor $i', 'order': i}
        ],
        'crew': [
          {'id': 9, 'name': 'Director', 'job': 'Director'},
          {'id': 10, 'name': 'Writer', 'job': 'Screenplay'},
        ],
      },
      'collection': {'id': 50, 'name': 'Dune Collection'},
      'productionCompanies': [
        {'id': 41077, 'name': 'Legendary', 'logoPath': '/l.png'}
      ],
    });
    expect(follows.map((f) => f.key), [
      'person:9:directing',
      for (var i = 0; i < 5; i++) 'person:${100 + i}:acting',
      'collection:50',
      'company:41077',
    ]);
  });

  test('source: follows and big releases, main roles and status', () async {
    final pages = <String, Map<String, dynamic>>{
      'person/7/combined_credits': {
        'cast': [
          {'id': 1, 'mediaType': 'movie', 'releaseDate': '2027-01-01'},
          {'id': 2, 'mediaType': 'movie', 'releaseDate': '2027-02-01'},
          {'id': 3, 'mediaType': 'movie', 'releaseDate': '2020-01-01'},
        ],
      },
      'discover/movies': {
        'results': [
          {'id': 1, 'popularity': 50},
          {'id': 4, 'popularity': 40},
        ]
      },
      'discover/tv': {'results': []},
      'movie/1': movie(releases: {
        'FR': [('2027-01-01', 3)]
      }, cast: [
        {'id': 7, 'order': 0, 'character': 'Lead'}
      ], mediaInfo: {
        'status': 2
      }),
      'movie/2': movie(releases: {
        'FR': [('2027-02-01', 3)]
      }, cast: [
        {'id': 7, 'order': 12, 'character': 'Cameo'}
      ]),
      'movie/4': movie(releases: {
        'FR': [('2027-03-01', 3)]
      }),
    };
    final source = UpcomingSource(
        (path, {query = const {}}) async => pages[path] ?? {},
        map: <T, R>(input, action) => Future.wait(input.map(action)),
        region: 'FR',
        today: today);
    final entries = await source.load(const [
      UpcomingFollow(
          kind: UpcomingFollowKind.person,
          id: 7,
          name: 'Léa Martin',
          role: UpcomingRole.acting)
    ]);
    final byId = {for (final e in entries) e.id: e};
    expect(byId.keys.toSet(), {1, 4});
    expect(byId[1]!.reasons, ['Léa Martin']);
    expect(byId[1]!.big, isTrue);
    expect(byId[1]!.status, SeerrMediaStatus.pending);
    expect(byId[1]!.requested, isTrue);
    expect(byId[4]!.reasons, isEmpty);
    expect(byId[4]!.requested, isFalse);
    // Le cache relit ce qu'il écrit.
    expect(UpcomingEntry.fromJson(byId[1]!.toJson())!.reasons, ['Léa Martin']);
  });
}
