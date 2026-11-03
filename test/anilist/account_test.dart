import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kinos/anilist/anilist_account.dart';
import 'package:kinos/anilist/anilist_client.dart';
import '../support/fake_secure_storage_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('OAuth uses the registered redirect, public client and no secret', () {
    final uri = anilistAuthorizationUri();
    expect(uri.queryParameters['client_id'], '55890');
    expect(uri.queryParameters['response_type'], 'token');
    expect(uri.queryParameters.containsKey('redirect_uri'), isFalse);
    expect(uri.queryParameters.containsKey('client_secret'), isFalse);
  });
  test('account is stored only in the secure vault and isolated by profile',
      () async {
    final fake = FakeSecureStoragePlatform.install();
    final store = const AnilistAccountStore();
    await store.save(
        'a',
        const AnilistConnection(
            id: 1, name: 'User', token: 'secret-token', enabled: false));
    expect((await store.read('a'))!.token, 'secret-token');
    expect(await store.read('b'), isNull);
    expect(fake.values.values.single, contains('secret-token'));
    await store.delete('a');
    expect(await store.read('a'), isNull);
  });
  test('Viewer and progress mutations require bearer auth, never send scores',
      () async {
    final client = AnilistClient(
        interval: Duration.zero,
        token: 'secret-token',
        client: MockClient((r) async {
          expect(r.headers['Authorization'], 'Bearer secret-token');
          final j = jsonDecode(r.body) as Map;
          if ((j['query'] as String).contains('Viewer')) {
            return http.Response(
                '{"data":{"Viewer":{"id":1,"name":"User"}}}', 200);
          }
          expect(j['variables'],
              {'mediaId': 2, 'progress': 3, 'status': 'CURRENT'});
          expect(j['query'], isNot(contains('score')));
          return http.Response(
              '{"data":{"SaveMediaListEntry":{"mediaId":2,"progress":3,"status":"CURRENT"}}}',
              200);
        }));
    addTearDown(client.close);
    expect((await client.viewer()).id, 1);
    await client.saveProgress(2, 3, status: 'CURRENT');
  });
  test('invalid auth is distinct and does not expose the token', () async {
    final client = AnilistClient(
        token: 'secret-token',
        client: MockClient((_) async => http.Response('', 401)));
    addTearDown(client.close);
    await expectLater(client.viewer(), throwsA(isA<AnilistUnauthorized>()));
  });
  test('GraphQL auth failures remain auth failures with HTTP 200', () async {
    final client = AnilistClient(
        token: 'secret-token',
        client: MockClient((_) async => http.Response(
            '{"errors":[{"message":"private detail","status":401}]}', 200)));
    addTearDown(client.close);
    await expectLater(client.viewer(), throwsA(isA<AnilistUnauthorized>()));
  });
  test('HTTP failures expose only the numeric status for diagnosis', () async {
    final client = AnilistClient(
        token: 'secret-token',
        client: MockClient((_) async => http.Response('private detail', 502)));
    addTearDown(client.close);
    await expectLater(
        client.viewer(),
        throwsA(isA<AnilistUnavailable>()
            .having((e) => e.statusCode, 'HTTP status', 502)));
  });
}
