import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kinos/letterboxd/letterboxd_providers.dart';
import 'package:kinos/ratings/kinos_ratings.dart';
import 'package:kinos/stats/stats_screen.dart';
import 'package:kinos/stats/viewing_log.dart';
import 'package:kinos/stats/viewing_stats.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/adaptive_layout/adaptive_layout.dart';
import 'package:kinos/util/adaptive_layout/adaptive_layout_model.dart';
import 'package:kinos/util/poster_defaults.dart';

ViewingEvent movie(String id, DateTime at,
        {int runtime = 7200,
        List<String> genres = const ['Drame'],
        List<String> directors = const [],
        Set<ViewingSource> sources = const {ViewingSource.kinos},
        String? jellyfinId = 'j'}) =>
    ViewingEvent(
        identity: id,
        kind: 'movie',
        title: id,
        at: at,
        runtimeSeconds: runtime,
        sources: sources,
        jellyfinId: jellyfinId,
        genres: genres,
        directors: directors);

ViewingEvent episode(String series, DateTime at) => ViewingEvent(
    identity: 'jellyfin:$series$at',
    kind: 'episode',
    title: 'E',
    seriesTitle: series,
    at: at,
    runtimeSeconds: 1800,
    genres: const ['Comédie']);

void main() {
  setUpAll(() => initializeDateFormatting('fr'));
  final events = [
    movie('tmdb:movie:1', DateTime(2026, 3, 2),
        directors: ['Villeneuve'], genres: ['Science-fiction']),
    movie('tmdb:movie:1', DateTime(2026, 8, 10),
        directors: ['Villeneuve'], genres: ['Science-fiction']),
    movie('tmdb:movie:2', DateTime(2026, 8, 12),
        runtime: 10800, sources: {ViewingSource.letterboxd}, jellyfinId: null),
    movie('tmdb:movie:3', DateTime(2025, 5, 1)),
    episode('Signal', DateTime(2026, 8, 20, 21)),
    episode('Signal', DateTime(2026, 8, 20, 22)),
    episode('Signal', DateTime(2026, 8, 20, 23)),
  ];
  final ratings = {
    'tmdb:movie:1':
        KinosRating(9, at: DateTime(2026), source: RatingSource.kinos),
    'tmdb:movie:3':
        KinosRating(4, at: DateTime(2025), source: RatingSource.kinos),
  };

  test('a year: numbers, months, tastes, ratings and records', () {
    final stats = computeStats(events, ratings, const StatsPeriod(year: 2026));
    expect(stats.films, 3);
    expect(stats.episodes, 3);
    expect(stats.series, 1);
    expect(stats.elsewhere, 1, reason: 'Letterboxd only, not in the library');
    expect(stats.seconds, 7200 * 2 + 10800 + 1800 * 3);
    expect(stats.buckets.length, 12);
    expect(stats.busiestBucket, 7, reason: 'August');
    expect(stats.genres.first, (name: 'Science-fiction', count: 2));
    expect(stats.genreFilms['Science-fiction']!.at, DateTime(2026, 8, 10),
        reason: 'same rating: the latest viewing');
    expect(stats.genreFilms.containsKey('Drame'), isFalse,
        reason: 'only a Letterboxd film outside the library');
    expect(stats.directors.single, (name: 'Villeneuve', count: 2));
    expect(stats.ratings[8], 1);
    expect(stats.average, 4.5);
    expect(stats.longestNight!.episodes, 3);
    expect(stats.longestFilm!.identity, 'tmdb:movie:2');
    expect(stats.mostSeen!.times, 2);
    expect(stats.years, [2026, 2025]);
    expect(stats.busiestDay!.day, DateTime(2026, 8, 12), reason: '3 h film');
    expect(stats.streak, isNull, reason: 'no two days in a row');
  });

  test('all time: one bar per year, every rating', () {
    final stats = computeStats(events, ratings, const StatsPeriod());
    expect(stats.buckets.length, 2);
    expect(stats.ratings.fold(0, (a, b) => a + b), 2);
    final month =
        computeStats(events, ratings, const StatsPeriod(year: 2026, month: 8));
    expect(month.buckets.length, 31);
    expect(month.films, 2);
    final streak = computeStats([
      for (final d in [3, 4, 5, 9, 10]) movie('m$d', DateTime(2026, 3, d)),
      movie('old', DateTime(2026, 3, 20)),
    ], const {}, const StatsPeriod(year: 2026))
        .streak!;
    expect((streak.start, streak.days), (DateTime(2026, 3, 3), 3));
  });

  testWidgets('the page shows the year and switches to all time',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        letterboxdScopeProvider.overrideWith((ref) => null),
        viewingEventsProvider.overrideWith((ref) async => [
              for (final e in events)
                ViewingEvent(
                    identity: e.identity,
                    kind: e.kind,
                    title: e.title,
                    seriesTitle: e.seriesTitle,
                    at: DateTime(DateTime.now().year, e.at.month, e.at.day),
                    runtimeSeconds: e.runtimeSeconds,
                    sources: e.sources,
                    genres: e.genres,
                    directors: e.directors)
            ]),
      ],
      child: MaterialApp(
          theme: buildAppTheme(),
          home: const AdaptiveLayout(
              data: AdaptiveLayoutModel(
                  viewSize: ViewSize.desktop,
                  layoutMode: LayoutMode.single,
                  inputDevice: InputDevice.pointer,
                  platform: TargetPlatform.linux,
                  isDesktop: true,
                  posterDefaults: PosterDefaults(size: 180, ratio: 2 / 3),
                  controller: {},
                  sideBarWidth: 0,
                  topBarHeight: 0,
                  statusBarHeight: 0),
              child: StatsScreen())),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Vos statistiques'), findsOneWidget);
    expect(find.textContaining('Activité', findRichText: true), findsWidgets);
    expect(find.text('films'), findsOneWidget);
    expect(find.bySemanticsLabel('Genre Science-fiction, 2 films'),
        findsOneWidget);
    expect(find.text('Villeneuve'), findsOneWidget);
    // Un jour d'été, après le changement d'heure, a bien sa case.
    expect(
        find.byWidgetPredicate(
            (w) => w is Tooltip && (w.message ?? '').contains('10 août ·')),
        findsOneWidget);
    await tester.tap(find.text('Depuis toujours'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
