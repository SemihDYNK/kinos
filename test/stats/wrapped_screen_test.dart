import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kinos/letterboxd/friends/letterboxd_friends_parser.dart';
import 'package:kinos/letterboxd/letterboxd_providers.dart';
import 'package:kinos/ratings/kinos_ratings.dart';
import 'package:kinos/stats/stats_screen.dart' show statsPersonProvider;
import 'package:kinos/stats/viewing_log.dart';
import 'package:kinos/stats/wrapped/film_facts.dart';
import 'package:kinos/stats/wrapped/wrapped_data.dart';
import 'package:kinos/stats/wrapped/wrapped_media.dart';
import 'package:kinos/stats/wrapped/wrapped_motion.dart';
import 'package:kinos/stats/wrapped/wikiquote.dart';
import 'package:kinos/stats/wrapped/wrapped_export.dart';
import 'package:kinos/stats/wrapped/wrapped_providers.dart';
import 'package:kinos/stats/wrapped/wrapped_quotes.dart';
import 'package:kinos/stats/wrapped/wrapped_screen.dart';
import 'package:kinos/stats/wrapped/wrapped_slides.dart';
import 'package:kinos/theme/app_theme.dart';

const year = 2026;

ViewingEvent film(int n, DateTime at,
        {String genre = 'Thriller', String director = 'Akira Kurosawa'}) =>
    ViewingEvent(
        identity: 'tmdb:movie:$n',
        kind: 'movie',
        title: 'Film $n',
        at: at,
        runtimeSeconds: 6000,
        sources: n == 3
            ? const {ViewingSource.letterboxd}
            : const {ViewingSource.kinos},
        jellyfinId: n == 3 ? null : 'j$n',
        tmdbId: n,
        year: 1950 + n * 5,
        genres: [genre],
        directors: [director],
        cast: const ['Toshiro Mifune']);

ViewingEvent episode(String series, int n, DateTime at) => ViewingEvent(
    identity: 'jellyfin:$series$n',
    kind: 'episode',
    title: 'Épisode $n',
    seriesTitle: series,
    at: at,
    runtimeSeconds: 2400,
    jellyfinId: '$series$n',
    genres: const ['Drame']);

final episodes = [
  for (var n = 1; n <= 4; n++)
    episode('Severance', n, DateTime(year, 2, 8, 20 + n)),
  episode('Andor', 1, DateTime(year, 3, 1)),
];

final events = [
  for (var n = 1; n <= 12; n++)
    film(n, DateTime(year, n <= 6 ? 7 : n - 6, n <= 6 ? 10 + n : 3),
        genre: n.isEven ? 'Drame' : 'Thriller'),
  ...episodes,
];

final ratings = {
  for (var n = 1; n <= 12; n++)
    'tmdb:movie:$n': KinosRating(n == 2 ? 2 : 6 + n % 5,
        at: DateTime(year), source: RatingSource.kinos),
};

WrappedData data() => computeWrapped(events, ratings, year, facts: {
      2: const FilmFacts(publicRating: 8.4, votes: 4000),
    }, friends: {
      'two': [
        (friend: const LetterboxdFriend(username: 'a', name: 'Aya'), rating: 9),
        (
          friend: const LetterboxdFriend(username: 'b', name: 'Ben'),
          rating: 10
        ),
      ],
    }, slugs: {
      'tmdb:movie:2': 'two'
    });

void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  test('the Wrapped of the current year opens on 1 December', () {
    expect(wrappedAvailable(2026, now: DateTime(2026, 11, 22)), isFalse);
    expect(wrappedAvailable(2026, now: DateTime(2026, 12, 1)), isTrue);
    expect(wrappedAvailable(2025, now: DateTime(2026, 3, 1)), isTrue);
  });

  testWidgets('every slide plays, from the opening to the recap',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final wrapped = data();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        letterboxdScopeProvider.overrideWith((ref) => null),
        kinosRatingStoreProvider.overrideWith((ref) => null),
        wrappedDataProvider(year).overrideWith((ref) async => wrapped),
        wrappedArtProvider(year).overrideWith((ref) async => const {}),
        wrappedTintsProvider(year).overrideWith((ref) async => const {}),
        wrappedQuoteProvider.overrideWith((ref, key) async => key
                .startsWith('director')
            ? const WrappedQuote('Je rêve pour gagner ma vie.', language: 'fr')
            : const WrappedQuote("The name's Bond. James Bond.",
                language: 'en', film: 'Casino Royale', role: 'James Bond')),
      ],
      child: MaterialApp(
          theme: buildAppTheme(), home: const YearWrappedScreen(year: year)),
    ));
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('Votre année 2026'), findsOneWidget);
    // Manuel par défaut : la diapo reste après son mouvement.
    await tester.pump(const Duration(seconds: 30));
    expect(find.text('Votre année 2026'), findsOneWidget);
    // Espace lance la lecture automatique : la diapo finie passe aussitôt.
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('ACTE I'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump(const Duration(seconds: 3));

    final seen = <String>{};
    for (var i = 0; i < 20; i++) {
      // Jusqu'à la fin de la diapo : tous ses textes sont posés.
      await tester.pump(const Duration(seconds: 7));
      await tester.pump(const Duration(seconds: 7));
      for (final label in [
        'ACTE I',
        'VOUS AVEZ PASSÉ',
        'VOTRE GENRE',
        'VOS SÉRIES',
        'VOTRE RÉALISATEUR',
        'VOS NOTES',
        'VOS AMIS NE SONT PAS D\'ACCORD',
        'À CONTRE-COURANT',
        'VOTRE PLUS VIEUX VOYAGE',
        'HORS DE CHEZ VOUS',
        'VOTRE FILM DE L\'ANNÉE',
        'Film de l\'année',
        '« Je rêve pour gagner ma vie. »',
        "“The name's Bond. James Bond.”",
        'JAMES BOND · CASINO ROYALE',
      ]) {
        if (find.text(label).evaluate().isNotEmpty) seen.add(label);
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump(const Duration(seconds: 2));
    }
    expect(tester.takeException(), isNull);
    expect(seen.length, 15, reason: 'seen: $seen');
  });

  test('the timeline speed never jumps nor goes backwards', () {
    final path =
        smoothPath([(0, 0, 0), (.5, 40, 20), (.64, 43, 20), (1, 90, 0)]);
    var previous = path(0);
    var speed = 0.0;
    for (var i = 1; i <= 1000; i++) {
      final x = i / 1000, p = path(x);
      expect(p, greaterThanOrEqualTo(previous - 1e-9));
      final v = (p - previous) * 1000;
      expect((v - speed).abs(), lessThan(5), reason: 'at $x');
      previous = p;
      speed = v;
    }
    expect(path(.5), closeTo(40, 1e-9));
    expect(path(1), closeTo(90, 1e-9));
  });

  testWidgets('a year of series only still plays', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final wrapped = computeWrapped(episodes, const {}, year);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        letterboxdScopeProvider.overrideWith((ref) => null),
        kinosRatingStoreProvider.overrideWith((ref) => null),
        wrappedDataProvider(year).overrideWith((ref) async => wrapped),
        wrappedArtProvider(year).overrideWith((ref) async => const {}),
        wrappedTintsProvider(year).overrideWith((ref) async => const {}),
      ],
      child: MaterialApp(
          theme: buildAppTheme(), home: const YearWrappedScreen(year: year)),
    ));
    var series = false;
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(seconds: 6));
      await tester.pump(const Duration(seconds: 6));
      series |= find.text('5 épisodes').evaluate().isNotEmpty;
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump(const Duration(seconds: 2));
    }
    expect(tester.takeException(), isNull);
    expect(series, isTrue);
  });

  testWidgets('a rolling year moves only the digit that changes',
      (tester) async {
    Widget board(String year) => MaterialApp(
        theme: buildAppTheme(),
        home: Center(
            child: RollingText(year, style: const TextStyle(fontSize: 40))));
    await tester.pumpWidget(board('1990'));
    await tester.pumpWidget(board('1980'));
    await tester.pump(const Duration(milliseconds: 200));
    // En plein roulement : l'ancien chiffre sort, le nouveau entre.
    expect(find.text('9'), findsWidgets);
    expect(find.text('8'), findsWidgets);
    await tester.pumpAndSettle();
    expect(find.text('9'), findsWidgets, reason: 'the 9 of 19… stays');
    expect(find.text('8'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the year and act recaps export as PNG stories', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        letterboxdScopeProvider.overrideWith((ref) => null),
        kinosRatingStoreProvider.overrideWith((ref) => null),
        // Pas de réseau en test : ni Wikiquote, ni recherche de personnes.
        wrappedQuoteProvider.overrideWith((ref, key) async => null),
        statsPersonProvider.overrideWith((ref, name) async => null),
      ],
      child: MaterialApp(
          theme: buildAppTheme(),
          home: Builder(builder: (c) {
            context = c;
            return const SizedBox();
          })),
    ));
    final w = WrappedInputs(
        data: data(), art: const {}, tints: const {}, ratings: ratings);
    final pages = wrappedExportPages(w.withName('Semih'), const [],
        year: true, acts: true, allSlides: false);
    expect([
      for (final p in pages) p.file
    ], [
      '00-recap',
      '01-acte-1-le-temps',
      '02-acte-2-les-gouts',
      '03-acte-3-les-films'
    ]);
    // Les vraies entrées-sorties passent par runAsync : dans le temps
    // simulé du test, elles ne se terminent jamais.
    final dir =
        (await tester.runAsync(() => Directory.systemTemp.createTemp('w')))!;
    addTearDown(() => dir.deleteSync(recursive: true));
    final files = await tester.runAsync(() => exportWrapped(context,
        dir: dir, pages: pages, formats: {WrappedFormat.story}));
    expect(files!.length, 4);
    expect(tester.takeException(), isNull, reason: 'recaps');
    final codec = await tester.runAsync(
        () async => ui.instantiateImageCodec(await files.first.readAsBytes()));
    expect([
      for (final f in files) f.uri.pathSegments.last
    ], [
      '00-recap.png',
      '01-acte-1-le-temps.png',
      '02-acte-2-les-gouts.png',
      '03-acte-3-les-films.png'
    ]);
    final frame = await tester.runAsync(() => codec!.getNextFrame());
    expect((frame!.image.width, frame.image.height), (1080, 1920));

    // Toutes les diapos tiennent aussi en story, dans leur état final.
    final all = wrappedExportPages(w, buildWrappedSlides(w),
        year: false, acts: false, allSlides: true);
    for (final page in all) {
      await tester.runAsync(() => exportWrapped(context,
          dir: dir, pages: [page], formats: {WrappedFormat.story}));
      expect(tester.takeException(), isNull, reason: page.file);
    }
  });

  testWidgets('the recap holds in a 9:16 story', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: WrappedClock(
        duration: 1,
        motion: false,
        progress: const AlwaysStoppedAnimation(1),
        child: WrappedRecap(
            inputs: WrappedInputs(
                data: data(),
                art: const {},
                tints: const {},
                ratings: ratings)),
      ),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('FILM DE L\'ANNÉE'), findsOneWidget);
    expect(find.text('2026'), findsNWidgets(2),
        reason: 'the year, bottom right, and the giant one behind');
  });
}
