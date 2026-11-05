import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kinos/anilist/anilist_client.dart';
import 'package:kinos/anilist/anilist_progress.dart';
import 'package:kinos/anilist/episode_store.dart';
import 'package:kinos/models/syncing/database_item.dart';

void main() {
  late ProviderContainer c;
  late AppDatabase db;
  late EpisodeStore store;
  setUp(() {
    c = ProviderContainer();
    db = AppDatabase(c.read(Provider<Ref>((r) => r)), NativeDatabase.memory());
    store = EpisodeStore(db, 'p');
  });
  tearDown(() async {
    await db.close();
    c.dispose();
  });
  test('sync advances contiguously and acknowledges the durable job', () async {
    final writes = <Map>[];
    final client = AnilistClient(
        token: 'secret',
        interval: Duration.zero,
        client: MockClient((r) async {
          final j = jsonDecode(r.body) as Map;
          if ((j['query'] as String).startsWith('query')) {
            return http.Response(
                '{"data":{"MediaList":{"progress":5,"status":"CURRENT"}}}',
                200);
          }
          writes.add(j['variables'] as Map);
          return http.Response(
              '{"data":{"SaveMediaListEntry":{"mediaId":2,"progress":7,"status":"CURRENT"}}}',
              200);
        }));
    addTearDown(client.close);
    final worker = AnilistProgressWorker(
        store: store,
        accountId: 1,
        client: client,
        isCurrent: () => true,
        load: (_) async =>
            const ProgressSnapshot(mediaId: 2, watched: {6, 7, 9}, total: 24));
    await store.enqueue('e7', 1);
    await worker.drain();
    expect(writes.single['progress'], 7);
    expect(await store.pending(), isEmpty);
  });
  test('ambiguity and network failures stay queued; other accounts never drain',
      () async {
    final client = AnilistClient(
        token: 'secret',
        interval: Duration.zero,
        client: MockClient((_) async => http.Response('', 500)));
    addTearDown(client.close);
    var mapping = true;
    final worker = AnilistProgressWorker(
        store: store,
        accountId: 1,
        client: client,
        isCurrent: () => true,
        load: (_) async {
          if (mapping) throw const AnilistMappingNeeded();
          return const ProgressSnapshot(mediaId: 2, watched: {1}, total: 24);
        });
    await store.enqueue('e', 1);
    await store.enqueue('other', 2);
    await worker.drain();
    expect((await store.pending()).where((j) => j.accountId == 1).single.error,
        'mapping');
    mapping = false;
    await store.retryNow(1);
    await worker.drain();
    expect((await store.pending()).where((j) => j.accountId == 1).single.error,
        'network');
    expect(
        (await store.pending()).where((j) => j.accountId == 2).single.attempts,
        0);
  });
  test('paused status and ratings are preserved when advancing progress',
      () async {
    var mutations = 0;
    final client = AnilistClient(
        token: 'secret',
        interval: Duration.zero,
        client: MockClient((r) async {
          final j = jsonDecode(r.body) as Map;
          if ((j['query'] as String).startsWith('query')) {
            return http.Response(
                '{"data":{"MediaList":{"progress":5,"status":"PAUSED"}}}', 200);
          }
          mutations++;
          expect(j['variables'], {'mediaId': 2, 'progress': 6});
          expect(j['query'], isNot(contains('status:')));
          expect(j['query'], isNot(contains('score')));
          return http.Response(
              '{"data":{"SaveMediaListEntry":{"mediaId":2,"progress":6,"status":"PAUSED"}}}',
              200);
        }));
    addTearDown(client.close);
    final worker = AnilistProgressWorker(
        store: store,
        accountId: 1,
        client: client,
        isCurrent: () => true,
        load: (_) async =>
            const ProgressSnapshot(mediaId: 2, watched: {6}, total: 6));
    await store.enqueue('e', 1);
    await worker.drain();
    expect(mutations, 1);
  });
  test('mapping failures stop retrying hourly after a few attempts', () async {
    final client = AnilistClient(
        token: 'secret',
        interval: Duration.zero,
        client: MockClient((_) async => http.Response('', 500)));
    addTearDown(client.close);
    final worker = AnilistProgressWorker(
        store: store,
        accountId: 1,
        client: client,
        isCurrent: () => true,
        load: (_) async => throw const AnilistMappingNeeded());
    await store.enqueue('e', 1);
    // The job already failed three times: it must back off instead of retrying
    // every hour forever on a title nobody mapped.
    final key = 'job:1:e';
    final row = await db.getSetting(key, scope: store.scope);
    final raw = jsonDecode(row!.value) as Map<String, dynamic>;
    raw['attempts'] = 3;
    raw['nextAt'] = DateTime.now()
        .toUtc()
        .subtract(const Duration(minutes: 1))
        .toIso8601String();
    await db.setSetting(key, jsonEncode(raw), scope: store.scope);
    await worker.drain();
    final job = (await store.pending()).single;
    expect(job.error, 'mapping');
    expect(job.nextAt.difference(DateTime.now()).inDays, greaterThanOrEqualTo(6));
  });
  test('switching profiles during a load prevents the mutation', () async {
    var active = true;
    var requests = 0;
    final client = AnilistClient(
        token: 'secret',
        interval: Duration.zero,
        client: MockClient((_) async {
          requests++;
          return http.Response('', 500);
        }));
    addTearDown(client.close);
    final worker = AnilistProgressWorker(
        store: store,
        accountId: 1,
        client: client,
        isCurrent: () => active,
        load: (_) async {
          active = false;
          return const ProgressSnapshot(mediaId: 2, watched: {1}, total: 24);
        });
    await store.enqueue('e', 1);
    await worker.drain();
    expect(requests, 0);
    expect(await store.pending(), hasLength(1));
  });
}
