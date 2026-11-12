import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kinos/letterboxd/friends/letterboxd_friends_client.dart';

void main() {
  test('a film the user opens jumps ahead of background sync', () async {
    final order = <String>[];
    final client = LetterboxdFriendsClient(
        spacing: const Duration(milliseconds: 5),
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
}
