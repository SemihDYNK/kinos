import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kinos/letterboxd/friends/letterboxd_friends_client.dart';

void main() {
  test('a film the user opens jumps ahead of background sync', () async {
    final order = <String>[];
    final client = LetterboxdFriendsClient(
        spacing: const Duration(milliseconds: 5),
        backgroundSpacing: const Duration(milliseconds: 5),
        client: MockClient((request) async {
          order.add(request.url.path);
          return http.Response(
              request.url.path.startsWith('/tmdb/')
                  ? '<meta property="og:url" content="https://letterboxd.com/film/ikiru/" />'
                  : '',
              200);
        }));
    addTearDown(client.close);
    final background = [
      for (var page = 1; page <= 4; page++) client.ratings('ana', page)
    ];
    final slug = client.filmSlug('3782');
    expect(await slug, 'ikiru');
    await Future.wait(background);
    expect(order.indexOf('/tmdb/3782/'), lessThanOrEqualTo(1),
        reason: 'only the request already in flight may go first');
    expect(order, hasLength(5));
  });

  test('a 429 pauses every request until the pause ends', () async {
    var calls = 0;
    final client = LetterboxdFriendsClient(
        spacing: Duration.zero,
        backgroundSpacing: Duration.zero,
        client: MockClient((request) async {
          calls++;
          return http.Response('', 429, headers: {'retry-after': '120'});
        }));
    addTearDown(client.close);
    await expectLater(
        client.ratings('ana', 1), throwsA(isA<LetterboxdPaused>()));
    expect(client.pausedUntil, isNotNull);
    expect(client.pausedUntil!.difference(DateTime.now()).inSeconds,
        inInclusiveRange(100, 120));
    // Plus rien ne part pendant la pause, pas même une requête urgente.
    await expectLater(client.filmSlug('1'), throwsA(isA<LetterboxdPaused>()));
    await expectLater(
        client.following('ana'), throwsA(isA<LetterboxdPaused>()));
    expect(calls, 1);
  });

  test('a 403 without Retry-After pauses for the default pause', () async {
    final client = LetterboxdFriendsClient(
        spacing: Duration.zero,
        backgroundSpacing: Duration.zero,
        pause: const Duration(minutes: 30),
        client: MockClient((request) async => http.Response('', 403)));
    addTearDown(client.close);
    await expectLater(
        client.reviews('ana', 1), throwsA(isA<LetterboxdPaused>()));
    expect(client.pausedUntil!.difference(DateTime.now()).inMinutes,
        inInclusiveRange(29, 30));
  });
}
