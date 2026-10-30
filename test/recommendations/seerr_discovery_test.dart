import 'dart:async';
import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kinos/models/syncing/database_item.dart';
import 'package:kinos/recommendations/models/library_trait_stats.dart';
import 'package:kinos/recommendations/models/trait.dart';
import 'package:kinos/recommendations/models/watch_event.dart';
import 'package:kinos/recommendations/models/watch_signal.dart';
import 'package:kinos/recommendations/seerr/discovery_models.dart';
import 'package:kinos/recommendations/seerr/discovery_engine.dart';
import 'package:kinos/recommendations/seerr/discovery_cache.dart';
import 'package:kinos/recommendations/seerr/discovery_client.dart';
import 'package:kinos/recommendations/seerr/discovery_repository.dart';

final _ref = Provider<Ref>((ref) => ref);
const seed = (type: 'movie', id: 1);
const candidate = (type: 'movie', id: 2);
final now = DateTime(2026, 10, 8);
final actor = trait(TraitKind.actor, 'Actor');
WatchEvent event(String id, WatchSignal signal, {DateTime? date}) => WatchEvent(
    itemId: id, traits: [actor], signal: signal, occurredAt: date ?? now);
Map<String, dynamic> detail(int id, {dynamic mediaInfo}) => {
      'id': id,
      'title': 'Film $id',
      'posterPath': '/poster.jpg',
      'releaseDate': '2020-01-01',
      'genres': [
        {'name': 'Drame'}
      ],
      'keywords': [
        {'name': 'Exploration'}
      ],
      'credits': {
        'cast': [
          {'name': 'Actor', 'order': 0}
        ],
        'crew': [
          {'name': 'Director', 'job': 'Director'}
        ]
      },
      if (mediaInfo != null) 'mediaInfo': mediaInfo,
    };
const exclusions =
    DiscoveryExclusions(identities: {}, tvdbIds: {}, imdbIds: {});
const stats = LibraryTraitStats(librarySize: 1, traitDocFrequency: {});

void main() {
  test('discovery reserves up to fifteen films and fifteen series', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final db = AppDatabase(container.read(_ref), NativeDatabase.memory());
    addTearDown(db.close);
    final cache = DiscoveryCache(db, 'quotas', const Duration(days: 7));
    final seeds = [(type: 'movie', id: 1), (type: 'tv', id: 2)];
    for (final s in seeds) {
      final keys = [for (var i = 0; i < 30; i++) (type: s.type, id: 100 + i)];
      for (final endpoint in ['similar', 'recommendations']) {
        await cache.write('list:v1:${s.identity}:$endpoint', {
          'items': [
            for (final k in keys) {'id': k.id}
          ]
        });
      }
      for (final k in keys) {
        await cache.write(
            'detail:v1:${k.identity}',
            DiscoveryItem(
                key: k,
                title: '${k.type} ${k.id}',
                traits: [trait(TraitKind.actor, k.identity)]).toJson());
      }
    }
    var requests = 0;
    final client = DiscoveryClient(
        baseUrl: Uri.parse('https://seerr'),
        headers: {},
        interval: Duration.zero,
        client: MockClient((request) async {
          requests++;
          final id = int.parse(request.url.pathSegments.last);
          return http.Response(
              jsonEncode({...detail(id), 'name': 'Title $id'}), 200);
        }));
    addTearDown(client.close);
    final result = await DiscoveryRepository(client, cache, 'fr').load(
        seeds: seeds,
        events: [
          for (final s in seeds)
            for (var i = 0; i < 30; i++)
              WatchEvent(
                  itemId: '${s.type}:$i',
                  traits: [trait(TraitKind.actor, 'tmdb:${s.type}:${100 + i}')],
                  signal: WatchSignal.completedFavorite,
                  occurredAt: DateTime.now())
        ],
        stats: stats,
        exclusions: exclusions);
    expect(result.where((i) => i.key.type == 'movie').length, 15);
    expect(result.where((i) => i.key.type == 'tv').length, 15);
    expect(requests, 30);
  });
  group('seed selection', () {
    test(
        'positive contributions, decay, no duplicated editions, at most fifteen per type',
        () {
      final events = [
        event('old', WatchSignal.rewatched,
            date: now.subtract(const Duration(days: 182))),
        event('fav', WatchSignal.completedFavorite),
        event('copy', WatchSignal.completedFavorite),
        event('negative', WatchSignal.abandonedEarly),
        event('neutral', WatchSignal.abandonedLate),
        event('missing', WatchSignal.rewatched),
        for (var i = 3; i < 20; i++) event('$i', WatchSignal.completedNeutral),
      ];
      final result = selectDiscoverySeeds(
          events,
          {
            'old': seed,
            'fav': candidate,
            'copy': candidate,
            'negative': (type: 'movie', id: 30),
            'neutral': (type: 'movie', id: 31),
            for (var i = 3; i < 20; i++) '$i': (type: 'movie', id: i),
          },
          now);
      expect(result.length, 15);
      expect(result.first, candidate);
      expect(result.toSet().length, 15);
      expect(result.any((k) => k.id >= 30), false);
    });
    test('fifteen series seeds survive thirty stronger movie seeds', () {
      final events = [
        for (var i = 0; i < 30; i++)
          event('movie$i', WatchSignal.completedFavorite),
        for (var i = 0; i < 20; i++)
          event('tv$i', WatchSignal.completedNeutral),
      ];
      final keys = {
        for (var i = 0; i < 30; i++) 'movie$i': (type: 'movie', id: i + 1),
        for (var i = 0; i < 20; i++) 'tv$i': (type: 'tv', id: i + 1),
      };
      final seeds = selectDiscoverySeeds(events, keys, now);
      expect(seeds.where((s) => s.type == 'movie'), hasLength(15));
      expect(seeds.where((s) => s.type == 'tv'), hasLength(15));
      expect(seeds.toSet(), hasLength(30));
    });
    test('empty history never falls back to popular titles', () {
      expect(selectDiscoverySeeds([], {}, now), isEmpty);
    });
    test('round robin balances sources and respects exclusions and type', () {
      expect(
          balancedDiscoveryPool([
            [seed, candidate, (type: 'movie', id: 3)],
            [candidate, (type: 'tv', id: 2)],
          ], {
            seed.identity
          }, limit: 2),
          [candidate, (type: 'tv', id: 2)]);
    });
  });
  group('metadata and exclusions', () {
    test(
        'normalizes genres and extracts keywords, four actors and real directors',
        () {
      final json = detail(2);
      json['credits'] = {
        'cast': [
          for (var i = 5; i >= 0; i--) {'name': 'Actor $i', 'order': i}
        ],
        'crew': [
          {'name': 'Director', 'job': 'Director'},
          {'name': 'Creator', 'job': 'Creator'}
        ],
      };
      final item = DiscoveryItem.fromDetails(candidate, json);
      expect(item.traits, contains(trait(TraitKind.genre, 'drama')));
      expect(item.traits, contains(trait(TraitKind.keyword, 'exploration')));
      expect(item.traits.where((t) => t.kind == TraitKind.actor).length, 4);
      expect(item.traits, isNot(contains(trait(TraitKind.actor, 'Actor 5'))));
      expect(
          item.traits, isNot(contains(trait(TraitKind.director, 'Creator'))));
      expect(DiscoveryItem.fromJson(item.toJson()).traits, item.traits);
    });
    test('ignores a remote poster URL and rejects mismatched details', () {
      expect(
          DiscoveryItem.fromDetails(candidate, {
            ...detail(2),
            'posterPath': 'https://host/?apiKey=secret'
          }).posterPath,
          isNull);
      expect(() => DiscoveryItem.fromDetails(candidate, detail(3)),
          throwsFormatException);
    });
    test('all media records are excluded including 4K and declined requests',
        () {
      for (final info in [
        {'status': 2},
        {'status': 4},
        {'status4k': 5},
        {
          'status': 1,
          'requests': [
            {'status': 3}
          ]
        },
        {'externalServiceId': 10},
        {'id': 1},
      ]) {
        expect(knownToSeerr({'mediaInfo': info}), true);
      }
      expect(knownToSeerr({}), false);
      expect(() => knownToSeerr({'mediaInfo': 'bad'}), throwsFormatException);
    });
    test('Sonarr TVDB match and typed Jellyfin TMDB match', () {
      const tv = DiscoveryItem(
          key: (type: 'tv', id: 2), title: 'TV', traits: [], tvdbId: '10');
      expect(
          const DiscoveryExclusions(
              identities: {}, tvdbIds: {'10'}, imdbIds: {}).contains(tv),
          true);
      final movie = DiscoveryItem.fromDetails(candidate, detail(2));
      expect(
          const DiscoveryExclusions(
              identities: {'tmdb:tv:2'},
              tvdbIds: {},
              imdbIds: {}).contains(movie),
          false);
      expect(
          const DiscoveryExclusions(
              identities: {'tmdb:movie:2'},
              tvdbIds: {},
              imdbIds: {}).contains(movie),
          true);
    });
    test('zero or negative affinity produces no filler', () {
      final item = DiscoveryItem.fromDetails(candidate, detail(2));
      expect(
          rankDiscovery(DiscoveryScoreInput([], stats, [item], now)), isEmpty);
      expect(
          rankDiscovery(DiscoveryScoreInput(
              [event('x', WatchSignal.abandonedEarly)], stats, [item], now)),
          isEmpty);
    });
  });
  group('persistent cache and repository', () {
    late AppDatabase db;
    late ProviderContainer container;
    setUp(() {
      container = ProviderContainer();
      db = AppDatabase(container.read(_ref), NativeDatabase.memory());
    });
    tearDown(() async {
      await db.close();
      container.dispose();
    });
    test('empty success persists, scope isolation and configurable expiry',
        () async {
      var clock = now;
      final cache = DiscoveryCache(
          db, 'server:user:seerr:fr', const Duration(days: 7),
          clock: () => clock);
      await cache.write('list', {'items': []});
      clock = now.add(const Duration(days: 6));
      expect((await cache.read('list'))!['items'], isEmpty);
      expect(
          await DiscoveryCache(db, 'other:user', const Duration(days: 7),
              clock: () => clock).read('list'),
          isNull);
      expect(
          await DiscoveryCache(
              db, 'server:user:seerr:fr', const Duration(days: 3),
              clock: () => clock).read('list'),
          isNull);
      clock = now.add(const Duration(days: 7));
      expect(await cache.read('list'), isNull);
    });
    test('list/details reused but availability rechecked on warm cache',
        () async {
      final calls = <String>[];
      var requested = false;
      final cache = DiscoveryCache(db, 'scope', const Duration(days: 7));
      DiscoveryClient makeClient() => DiscoveryClient(
          baseUrl: Uri.parse('https://seerr'),
          headers: {},
          interval: Duration.zero,
          client: MockClient((request) async {
            calls.add(request.url.path);
            if (request.url.path.endsWith('similar') ||
                request.url.path.endsWith('recommendations')) {
              return http.Response(
                  jsonEncode({
                    'results': [
                      {'id': 2}
                    ]
                  }),
                  200);
            }
            return http.Response(
                jsonEncode(
                    detail(2, mediaInfo: requested ? {'status': 2} : null)),
                200);
          }));
      Future<List<DiscoveryItem>> run() async {
        final client = makeClient();
        try {
          return await DiscoveryRepository(client, cache, 'fr').load(
              seeds: [seed],
              events: [event('1', WatchSignal.rewatched)],
              stats: stats,
              exclusions: exclusions);
        } finally {
          client.close();
        }
      }

      expect(await run(), hasLength(1));
      expect(calls.length, 3);
      requested = true;
      calls.clear();
      expect(await run(), isEmpty);
      expect(calls, ['/api/v1/movie/2']);
    });
    test('thirty seeds never exceed sixty lists plus sixty unique details',
        () async {
      var lists = 0;
      final detailed = <int>[];
      final client = DiscoveryClient(
          baseUrl: Uri.parse('https://seerr'),
          headers: {},
          interval: Duration.zero,
          client: MockClient((request) async {
            final parts = request.url.pathSegments;
            if (parts.last == 'similar' || parts.last == 'recommendations') {
              expect(request.url.queryParameters['page'], '1');
              final offset = lists++ * 20 + 100;
              return http.Response(
                  jsonEncode({
                    'results': [
                      for (var i = 0; i < 20; i++) {'id': offset + i}
                    ]
                  }),
                  200);
            }
            final id = int.parse(parts.last);
            detailed.add(id);
            return http.Response(
                jsonEncode({...detail(id), 'name': 'Series $id'}), 200);
          }));
      addTearDown(client.close);
      final result = await DiscoveryRepository(client,
              DiscoveryCache(db, 'budget', const Duration(days: 7)), 'fr')
          .load(seeds: [
        for (final type in ['movie', 'tv'])
          for (var i = 0; i < 15; i++) (type: type, id: i + 1)
      ], events: [
        event('1', WatchSignal.rewatched)
      ], stats: stats, exclusions: exclusions);
      expect(result, isNotEmpty);
      expect(lists, 60);
      expect(detailed, hasLength(60));
      expect(detailed.toSet(), hasLength(60));
    });
    test('429 worker failure preserves long cooldown across restarts',
        () async {
      final client = DiscoveryClient(
          baseUrl: Uri.parse('https://seerr'),
          headers: {},
          interval: Duration.zero,
          client: MockClient((_) async =>
              http.Response('', 429, headers: {'retry-after': '3600'})));
      addTearDown(client.close);
      var clock = DateTime.now();
      final cache = DiscoveryCache(db, 'rate', const Duration(days: 7),
          clock: () => clock);
      await expectLater(
          DiscoveryRepository(client, cache, 'fr').load(
              seeds: [seed],
              events: [event('1', WatchSignal.rewatched)],
              stats: stats,
              exclusions: exclusions),
          throwsA(isA<DiscoveryUnavailable>()));
      clock = clock.add(const Duration(minutes: 45));
      expect(await cache.read('backoff'), isNotNull);
    });
    test('network failure never falls back to cached eligible cards', () async {
      final cache = DiscoveryCache(db, 'scope', const Duration(days: 7));
      for (final endpoint in ['similar', 'recommendations']) {
        await cache.write('list:v1:${seed.identity}:$endpoint', {
          'items': [
            {'id': 2}
          ]
        });
      }
      await cache.write('detail:v1:${candidate.identity}',
          DiscoveryItem.fromDetails(candidate, detail(2)).toJson());
      final client = DiscoveryClient(
          baseUrl: Uri.parse('https://seerr'),
          headers: {},
          interval: Duration.zero,
          client: MockClient((_) async => http.Response('Unavailable', 502)));
      addTearDown(client.close);
      await expectLater(
          DiscoveryRepository(client, cache, 'fr').load(
              seeds: [seed],
              events: [event('1', WatchSignal.rewatched)],
              stats: stats,
              exclusions: exclusions),
          throwsA(isA<DiscoveryUnavailable>()));
      expect(await cache.read('backoff'), isNotNull);
    });
  });
  group('network budget and cancellation', () {
    test('bounds simultaneous requests and sends authentication in headers',
        () async {
      var active = 0;
      var maximum = 0;
      final client = DiscoveryClient(
          baseUrl: Uri.parse('https://seerr/prefix/'),
          headers: {'X-Api-Key': 'secret'},
          interval: Duration.zero,
          client: MockClient((request) async {
            expect(request.headers['X-Api-Key'], 'secret');
            expect(request.url.path, startsWith('/prefix/api/v1/'));
            expect(request.url.toString(), isNot(contains('secret')));
            active++;
            if (active > maximum) maximum = active;
            await Future<void>.delayed(const Duration(milliseconds: 5));
            active--;
            return http.Response('{}', 200);
          }));
      addTearDown(client.close);
      await client.map(
          List.generate(10, (i) => i), (id) => client.get('movie/$id'));
      expect(maximum, 2);
    });
    test('cancellation interrupts a hanging request and prevents queued work',
        () async {
      var calls = 0;
      final client = DiscoveryClient(
          baseUrl: Uri.parse('https://seerr'),
          headers: {},
          interval: Duration.zero,
          client: MockClient((_) {
            calls++;
            return Completer<http.Response>().future;
          }));
      final future = client.map(
          List.generate(10, (i) => i), (id) => client.get('movie/$id'));
      final expectation =
          expectLater(future, throwsA(isA<DiscoveryUnavailable>()));
      await Future<void>.delayed(const Duration(milliseconds: 5));
      client.close();
      await expectation;
      expect(calls, lessThanOrEqualTo(2));
      expect(client.failed, false);
    });
    test('429 long Retry-After stops the batch without early retry', () async {
      var calls = 0;
      final client = DiscoveryClient(
          baseUrl: Uri.parse('https://seerr'),
          headers: {},
          interval: Duration.zero,
          client: MockClient((_) async {
            calls++;
            return http.Response('', 429, headers: {'retry-after': '3600'});
          }));
      addTearDown(client.close);
      await expectLater(
          client.get('movie/1'), throwsA(isA<DiscoveryUnavailable>()));
      expect(calls, 1);
      expect(retryAfter('60', now), now.add(const Duration(seconds: 60)));
      expect(
          retryAfter(
              'Thu, 08 Oct 2026 12:00:00 GMT', DateTime.utc(2026, 10, 8)),
          DateTime.utc(2026, 10, 8, 12));
    });
    test(
        'Retry-After also postpones a worker already waiting in the pacing gate',
        () async {
      final watch = Stopwatch()..start();
      final times = <int>[];
      final client = DiscoveryClient(
          baseUrl: Uri.parse('https://seerr'),
          headers: {},
          interval: const Duration(milliseconds: 100),
          client: MockClient((_) async {
            times.add(watch.elapsedMilliseconds);
            if (times.length == 1) {
              await Future<void>.delayed(const Duration(milliseconds: 20));
              return http.Response('', 429, headers: {'retry-after': '1'});
            }
            return http.Response('{}', 200);
          }));
      addTearDown(client.close);
      await client.map([1, 2], (id) => client.get('movie/$id'));
      expect(times, hasLength(3));
      expect(times[1] - times[0], greaterThanOrEqualTo(1000));
    });
    test('requests timeout', () async {
      final client = DiscoveryClient(
          baseUrl: Uri.parse('https://seerr'),
          headers: {},
          interval: Duration.zero,
          timeout: const Duration(milliseconds: 5),
          client: MockClient((_) => Completer<http.Response>().future));
      addTearDown(client.close);
      await expectLater(
          client.get('movie/1'), throwsA(isA<TimeoutException>()));
    });
  });
}
