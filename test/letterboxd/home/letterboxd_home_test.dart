import 'package:chopper/chopper.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:kinos/jellyfin/jellyfin_open_api.swagger.dart';
import 'package:kinos/letterboxd/friends/letterboxd_friends_client.dart';
import 'package:kinos/letterboxd/friends/letterboxd_friends_parser.dart';
import 'package:kinos/letterboxd/friends/letterboxd_friends_store.dart';
import 'package:kinos/letterboxd/home/letterboxd_home.dart';
import 'package:kinos/letterboxd/home/letterboxd_home_providers.dart';
import 'package:kinos/letterboxd/letterboxd_model.dart';
import 'package:kinos/letterboxd/letterboxd_providers.dart';
import 'package:kinos/models/item_base_model.dart';
import 'package:kinos/models/items/movie_model.dart';
import 'package:kinos/models/syncing/database_item.dart';
import 'package:kinos/providers/api_provider.dart';
import 'package:kinos/providers/database_provider.dart';
import 'package:kinos/providers/service_provider.dart';

LetterboxdFriend friend(String u) => LetterboxdFriend(username: u, name: u);
FriendRating rated(String u, int r) => (friend: friend(u), rating: r);

LetterboxdFilmPage film(String slug, String tmdb,
        {int year = 2000, bool movie = true}) =>
    LetterboxdFilmPage(
        slug: slug, tmdbId: tmdb, isMovie: movie, title: slug, year: year);

class FakeClient extends LetterboxdFriendsClient {
  FakeClient() : super(spacing: Duration.zero);
  final lists = <String, List<List<String>>>{};
  final films = <String, LetterboxdFilmPage?>{};
  final requested = <String>[];
  final failing = <String>{};

  @override
  Future<LetterboxdPage<List<String>>> slugList(String path, int page) async {
    requested.add('$path#$page');
    if (failing.contains(path)) throw const LetterboxdUnavailable(503);
    final pages = lists[path] ?? const [];
    return LetterboxdPage(page <= pages.length ? pages[page - 1] : const [],
        hasNext: page < pages.length);
  }

  @override
  Future<LetterboxdFilmPage?> film(String slug) async {
    requested.add('film:$slug');
    return films[slug];
  }
}

AppDatabase memoryDb() {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  final db = AppDatabase(
      container.read(Provider<Ref>((ref) => ref)), NativeDatabase.memory());
  addTearDown(db.close);
  return db;
}

void main() {
  group('choosing films', () {
    test('friends: enthusiastic friends first, never a watched film', () {
      final picks = friendPicks({
        'ikiru': [rated('a', 10), rated('b', 8)],
        'heat': [rated('a', 9)],
        'meh': [rated('a', 6), rated('b', 7)],
        'seen': [rated('a', 10), rated('b', 10)],
        'split': [rated('a', 8), rated('b', 2)],
      }, {
        'seen'
      });
      expect(picks, ['ikiru', 'heat', 'split']);
    });

    test('daily pick: stable within a day, unwatched only', () {
      final slugs = [for (var i = 0; i < 500; i++) 'f$i'];
      final day = DateTime(2026, 11, 12, 9);
      final pick = dailyPick(slugs, {'f1', 'f2'}, day);
      expect(pick, hasLength(topDailyCount));
      expect(pick, dailyPick(slugs, {'f1', 'f2'}, DateTime(2026, 11, 12, 23)));
      expect(
          pick, isNot(dailyPick(slugs, {'f1', 'f2'}, DateTime(2026, 11, 13))));
      expect(pick.toSet().intersection({'f1', 'f2'}), isEmpty);
    });
  });

  group('rotation', () {
    final slugs = [for (var i = 0; i < 100; i++) 'f$i'];

    test('same draw for three days, a new one afterwards', () {
      final monday = DateTime(2026, 11, 9, 8);
      final draw = rotationPick(slugs, monday, count: 10, salt: 2);
      expect(draw, hasLength(10));
      final period = rotationIndex(monday, rotationPeriod);
      for (var day = 0; day < 6; day++) {
        final when = monday.add(Duration(days: day, hours: 12));
        final same = rotationIndex(when, rotationPeriod) == period;
        expect(rotationPick(slugs, when, count: 10, salt: 2).join(),
            same ? draw.join() : isNot(draw.join()));
      }
    });

    test('weighted draw favours the best ranked without fixing the row', () {
      var firstHalf = 0, total = 0;
      final draws = <String>{};
      for (var period = 0; period < 200; period++) {
        final when = DateTime(2026).add(Duration(days: period * 3));
        final draw = weightedRotationPick(slugs.take(40).toList(), when,
            count: 8, salt: 1);
        expect(draw.toSet(), hasLength(8));
        draws.add(draw.join(','));
        for (final slug in draw) {
          total++;
          if (int.parse(slug.substring(1)) < 20) firstHalf++;
        }
      }
      expect(firstHalf / total, greaterThan(.6));
      expect(draws.length, greaterThan(150));
    });
  });

  group('parsing', () {
    test('poster lists keep page order and pagination', () {
      final page = parseSlugListPage(
          '<div data-item-slug="ikiru"></div><div data-item-slug="heat"></div>'
          '<div data-item-slug="ikiru"></div><a class="next" href="/x/page/2/">');
      expect(page.items, ['ikiru', 'heat']);
      expect(page.hasNext, isTrue);
    });

    test('film page: TMDB id, type, title, year and poster', () {
      const html =
          '<meta property="og:url" content="https://letterboxd.com/film/ikiru/" />'
          '<body data-tmdb-type="movie" data-tmdb-id="3782">'
          '<script type="application/ld+json"> /* <![CDATA[ */ {"director":[{"@type":"Person","name":"Akira Kurosawa"}],"image":"https:\\/\\/a.ltrbxd.com\\/ikiru.jpg","name":"Ikiru","dateCreated":"1952-10-09","@type":"Movie"} /* ]]> */ </script>';
      final film = parseFilmPage(html)!;
      expect((film.slug, film.tmdbId, film.isMovie, film.title, film.year),
          ('ikiru', '3782', true, 'Ikiru', 1952));
      expect(film.posterUrl, 'https://a.ltrbxd.com/ikiru.jpg');
      expect(
          parseFilmPage(html.replaceAll(
                  'data-tmdb-type="movie"', 'data-tmdb-type="tv"'))!
              .isMovie,
          isFalse);
      expect(parseFilmPage('<html></html>', slug: 'x'), isNull);
    });
  });

  group('refresh', () {
    test('builds the lists, resolves only shown films, and caches them',
        () async {
      final store = LetterboxdHomeStore(memoryDb(), 'p');
      final client = FakeClient()
        ..lists['me/films/by/date/'] = [
          ['seen']
        ]
        ..lists['me/watchlist/'] = [
          ['w1', 'seen'],
          ['w2']
        ]
        ..lists[top500Path] = [
          ['t1', 't2', 'seen']
        ];
      for (final slug in ['w1', 'w2', 't1', 't2', 'ikiru']) {
        client.films[slug] = film(slug, slug.hashCode.toString());
      }
      final now = DateTime(2026, 11, 12);
      final lists =
          await LetterboxdHomeRefresh(client, store, now: now).run('me',
              friendsIndex: {
                'ikiru': [rated('a', 9)],
                'seen': [rated('a', 10)]
              },
              cancelled: () => false);
      expect(lists.friends, ['ikiru']);
      expect(lists.watchlist.toSet(), {'w1', 'seen', 'w2'});
      expect(lists.top.toSet(), {'t1', 't2'});
      expect(client.requested.where((r) => r.startsWith('film:')).toSet(), {
        'film:ikiru',
        'film:w1',
        'film:w2',
        'film:t1',
        'film:t2',
        'film:seen'
      });

      client.requested.clear();
      final again = await LetterboxdHomeRefresh(client, store,
              now: now.add(const Duration(hours: 1)))
          .run('me', friendsIndex: const {}, cancelled: () => false);
      expect(client.requested, isEmpty, reason: 'everything is still fresh');
      expect(again.friends, ['ikiru']);
    });

    test('one failing list keeps the others and its own cache', () async {
      final store = LetterboxdHomeStore(memoryDb(), 'p');
      await store.saveList('watchlist', ['old'], at: DateTime(2026, 1, 1));
      final client = FakeClient()
        ..failing.add('me/watchlist/')
        ..lists[top500Path] = [
          ['t1']
        ];
      final lists = await LetterboxdHomeRefresh(client, store,
              now: DateTime(2026, 11, 12))
          .run('me', friendsIndex: const {}, cancelled: () => false);
      expect(lists.watchlist, ['old']);
      expect(lists.top, ['t1']);
    });
  });

  test('films seen in the Letterboxd import are never recommended', () async {
    final db = memoryDb();
    final store = LetterboxdHomeStore(db, 'p');
    await store.saveList('friends', ['by-id', 'by-title', 'fresh'],
        at: DateTime.now());
    await store.saveList('watched', const [], at: DateTime.now());
    await store.saveFilm('by-id', film('by-id', '10'));
    await store.saveFilm('by-title', film('Seven', '11', year: 1995));
    await store.saveFilm('fresh', film('fresh', '12'));
    await LetterboxdFriendsStore(db, 'p')
        .saveAccount(const LetterboxdFriendsAccount(username: 'me'));
    final container = ProviderContainer(overrides: [
      letterboxdScopeProvider.overrideWith((ref) => 'p'),
      appDatabaseProvider.overrideWithValue(db),
      jellyApiProvider.overrideWith(() => _Api(_Library(const []))),
      letterboxdSnapshotProvider
          .overrideWith((ref) => const AsyncData(LetterboxdSnapshot(records: [
                LetterboxdRecord(LetterboxdFilm(uri: 'a', title: 'Whatever'),
                    work: LetterboxdWork(title: 'x', tmdbId: 10, traits: [])),
                LetterboxdRecord(
                    LetterboxdFilm(uri: 'b', title: 'SEVEN', year: 1995)),
              ]))),
    ]);
    addTearDown(container.dispose);
    final rows = await container.read(letterboxdHomeRowsProvider.future);
    expect(rows.friends.map((e) => e.film.slug), ['fresh']);
  });

  test('the full watchlist keeps its order and counts what is loading',
      () async {
    final db = memoryDb();
    final store = LetterboxdHomeStore(db, 'p');
    await store.saveList('watchlist', ['a', 'b', 'c', 'd', 'e'],
        at: DateTime.now());
    await store.saveFilm('a', film('a', '1'));
    await store.saveFilm('b', film('b', '2'));
    await store.saveFilm('c', film('c', '3'));
    await store.saveFilm('d', null);
    await LetterboxdFriendsStore(db, 'p')
        .saveAccount(const LetterboxdFriendsAccount(username: 'me'));
    final container = ProviderContainer(overrides: [
      letterboxdScopeProvider.overrideWith((ref) => 'p'),
      appDatabaseProvider.overrideWithValue(db),
      jellyApiProvider.overrideWith(
          () => _Api(_Library([_movie('b', '2', played: false)]))),
    ]);
    addTearDown(container.dispose);
    final watchlist = await container.read(letterboxdWatchlistProvider.future);
    expect(watchlist.library.map((e) => e.film.slug), ['b']);
    expect(watchlist.request.map((e) => e.film.slug), ['a', 'c']);
    expect(watchlist.pending, 1,
        reason: 'e is not resolved yet; d has no page');
  });

  test('rows split the watchlist between library and requests', () async {
    final db = memoryDb();
    final store = LetterboxdHomeStore(db, 'p');
    final now = DateTime.now();
    await store.saveList('watchlist', ['owned', 'missing', 'played', 'show'],
        at: now);
    await store.saveFilm('owned', film('owned', '1'));
    await store.saveFilm('missing', film('missing', '2'));
    await store.saveFilm('played', film('played', '3'));
    await store.saveFilm('show', film('show', '4', movie: false));
    await LetterboxdFriendsStore(db, 'p')
        .saveAccount(const LetterboxdFriendsAccount(username: 'me'));

    final api = _Library([
      _movie('owned', '1', played: false),
      _movie('played', '3', played: true),
    ]);
    final container = ProviderContainer(overrides: [
      letterboxdScopeProvider.overrideWith((ref) => 'p'),
      appDatabaseProvider.overrideWithValue(db),
      jellyApiProvider.overrideWith(() => _Api(api)),
    ]);
    addTearDown(container.dispose);
    final rows = await container.read(letterboxdHomeRowsProvider.future);
    expect(rows.watchlistLibrary.map((e) => e.item!.id), ['owned']);
    expect(rows.watchlistRequest.map((e) => e.film.slug), ['missing']);
    expect(api.years.single, [2000]);
  });
}

ItemBaseModel _movie(String id, String tmdb, {required bool played}) =>
    MovieModel.fromBaseDto(
        BaseItemDto(
            id: id,
            name: id,
            providerIds: {'Tmdb': tmdb},
            userData: UserItemDataDto(played: played)),
        null);

class _Library implements JellyService {
  _Library(this.items);
  final List<ItemBaseModel> items;
  final years = <List<int>?>[];
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName != #itemsGet) {
      return super.noSuchMethod(invocation);
    }
    years.add(invocation.namedArguments[#years] as List<int>?);
    return Future.value(
        Response(http.Response('', 200), ServerQueryResult(items: items)));
  }
}

class _Api extends JellyApi {
  _Api(this.api);
  final _Library api;
  @override
  JellyService build() => api;
}
