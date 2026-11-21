import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/letterboxd/friends/letterboxd_friends_client.dart';
import 'package:kinos/letterboxd/friends/letterboxd_friends_parser.dart';
import 'package:kinos/letterboxd/friends/letterboxd_friends_store.dart';
import 'package:kinos/letterboxd/friends/letterboxd_friends_sync.dart';
import 'package:kinos/letterboxd/friends/letterboxd_reviews.dart';
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

  final reviewPages = <String, List<List<LetterboxdReview>>>{};

  @override
  Future<LetterboxdPage<List<LetterboxdReview>>> reviews(
      String username, int page) async {
    requested.add('reviews:$username:$page');
    final list = reviewPages[username] ?? const [];
    return LetterboxdPage(page <= list.length ? list[page - 1] : const [],
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

    test('your profile picture is read from your public page', () {
      const photo =
          'https://a.ltrbxd.com/resized/avatar/upload/8/8/shard/avtr-0-220-0-220-crop.jpg?v=abc';
      expect(parseProfileAvatar('<a><img src="$photo" alt="Me" /></a>'), photo);
      expect(
          parseProfileAvatar(
              '<img src="https://s.ltrbxd.com/static/img/avatar220.png" alt="Me" />'),
          isNull,
          reason: 'the default picture says nothing');
    });

    test('an account keeps its picture through storage', () {
      final account = LetterboxdFriendsAccount.fromJson(
          const LetterboxdFriendsAccount(
                  username: 'me', friendCount: 3, avatarUrl: 'https://x/a.jpg')
              .toJson());
      expect((account!.username, account.friendCount, account.avatarUrl),
          ('me', 3, 'https://x/a.jpg'));
      expect(LetterboxdFriendsAccount.fromJson({'u': 'me'})!.avatarUrl, isNull);
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

    test('a sync keeps your profile picture', () async {
      await store.saveAccount(const LetterboxdFriendsAccount(
          username: 'me', avatarUrl: 'https://x/a.jpg'));
      final client = FakeClient([friend('ana')], {});
      await LetterboxdFriendsSync(client, store)
          .run('me', cancelled: () => false);
      final account = await store.account();
      expect(account!.avatarUrl, 'https://x/a.jpg');
      expect(account.friendCount, 1);
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
      expect(client.requested.where((r) => !r.startsWith('reviews:')),
          ['me:1', 'ana:1', 'ana:2']);
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

  group('reviews', () {
    const html = '''
<article class="production-viewing -viewing" data-owner="ana" data-object-id="viewing:42" data-object-name="review"> <div class="react-component figure" data-item-slug="dune-part-two" data-item-link="/film/dune-part-two/"></div>
<div class="body"><h2 class="primaryname prettify"><a href="/ana/film/dune-part-two/">Dune</a></h2>
<span class="inline-rating"><svg class="glyph -rating" width="38" aria-label="★★★★½"><title>★★★★½</title></svg></span>
<span class="date"><time class="timestamp" datetime="2026-03-02">2 Mar 2026</time></span>
<div class="js-review "><div class="body-text -prose -reset js-review-body js-collapsible-text" data-full-text-url="/s/full-text/viewing:42/"><div class="collapsed-text"><p>Sand &amp; spice.</p><p>Second paragraph…</p></div></div>
<div class="viewing-actions"><p class="like-link-target" data-format="count" data-count="12"></p></div></div></article>
<article class="production-viewing -viewing" data-owner="ana" data-object-id="viewing:7" data-object-name="review"> <div class="react-component figure" data-item-slug="mouse"></div>
<div class="js-review "><p class="body-text -prose js-spoiler-container"><em>This review may contain spoilers.</em></p><div class="body-text -prose -reset js-review-body js-collapsible-text" hidden><p>The end.</p></div>
<div class="viewing-actions"></div></div></article>
<div class="paginate-nextprev"><a class="next" href="/ana/reviews/page/2/">Next</a></div>
''';

    test('a reviews page: slug, stars, date, likes, text, spoilers', () {
      final page = parseReviewsPage(html);
      expect(page.hasNext, isTrue);
      final dune = page.items.first;
      expect(dune.id, '42');
      expect(dune.slug, 'dune-part-two');
      expect(dune.rating, 9);
      expect(dune.date, DateTime(2026, 3, 2));
      expect(dune.likes, 12);
      expect(dune.excerpt, 'Sand & spice.\n\nSecond paragraph…');
      expect(dune.truncated, isTrue);
      expect(dune.path, '/ana/film/dune-part-two/');
      final mouse = page.items.last;
      expect(mouse.spoilers, isTrue);
      expect(mouse.excerpt, 'The end.');
      expect(mouse.truncated, isFalse);
      expect(LetterboxdReview.fromJson(dune.toJson())!.excerpt, dune.excerpt);
    });

    late AppDatabase db;
    setUp(() {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      db = AppDatabase(
          container.read(Provider<Ref>((ref) => ref)), NativeDatabase.memory());
    });
    tearDown(() => db.close());

    test('reviews: later passes stop at the first page with nothing new',
        () async {
      final client = FakeClient([friend('ana')], {});
      LetterboxdReview r(String id, String slug) =>
          LetterboxdReview(id: id, slug: slug, excerpt: 'x');
      client.reviewPages['ana'] = [
        [r('3', 'c'), r('2', 'b')],
        [r('1', 'a')],
      ];
      final store = LetterboxdFriendsStore(db, 'P');
      final sync = LetterboxdFriendsSync(client, store);
      await sync.syncReviews(friend('ana'), cancelled: () => false);
      expect((await store.reviews('ana'))!.reviews.keys,
          unorderedEquals(['a', 'b', 'c']));
      client.reviewPages['ana'] = [
        [r('4', 'd'), r('3', 'c')],
        [r('2', 'b')],
        [r('1', 'a')],
      ];
      client.requested.clear();
      await sync.syncReviews(friend('ana'), cancelled: () => false);
      // Page 1 a du neuf, page 2 rien : on s'arrête là.
      expect(client.requested, ['reviews:ana:1', 'reviews:ana:2']);
      expect((await store.reviewsIndex())['d']!['ana']!.id, '4');
    });
  });
}
