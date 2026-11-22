import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/letterboxd/letterboxd_model.dart';
import 'package:kinos/models/syncing/database_item.dart';
import 'package:kinos/ratings/kinos_rating_button.dart';
import 'package:kinos/ratings/kinos_ratings.dart';
import 'package:kinos/recommendations/models/watch_event.dart';
import 'package:kinos/recommendations/models/watch_signal.dart';
import 'package:kinos/theme/app_theme.dart';

void main() {
  test('Letterboxd ratings become ratings out of 10, the latest wins', () {
    final ratings = letterboxdRatings(LetterboxdSnapshot(records: [
      LetterboxdRecord(
          LetterboxdFilm(
              uri: 'https://boxd.it/a',
              title: 'A',
              rating: 4.5,
              ratedAt: DateTime(2024)),
          work: const LetterboxdWork(title: 'A', tmdbId: 1, traits: [])),
      LetterboxdRecord(
          LetterboxdFilm(
              uri: 'https://boxd.it/b',
              title: 'A',
              rating: 2,
              ratedAt: DateTime(2020)),
          work: const LetterboxdWork(title: 'A', tmdbId: 1, traits: [])),
      const LetterboxdRecord(
          LetterboxdFilm(uri: 'https://boxd.it/c', title: 'C', rating: 3)),
    ]));
    expect(ratings.keys, ['tmdb:movie:1']);
    expect(ratings['tmdb:movie:1']!.$1, 9);
  });

  test('a rating sets the weight of the matching viewing', () {
    final events = applyKinosRatings([
      const WatchEvent(
          itemId: 'j1', traits: [], signal: WatchSignal.completedNeutral),
      const WatchEvent(
          itemId: 'j2', traits: [], signal: WatchSignal.completedNeutral),
    ], {
      'tmdb:movie:1':
          KinosRating(10, at: DateTime(2026), source: RatingSource.kinos),
    }, (id) => id == 'j1' ? 'tmdb:movie:1' : null);
    expect(events.first.explicitWeight, ratingWeight(10));
    expect(ratingWeight(6), 0);
    expect(events.last.explicitWeight, isNull);
  });

  test('seeding never overwrites a rating given in Kinos', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final db = AppDatabase(
        container.read(Provider<Ref>((r) => r)), NativeDatabase.memory());
    addTearDown(db.close);
    final store = KinosRatingStore(db, 'p');
    final controller = KinosRatingsController(store);
    addTearDown(controller.dispose);
    await controller.set('tmdb:movie:1', 4);
    await controller.seed({
      'tmdb:movie:1': (9, DateTime(2024)),
      'tmdb:movie:2': (7, DateTime(2024)),
    });
    final saved = await store.all();
    expect(saved['tmdb:movie:1']!.value, 4);
    expect(saved['tmdb:movie:2']!.value, 7);
    expect(saved['tmdb:movie:2']!.source, RatingSource.letterboxd);
    await controller.set('tmdb:movie:2', null);
    expect((await store.all()).containsKey('tmdb:movie:2'), isFalse);
  });

  testWidgets('rate with the keyboard: arrows, then Enter', (tester) async {
    final container = ProviderContainer(overrides: [
      kinosRatingStoreProvider.overrideWith((ref) => null),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(
              body: Center(
                  child: KinosRatingButton(
                      identity: 'tmdb:movie:1', title: 'Dune')))),
    ));
    expect(find.text('Noter'), findsOneWidget);
    await tester.tap(find.text('Noter'));
    await tester.pumpAndSettle();
    // 3 étoiles par défaut, puis deux demi-étoiles de plus.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(find.text('4 / 5'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(container.read(kinosRatingsProvider)['tmdb:movie:1']!.value, 8);
    expect(find.byType(StarRow), findsOneWidget);
  });
}
