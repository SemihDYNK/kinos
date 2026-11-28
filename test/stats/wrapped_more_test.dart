import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kinos/letterboxd/friends/letterboxd_friends_parser.dart';
import 'package:kinos/letterboxd/letterboxd_providers.dart';
import 'package:kinos/ratings/kinos_ratings.dart';
import 'package:kinos/stats/stats_screen.dart'
    show statsPersonProvider, statsPortraitProvider;
import 'package:kinos/stats/viewing_log.dart';
import 'package:kinos/stats/wrapped/film_facts.dart';
import 'package:kinos/stats/wrapped/wrapped_audio.dart';
import 'package:kinos/stats/wrapped/wrapped_data.dart';
import 'package:kinos/stats/wrapped/wrapped_export.dart';
import 'package:kinos/stats/wrapped/wrapped_media.dart';
import 'package:kinos/stats/wrapped/wrapped_more.dart';
import 'package:kinos/stats/wrapped/wrapped_motion.dart';
import 'package:kinos/stats/wrapped/wrapped_quotes.dart';
import 'package:kinos/stats/wrapped/wrapped_slides.dart';
import 'package:kinos/theme/app_theme.dart';

const year = 2026;

ViewingEvent film(int n, DateTime at,
        {int minutes = 100, String director = 'Agnès Varda'}) =>
    ViewingEvent(
        identity: 'tmdb:movie:$n',
        kind: 'movie',
        title: 'Film $n',
        at: at,
        runtimeSeconds: minutes * 60,
        sources: const {ViewingSource.kinos},
        jellyfinId: 'j$n',
        tmdbId: n,
        year: 1990 + n,
        genres: [n.isEven ? 'Drama' : 'Comédie'],
        directors: [director]);

ViewingEvent episode(String series, int n, DateTime at,
        {List<String> studios = const ['HBO']}) =>
    ViewingEvent(
        identity: 'jellyfin:$series$n',
        kind: 'episode',
        title: 'Épisode $n',
        seriesTitle: series,
        season: 1,
        episode: n,
        at: at,
        runtimeSeconds: 2400,
        jellyfinId: '$series$n',
        genres: const ['Drame'],
        studios: studios);

const aya = LetterboxdFriend(username: 'aya', name: 'Aya');
const ben = LetterboxdFriend(username: 'ben', name: 'Ben');

final lastYear = [
  for (var n = 1; n <= 10; n++)
    film(100 + n, DateTime(year - 1, n, 5), director: 'Akira Kurosawa'),
];

final thisYear = [
  for (var n = 1; n <= 8; n++)
    film(n, DateTime(year, n, 10), minutes: 80 + n * 10),
  // Le film 3, revu deux fois.
  film(3, DateTime(year, 9, 1), minutes: 110),
  film(3, DateTime(year, 10, 1), minutes: 110),
  for (var n = 1; n <= 10; n++)
    episode('Succession', n, DateTime(year, 3, n, 21)),
  for (var n = 1; n <= 3; n++)
    episode('Frieren', n, DateTime(year, 4, n, 21),
        studios: const ['Nippon TV']),
];

final events = [...lastYear, ...thisYear];

final ratings = {
  for (var n = 1; n <= 8; n++)
    'tmdb:movie:$n':
        KinosRating(4 + n % 6, at: DateTime(year), source: RatingSource.kinos),
};

final facts = {
  for (var n = 1; n <= 8; n++)
    n: FilmFacts(
        countries: switch (n % 4) {
      0 => const ['FR'],
      1 => const ['JP'],
      2 => const ['US', 'GB'],
      _ => const ['KR'],
    }),
};

/// Aya note comme vous ; Ben toujours à l'opposé.
final friends = {
  for (var n = 1; n <= 8; n++)
    'film-$n': [
      (friend: aya, rating: 4 + n % 6),
      (friend: ben, rating: 10 - (4 + n % 6) + 1),
    ],
};

WrappedData data() => computeWrapped(events, ratings, year,
    facts: facts,
    friends: friends,
    slugs: {for (var n = 1; n <= 8; n++) 'tmdb:movie:$n': 'film-$n'});

void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  test('versus compares hours, films, genre and new directors', () {
    final v = data().versus!;
    expect(v.lastFilms, 10);
    expect(v.films, 10, reason: 'viewings, rewatches included');
    expect(v.newDirectors, 1, reason: 'Varda, unseen before this year');
    expect(v.lastGenre, isNotNull);
    expect(wrappedVersus(thisYear, ratings, year), isNull,
        reason: 'nothing watched the year before');
  });

  test('the soulmate rates like you, the opposite does not', () {
    final s = data().soulmate!;
    expect(s.friend.name, 'Aya');
    expect(s.gap, 0);
    expect(s.shared.length, 8);
    expect(s.opposite?.name, 'Ben');
  });

  test('records: longest, shortest and most rewatched', () {
    final r = data().records!;
    expect(r.longest.title, 'Film 8');
    expect(r.shortest.title, 'Film 1');
    expect(r.mostSeen?.title, 'Film 3');
    expect(r.times, 3);
  });

  test('world tour counts production countries', () {
    final w = data().world!;
    expect([for (final c in w.countries) c.code].toSet(),
        {'FR', 'JP', 'US', 'GB', 'KR'});
    expect(countryName('JP'), 'Japon');
    expect(countryName('ZZ'), 'ZZ');
  });

  test('channel of the year weighs episodes', () {
    final c = data().channel!;
    expect(c.name, 'HBO');
    expect(c.episodes, 10);
    expect(c.series, ['Succession']);
  });

  test('series started this year exclude older ones', () {
    final started = seriesStartedIn([
      ...thisYear,
      episode('Succession', 0, DateTime(year - 2, 1, 1)),
    ], year);
    expect(started, {'Frieren'});
  });

  test('new slides belong to their act', () {
    expect(wrappedActOf('versus'), 0);
    expect(wrappedActOf('world'), 1);
    expect(wrappedActOf('records'), 1);
    expect(wrappedActOf('channel'), 2);
    expect(wrappedActOf('anime'), 2);
    expect(wrappedActOf('abandoned'), 2);
    expect(wrappedActOf('returning'), 2);
    expect(wrappedActOf('soulmate'), 3);
  });

  WrappedInputs inputs() => WrappedInputs(
        data: data(),
        art: const {},
        tints: const {},
        ratings: ratings,
        anime: const {'Frieren', 'Succession'},
        abandoned: const [
          (name: 'Frieren', played: 3, total: 28),
          (name: 'The Bear', played: 0, total: 10),
        ],
        returning: [
          (
            title: 'Succession',
            season: 5,
            date: DateTime(year + 1, 3, 12),
            backdrop: null
          ),
          (
            title: 'Frieren',
            season: 2,
            date: DateTime(year + 1, 1, 9),
            backdrop: null
          ),
        ],
      );

  const added = [
    'versus',
    'world',
    'records',
    'channel',
    'anime',
    'abandoned',
    'returning',
    'soulmate',
  ];

  testWidgets('the new slides appear, in order, and hold at 16:9',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final slides = buildWrappedSlides(inputs());
    final ids = [for (final s in slides) s.id];
    for (final id in added) {
      expect(ids, contains(id));
    }
    expect(ids.indexOf('versus'), lessThan(ids.indexOf('act2')));
    expect(ids.indexOf('returning'), lessThan(ids.indexOf('series-of-year')));
    expect(ids.indexOf('soulmate'), greaterThan(ids.indexOf('profile')));
    for (final slide in slides.where((s) => added.contains(s.id))) {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          letterboxdScopeProvider.overrideWith((ref) => null),
          kinosRatingStoreProvider.overrideWith((ref) => null),
          statsPortraitProvider.overrideWith((ref, name) async => null),
          statsPersonProvider.overrideWith((ref, name) async => null),
          wrappedQuoteProvider.overrideWith((ref, key) async => null),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: WrappedClock(
            duration: slide.seconds,
            motion: false,
            progress: const AlwaysStoppedAnimation(1),
            child: Builder(builder: slide.builder),
          ),
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: slide.id);
    }
  });

  testWidgets('the new slides hold as stories', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        letterboxdScopeProvider.overrideWith((ref) => null),
        kinosRatingStoreProvider.overrideWith((ref) => null),
        statsPortraitProvider.overrideWith((ref, name) async => null),
        statsPersonProvider.overrideWith((ref, name) async => null),
        wrappedQuoteProvider.overrideWith((ref, key) async => null),
      ],
      child: MaterialApp(
          theme: buildAppTheme(),
          home: Builder(builder: (c) {
            context = c;
            return const SizedBox();
          })),
    ));
    final w = inputs();
    final slides = [
      for (final s in buildWrappedSlides(w))
        if (added.contains(s.id)) s
    ];
    final pages = wrappedExportPages(w, slides,
        year: false, acts: false, allSlides: true);
    // La story de l'acte IV, signée par l'âme sœur.
    final summaries = wrappedExportPages(w, const [],
        year: false, acts: true, allSlides: false);
    final dir =
        (await tester.runAsync(() => Directory.systemTemp.createTemp('w')))!;
    addTearDown(() => dir.deleteSync(recursive: true));
    for (final page in pages) {
      await tester.runAsync(() => exportWrapped(context,
          dir: dir, pages: [page], formats: {WrappedFormat.story}));
      expect(tester.takeException(), isNull, reason: page.file);
    }
    expect(pages.length, added.length);
    for (final page in summaries) {
      await tester.runAsync(() => exportWrapped(context,
          dir: dir, pages: [page], formats: {WrappedFormat.story}));
      expect(tester.takeException(), isNull, reason: page.file);
    }
    expect([for (final p in summaries) p.file], contains('03-acte-4-vous'));
  });
}
