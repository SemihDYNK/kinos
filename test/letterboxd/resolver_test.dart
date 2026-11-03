import 'package:kinos/letterboxd/letterboxd_model.dart';
import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kinos/models/syncing/database_item.dart';
import 'package:kinos/letterboxd/letterboxd_import_controller.dart';
import 'package:kinos/letterboxd/letterboxd_store.dart';
import 'package:kinos/recommendations/seerr/discovery_client.dart';
import 'package:kinos/letterboxd/letterboxd_matching.dart';
import 'parser_test.dart' show exportZip;

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late LetterboxdStore store;
  setUp(() {
    container = ProviderContainer();
    db = AppDatabase(
        container.read(Provider<Ref>((r) => r)), NativeDatabase.memory());
    store = LetterboxdStore(db, 'a');
  });
  tearDown(() async {
    await db.close();
    container.dispose();
  });
  final bytes = exportZip({
    'ratings.csv':
        'Date,Name,Year,Letterboxd URI,Rating\n2026-01-01,A,2000,https://boxd.it/a,5\n'
  });
  Map<String, dynamic> detail(int id) => {
        'id': id,
        'title': 'A',
        'releaseDate': '2000-01-01',
        'genres': [
          {'name': 'Drama'}
        ]
      };
  test('search encodes reserved title characters as required by Seerr',
      () async {
    const title = 'Toy Story 2: L’été & +';
    final client = DiscoveryClient(
        baseUrl: Uri.parse('https://seerr.test'),
        headers: {},
        interval: Duration.zero,
        client: MockClient((request) async {
          expect(
              request.url.queryParameters['query'], Uri.encodeComponent(title));
          return http.Response('{"results":[]}', 200);
        }));
    addTearDown(client.close);
    await LetterboxdResolver(client).search(const LetterboxdFilm(
        uri: 'https://boxd.it/test', title: title, year: 1999));
  });
  test('direct detail', () async {
    final client = DiscoveryClient(
        baseUrl: Uri.parse('https://seerr.test'),
        headers: {},
        interval: Duration.zero,
        client: MockClient(
            (_) async => http.Response(jsonEncode(detail(42)), 200)));
    addTearDown(client.close);
    await LetterboxdResolver(client).details(42);
  });
  test('outside-library movie is enriched through Seerr and reused on reimport',
      () async {
    var calls = 0;
    final c = LetterboxdImportController(
        store: store,
        loadLibrary: () async => [],
        isCurrent: () => true,
        createClient: () => DiscoveryClient(
            baseUrl: Uri.parse('https://seerr.test'),
            headers: {},
            interval: Duration.zero,
            client: MockClient((request) async {
              calls++;
              return http.Response(
                  jsonEncode(request.url.path.endsWith('/search')
                      ? {
                          'results': [
                            {
                              'id': 42,
                              'mediaType': 'movie',
                              'title': 'A',
                              'releaseDate': '2000-01-01'
                            }
                          ]
                        }
                      : detail(42)),
                  200);
            })));
    addTearDown(c.dispose);
    await c.prepare(bytes);
    expect(c.state.records.single.work!.tmdbId, 42);
    expect(c.state.matched, 1);
    expect(calls, 2);
    await c.commit();
    await c.prepare(bytes);
    expect(calls, 2);
    expect(c.state.matched, 1);
  });
  test('ambiguous search requires explicit selection before details are used',
      () async {
    final c = LetterboxdImportController(
        store: store,
        loadLibrary: () async => [],
        isCurrent: () => true,
        createClient: () => DiscoveryClient(
            baseUrl: Uri.parse('https://seerr.test'),
            headers: {},
            interval: Duration.zero,
            client: MockClient((request) async => http.Response(
                jsonEncode(request.url.path.endsWith('/search')
                    ? {
                        'results': [
                          for (final id in [1, 2])
                            {
                              'id': id,
                              'mediaType': 'movie',
                              'title': 'A',
                              'releaseDate': '2000-01-01'
                            }
                        ]
                      }
                    : detail(int.parse(request.url.pathSegments.last))),
                200))));
    addTearDown(c.dispose);
    await c.prepare(bytes);
    expect(c.state.records.single.work, isNull);
    await c.choose(0, 'tmdb:movie:2');
    expect(c.state.records.single.work!.tmdbId, 2);
    expect(c.state.matched, 1);
  });
  test('network failure produces an explicit partial preview, not a save',
      () async {
    final c = LetterboxdImportController(
        store: store,
        loadLibrary: () async => [],
        isCurrent: () => true,
        createClient: () => DiscoveryClient(
            baseUrl: Uri.parse('https://seerr.test'),
            headers: {},
            interval: Duration.zero,
            client: MockClient((_) async => http.Response('', 503))));
    addTearDown(c.dispose);
    await c.prepare(bytes);
    expect(c.state.ready, isTrue);
    expect(c.state.networkWarning, isTrue);
    expect(c.state.records.single.work, isNull);
    expect((await store.read()).records, isEmpty);
  });
}
