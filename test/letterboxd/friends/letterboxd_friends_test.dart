import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/letterboxd/friends/letterboxd_friends_client.dart';
import 'package:kinos/letterboxd/friends/letterboxd_friends_parser.dart';
import 'package:kinos/letterboxd/friends/letterboxd_friends_store.dart';
import 'package:kinos/letterboxd/friends/letterboxd_friends_sync.dart';
import 'package:kinos/models/syncing/database_item.dart';

// Extraits fidèles à la structure de letterboxd.com (novembre 2026).
String followingRow(String user, String name, {bool defaultAvatar = false}) =>
    '<td class="col-member table-person"><div class="person-summary"> '
    '<a class="avatar -a40" href="/$user/" > <img src="${defaultAvatar ? 'https://s.ltrbxd.com/static/img/avatar80-x.png' : 'https://a.ltrbxd.com/$user.jpg'}" alt="$name" width="40" height="40" /> </a>'
    '<h3 class="title-3"><a href="/$user/" class="name">$name</a></h3></div></td>';

String ratedItem(String slug, int? rating) =>
    '<li class="griditem"><div class="react-component" data-item-slug="$slug" '
    'data-item-link="/film/$slug/"></div><p class="poster-viewingdata" '
    'data-item-uid="film:1">${rating == null ? '' : '<span class="rating -micro -darker rated-$rating">★</span>'}</p></li>';

const next =
    '<div class="paginate-nextprev"><a class="next" href="/x/page/2/">Next</a></div>';

class FakeClient extends LetterboxdFriendsClient {
  FakeClient(this.friends, this.pages) : super(spacing: Duration.zero);
  List<LetterboxdFriend>? friends;
  final Map<String, List<Map<String, int>>> pages;
  final requested = <String>[];

  @override
  Future<List<LetterboxdFriend>?> following(String username,
          {int maxPages = 40, bool Function()? cancelled}) async =>
      friends;

  @override
  Future<LetterboxdPage<Map<String, int>>> ratings(
      String username, int page) async {
    requested.add('$username:$page');
    final list = pages[username] ?? const [];
    return LetterboxdPage(page <= list.length ? list[page - 1] : const {},
        hasNext: page < list.length);
  }
}

LetterboxdFriend friend(String u) => LetterboxdFriend(username: u, name: u);

void main() {
  group('parsing public pages', () {
    test('following rows, default avatars and pagination', () {
      final page = parseFollowingPage(followingRow('ana', 'Ana &amp; Co') +
          followingRow('Bob_2', 'bob_2', defaultAvatar: true) +
          next);
      expect(page.items.map((f) => (f.username, f.name)),
          [('ana', 'Ana & Co'), ('bob_2', 'bob_2')]);
      expect(page.items.first.avatarUrl, 'https://a.ltrbxd.com/ana.jpg');
      expect(page.items.last.avatarUrl, isNull);
      expect(page.hasNext, isTrue);
      expect(parseFollowingPage(followingRow('ana', 'Ana')).hasNext, isFalse);
    });

    test('the profile owner in the page header is not a friend', () {
      final page = parseFollowingPage('<header>${followingRow('me', 'Me')}'
          '</header><table><tbody>${followingRow('ana', 'Ana')}</tbody></table>');
      expect(page.items.map((f) => f.username), ['ana']);
    });

    test('ratings keep only rated films, in half stars', () {
      final page = parseRatingsPage(ratedItem('ikiru', 10) +
          ratedItem('unrated', null) +
          ratedItem('dune-2021', 7));
      expect(page.items, {'ikiru': 10, 'dune-2021': 7});
      expect(letterboxdStars(7), '★★★½');
      expect(letterboxdStars(10), '★★★★★');
    });

    test('film slug from the page reached through /tmdb/', () {
      expect(
          filmSlugFromPage(
              '<meta property="og:url" content="https://letterboxd.com/film/ikiru/" />'),
          'ikiru');
      expect(filmSlugFromPage('<html></html>'), isNull);
    });

    test('usernames from a pseudo, a handle or a profile address', () {
      expect(normalizeLetterboxdUsername(' DavidEhrlich '), 'davidehrlich');
      expect(normalizeLetterboxdUsername('@ana_b'), 'ana_b');
      expect(normalizeLetterboxdUsername('https://letterboxd.com/ana_b/films/'),
          'ana_b');
      expect(normalizeLetterboxdUsername('not valid!'), isNull);
    });
  });

  group('sync', () {
    late AppDatabase db;
    late LetterboxdFriendsStore store;
    setUp(() {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      db = AppDatabase(
          container.read(Provider<Ref>((ref) => ref)), NativeDatabase.memory());
      store = LetterboxdFriendsStore(db, 'profile');
    });
    tearDown(() => db.close());

    test('first pass reads every page and builds the film index', () async {
      final client = FakeClient([
        friend('ana'),
        friend('bob')
      ], {
        'ana': [
          {'ikiru': 10, 'dune': 6},
          {'heat': 9}
        ],
        'bob': [
          {'ikiru': 7}
        ],
      });
      await LetterboxdFriendsSync(client, store)
          .run('me', cancelled: () => false);
      final index = await store.index();
      expect(index['ikiru']!.map((r) => (r.friend.username, r.rating)),
          unorderedEquals([('ana', 10), ('bob', 7)]));
      expect(index['heat']!.single.rating, 9);
      expect((await store.account())!.friendCount, 2);
    });

    test('my own ratings are kept apart from the friends index', () async {
      final client = FakeClient([
        friend('ana')
      ], {
        'me': [
          {'ikiru': 9}
        ],
        'ana': [
          {'ikiru': 10}
        ],
      });
      await LetterboxdFriendsSync(client, store)
          .run('me', cancelled: () => false);
      expect((await store.ratings('me'))!.ratings, {'ikiru': 9});
      expect((await store.index())['ikiru']!.map((r) => r.friend.username),
          ['ana']);
    });

    test('later passes stop at the first page with nothing new', () async {
      final pages = {
        'ana': [
          {'ikiru': 10},
          {'dune': 6},
          {'heat': 9}
        ]
      };
      final client = FakeClient([friend('ana')], pages);
      final sync = LetterboxdFriendsSync(client, store);
      await sync.run('me', cancelled: () => false);
      client.requested.clear();
      pages['ana'] = [
        {'new': 8, 'ikiru': 10},
        {'dune': 6},
        {'heat': 9}
      ];
      await sync.run('me', cancelled: () => false);
      expect(client.requested, ['me:1', 'ana:1', 'ana:2']);
      expect((await store.ratings('ana'))!.ratings,
          {'ikiru': 10, 'dune': 6, 'heat': 9, 'new': 8});
    });

    test('unfollowed friends are dropped; a missing profile is reported',
        () async {
      final client = FakeClient([
        friend('ana'),
        friend('bob')
      ], {
        'ana': [
          {'ikiru': 10}
        ],
        'bob': [
          {'ikiru': 4}
        ],
      });
      final sync = LetterboxdFriendsSync(client, store);
      await sync.run('me', cancelled: () => false);
      client.friends = [friend('ana')];
      await sync.run('me', cancelled: () => false);
      expect((await store.index())['ikiru']!.single.friend.username, 'ana');
      expect(await store.ratings('bob'), isNull);

      client.friends = null;
      expect(sync.run('me', cancelled: () => false),
          throwsA(isA<LetterboxdProfileNotFound>()));
    });

    test('a cancelled pass keeps what was already known', () async {
      final client = FakeClient([
        friend('ana')
      ], {
        'ana': [
          {'ikiru': 10}
        ]
      });
      await store.saveRatings('ana', const FriendRatings({'heat': 9}));
      var calls = 0;
      await LetterboxdFriendsSync(client, store)
          .run('me', cancelled: () => ++calls > 1);
      expect((await store.ratings('ana'))!.ratings, {'heat': 9});
      expect(await store.account(), isNull);
    });

    test('unknown films are asked again later, found ones are kept', () async {
      await store.saveSlug('1', null);
      await store.saveSlug('2', 'ikiru');
      expect(
          await store.slug('1', maxAge: const Duration(days: 7)), (slug: null));
      expect(await store.slug('1', maxAge: Duration.zero), isNull);
      expect(await store.slug('2', maxAge: Duration.zero), (slug: 'ikiru'));
    });
  });
}
