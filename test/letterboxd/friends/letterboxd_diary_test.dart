import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/letterboxd/friends/letterboxd_diary.dart';
import 'package:kinos/letterboxd/friends/letterboxd_friends_store.dart';
import 'package:kinos/letterboxd/friends/letterboxd_friends_sync.dart';
import 'package:kinos/letterboxd/letterboxd_model.dart';
import 'package:kinos/letterboxd/letterboxd_store.dart';
import 'package:kinos/models/syncing/database_item.dart';

// Extrait fidèle au flux RSS de letterboxd.com (novembre 2026).
String item(String guid, String slug, String title, String date,
        {int? tmdb, String? rating, bool rewatch = false}) =>
    '<item> <title>$title</title> '
    '<link>https://letterboxd.com/me/film/$slug/</link> '
    '<guid isPermaLink="false">$guid</guid> '
    '<letterboxd:watchedDate>$date</letterboxd:watchedDate> '
    '<letterboxd:rewatch>${rewatch ? 'Yes' : 'No'}</letterboxd:rewatch> '
    '<letterboxd:filmTitle>$title</letterboxd:filmTitle> '
    '<letterboxd:filmYear>2025</letterboxd:filmYear> '
    '${rating == null ? '' : '<letterboxd:memberRating>$rating</letterboxd:memberRating> '}'
    '${tmdb == null ? '' : '<tmdb:movieId>$tmdb</tmdb:movieId> '}'
    '<description><![CDATA[ <p>x</p> ]]></description> </item>';

String feed(List<String> items) =>
    '<?xml version="1.0"?><rss><channel><title>Letterboxd - me</title>'
    '${items.join()}'
    // Une liste publiée : pas une entrée du journal.
    '<item> <title>Ma liste</title> <link>https://letterboxd.com/me/list/x/</link> '
    '<guid isPermaLink="false">letterboxd-list-1</guid> </item>'
    '</channel></rss>';

class FakeLibrary implements LetterboxdDiaryLibrary {
  FakeLibrary(this.library);
  final Map<int, LetterboxdLibraryMovie> library;
  final marked = <(String, DateTime)>[];

  @override
  Future<Map<int, LetterboxdLibraryMovie>> movies(Set<int> tmdbIds) async => {
        for (final e in library.entries)
          if (tmdbIds.contains(e.key)) e.key: e.value
      };

  @override
  Future<List<LetterboxdWork>> works(List<String> ids) async => [
        for (final e in library.entries)
          if (ids.contains(e.value.id))
            LetterboxdWork(
                title: 'J${e.key}',
                tmdbId: e.key,
                jellyfinId: e.value.id,
                traits: const [])
      ];

  @override
  Future<void> markPlayed(String id, DateTime watchedOn) async =>
      marked.add((id, watchedOn));
}

void main() {
  test('parses diary entries and skips lists', () {
    final entries = parseLetterboxdDiary(feed([
      item('letterboxd-review-2', 'the-film-2025', 'Tom &amp; Jerry',
          '2026-11-17',
          tmdb: 42, rating: '3.5', rewatch: true),
      item('letterboxd-watch-1', 'other', 'Other', '2026-11-10'),
    ]));
    expect(entries.length, 2);
    final first = entries.first;
    expect(first.id, 'letterboxd-review-2');
    expect(first.uri, 'https://letterboxd.com/film/the-film-2025/');
    expect(first.title, 'Tom & Jerry');
    expect(first.year, 2025);
    expect(first.tmdbId, 42);
    expect(first.rating, 3.5);
    expect(first.rewatch, isTrue);
    expect(first.watchedOn, DateTime(2026, 11, 17));
    expect(entries.last.rating, isNull);
    expect(entries.last.tmdbId, isNull);
  });

  test('merge adds new films and counts a later viewing once', () {
    final snapshot = LetterboxdSnapshot(records: [
      LetterboxdRecord(LetterboxdFilm(
          uri: 'https://letterboxd.com/film/known/',
          title: 'Known',
          rating: 3,
          watchedAt: DateTime(2026, 11, 1))),
    ]);
    LetterboxdDiaryEntry entry(String slug, DateTime on, {double? rating}) =>
        LetterboxdDiaryEntry(
            id: '$slug$on',
            slug: slug,
            title: slug,
            watchedOn: on,
            rating: rating,
            tmdbId: 7);
    const work = LetterboxdWork(title: 'W', tmdbId: 7, traits: []);
    final merged = mergeLetterboxdDiary(
        snapshot,
        [
          // Déjà dans l'export : pas un nouveau visionnage.
          entry('known', DateTime(2026, 11, 1)),
          entry('known', DateTime(2026, 11, 12), rating: 4.5),
          entry('new', DateTime(2026, 11, 15), rating: 2),
        ],
        {7: work},
        now: DateTime(2026, 11, 18));
    final known = merged.records.first;
    expect(known.film.watches, 2);
    expect(known.film.rating, 4.5);
    expect(known.film.watchedAt, DateTime(2026, 11, 12));
    expect(known.work, same(work));
    final added = merged.records.last;
    expect(added.film.uri, 'https://letterboxd.com/film/new/');
    expect(added.film.rating, 2);
    expect(added.film.ratedAt, DateTime(2026, 11, 15));
    expect(merged.records.length, 2);
    // Le résultat reste lisible par le stockage de l'import.
    LetterboxdSnapshot.fromJson(merged.toJson());
  });

  group('sync', () {
    late AppDatabase db;
    late ProviderContainer container;
    setUp(() {
      container = ProviderContainer();
      db = AppDatabase(
          container.read(Provider<Ref>((r) => r)), NativeDatabase.memory());
    });
    tearDown(() async {
      await db.close();
      container.dispose();
    });

    test('marks unplayed library films once and feeds the taste profile',
        () async {
      final friends = LetterboxdFriendsStore(db, 'P');
      final snapshots = LetterboxdStore(db, 'P');
      final library = FakeLibrary({
        1: (id: 'cinema', played: false),
        2: (id: 'seen', played: true),
      });
      var xml = feed([
        item('g3', 'outside', 'Outside', '2026-11-16', tmdb: 3),
        item('g2', 'seen', 'Seen', '2026-11-15', tmdb: 2),
        item('g1', 'cinema', 'Cinema', '2026-11-14', tmdb: 1, rating: '4'),
      ]);
      final resolved = <int>[];
      LetterboxdDiarySync sync() => LetterboxdDiarySync(
          fetch: (_) async => xml,
          friends: friends,
          snapshots: snapshots,
          library: library,
          resolve: (id) async {
            resolved.add(id);
            return LetterboxdWork(title: 'S$id', tmdbId: id, traits: const []);
          });

      expect(await sync().run('me', cancelled: () => false), 1);
      expect(library.marked, [('cinema', DateTime(2026, 11, 14))]);
      expect(resolved, [3]);
      final saved = await snapshots.read();
      expect(saved.records.map((r) => r.work?.title), ['J1', 'J2', 'S3']);

      // Même flux : rien à refaire, même si on démarque ensuite le film.
      library.library[1] = (id: 'cinema', played: false);
      expect(await sync().run('me', cancelled: () => false), 0);
      expect(library.marked.length, 1);
      expect((await snapshots.read()).records.length, 3);

      // Une nouvelle séance du même film : un visionnage de plus.
      xml = feed([
        item('g4', 'cinema', 'Cinema', '2026-11-17', tmdb: 1),
      ]);
      await sync().run('me', cancelled: () => false);
      final again = await snapshots.read();
      expect(again.records.first.film.watches, 2);
      expect((await friends.diary()).seen, containsAll(['g1', 'g4']));
    });

    test('unknown profile', () async {
      expect(
          LetterboxdDiarySync(
              fetch: (_) async => null,
              friends: LetterboxdFriendsStore(db, 'P'),
              snapshots: LetterboxdStore(db, 'P'),
              library: FakeLibrary({})).run('me', cancelled: () => false),
          throwsA(isA<LetterboxdProfileNotFound>()));
    });
  });
}
