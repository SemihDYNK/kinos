import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kinos/anilist/anilist_client.dart';

void main() {
  test('uses GraphQL variables, validates ANIME and MAL identities', () async {
    final client = AnilistClient(
        interval: Duration.zero,
        client: MockClient((r) async {
          final request = jsonDecode(r.body) as Map;
          expect(r.method, 'POST');
          expect(request['query'], contains('ANIME'));
          expect(request['variables'], {'id': null, 'malId': 1535});
          return http.Response(
              jsonEncode({
                'data': {
                  'Media': {
                    'id': 1535,
                    'idMal': 1535,
                    'type': 'ANIME',
                    'title': {'romaji': 'Death Note'}
                  }
                }
              }),
              200);
        }));
    addTearDown(client.close);
    expect((await client.media(malId: 1535))!.title, 'Death Note');
  });
  test('distinguishes missing media from GraphQL and HTTP failures', () async {
    for (final response in [
      http.Response('{"errors":[{"message":"bad"}]}', 200),
      http.Response('bad', 500),
      http.Response('bad', 200)
    ]) {
      final c = AnilistClient(
          interval: Duration.zero, client: MockClient((_) async => response));
      await expectLater(c.media(id: 1), throwsA(isA<AnilistUnavailable>()));
      c.close();
    }
    final c =
        AnilistClient(client: MockClient((_) async => http.Response('', 404)));
    expect(await c.media(id: 1), isNull);
    c.close();
  });
  test('respects a rate limit and exposes retry time instead of looping',
      () async {
    var requests = 0;
    final c = AnilistClient(
        interval: Duration.zero,
        client: MockClient((_) async {
          requests++;
          return http.Response('', 429, headers: {'retry-after': '60'});
        }));
    addTearDown(c.close);
    await expectLater(
        c.media(id: 1),
        throwsA(isA<AnilistUnavailable>()
            .having((e) => e.retryAt, 'retry time', isNotNull)));
    await expectLater(c.media(id: 2), throwsA(isA<AnilistUnavailable>()));
    expect(requests, 1);
  });
  test('rejects other media types and supports search without auto-selecting',
      () async {
    final c = AnilistClient(
        interval: Duration.zero,
        client: MockClient((_) async => http.Response(
            '{"data":{"Page":{"media":[{"id":1,"type":"ANIME","title":{"english":"A"}},{"id":2,"type":"MANGA"}]}}}',
            200)));
    addTearDown(c.close);
    expect((await c.search('A')).map((e) => e.id), [1]);
  });
  test('timeout aborts the actual request before another can start', () async {
    final transport = _AbortClient();
    final c = AnilistClient(
        client: transport,
        interval: Duration.zero,
        timeout: const Duration(milliseconds: 10));
    addTearDown(c.close);
    final first = c.media(id: 1);
    final checked = expectLater(first, throwsA(isA<AnilistUnavailable>()));
    final second = c.media(id: 2);
    await checked;
    expect((await second)!.id, 2);
    expect(transport.aborted, isTrue);
    expect(transport.maxActive, 1);
  });
  test('a response for the wrong identity cannot establish a link', () async {
    final c = AnilistClient(
        interval: Duration.zero,
        client: MockClient((_) async =>
            http.Response('{"data":{"Media":{"id":2,"type":"ANIME"}}}', 200)));
    addTearDown(c.close);
    await expectLater(c.media(id: 1), throwsA(isA<AnilistUnavailable>()));
  });
  test('close cancels queued and active work; timeout is surfaced', () async {
    final c = AnilistClient(
        interval: Duration.zero,
        timeout: const Duration(milliseconds: 5),
        client: MockClient((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return http.Response('{}', 200);
        }));
    await expectLater(c.media(id: 1), throwsA(isA<AnilistUnavailable>()));
    c.close();
    await expectLater(c.media(id: 2), throwsA(isA<AnilistUnavailable>()));
  });
}

class _AbortClient extends http.BaseClient {
  int active = 0;
  int maxActive = 0;
  bool aborted = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    active++;
    if (active > maxActive) maxActive = active;
    if (jsonDecode((request as http.Request).body)['variables']['id'] == 1) {
      final done = Completer<http.StreamedResponse>();
      (request as http.Abortable).abortTrigger!.then((_) {
        aborted = true;
        active--;
        done.completeError(http.ClientException('aborted'));
      });
      return done.future;
    }
    active--;
    return http.StreamedResponse(
        Stream.value(utf8.encode('{"data":{"Media":{"id":2,"type":"ANIME"}}}')),
        200);
  }
}
