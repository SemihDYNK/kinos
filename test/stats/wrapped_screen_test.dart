import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kinos/letterboxd/friends/letterboxd_friends_parser.dart';
import 'package:kinos/letterboxd/letterboxd_providers.dart';
import 'package:kinos/ratings/kinos_ratings.dart';
import 'package:kinos/stats/viewing_log.dart';
import 'package:kinos/stats/wrapped/film_facts.dart';
import 'package:kinos/stats/wrapped/wrapped_data.dart';
import 'package:kinos/stats/wrapped/wrapped_media.dart';
import 'package:kinos/stats/wrapped/wrapped_motion.dart';
import 'package:kinos/stats/wrapped/wrapped_providers.dart';
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

final events = [
  for (var n = 1; n <= 12; n++)
    film(n, DateTime(year, n <= 6 ? 7 : n - 6, n <= 6 ? 10 + n : 3),
        genre: n.isEven ? 'Drame' : 'Thriller'),
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
      ],
      child: MaterialApp(
          theme: buildAppTheme(), home: const YearWrappedScreen(year: year)),
    ));
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('Votre année 2026'), findsOneWidget);

    final seen = <String>{};
    for (var i = 0; i < 20; i++) {
      // Jusqu'à la fin de la diapo : tous ses textes sont posés.
      await tester.pump(const Duration(seconds: 7));
      await tester.pump(const Duration(seconds: 7));
      for (final label in [
        'ACTE I',
        'VOUS AVEZ PASSÉ',
        'VOTRE GENRE',
        'VOTRE RÉALISATEUR',
        'VOS NOTES',
        'VOS AMIS NE SONT PAS D\'ACCORD',
        'À CONTRE-COURANT',
        'VOTRE PLUS VIEUX VOYAGE',
        'HORS DE CHEZ VOUS',
        'VOTRE FILM DE L\'ANNÉE',
        'KINOS · 2026',
      ]) {
        if (find.text(label).evaluate().isNotEmpty) seen.add(label);
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump(const Duration(seconds: 2));
    }
    expect(tester.takeException(), isNull);
    expect(seen.length, 11, reason: 'seen: $seen');
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
    expect(find.text('Film de l\'année'), findsOneWidget);
  });
}
