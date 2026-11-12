import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/letterboxd/friends/letterboxd_friends_parser.dart';
import 'package:kinos/letterboxd/friends/letterboxd_friends_providers.dart';
import 'package:kinos/letterboxd/friends/letterboxd_friends_section.dart';
import 'package:kinos/letterboxd/letterboxd_providers.dart';
import 'package:kinos/theme/app_theme.dart';

void main() {
  testWidgets('+N unfolds every friend rating, then folds back',
      (tester) async {
    final ratings = [
      for (var i = 0; i < 27; i++)
        (
          friend: LetterboxdFriend(username: 'f$i', name: 'Ami $i'),
          rating: 10 - i % 5
        )
    ];
    await tester.pumpWidget(ProviderScope(
      overrides: [
        letterboxdScopeProvider.overrideWith((ref) => null),
        letterboxdFriendsFilmProvider('120').overrideWith(
            (ref) async => (slug: 'lotr', ratings: ratings, mine: null)),
      ],
      child: MaterialApp(
          theme: buildAppTheme(density: AppDensity.desk),
          home: const Scaffold(
              body: SingleChildScrollView(
                  child: LetterboxdFriendsSection(tmdbId: '120')))),
    ));
    await tester.pumpAndSettle();
    final cells = find.byWidgetPredicate(
        (w) => w is Tooltip && (w.message ?? '').startsWith('Ami '));
    expect(cells, findsNWidgets(AppDetailLayout.friendsVisible));
    final more = '+${27 - AppDetailLayout.friendsVisible}';
    await tester.tap(find.text(more));
    await tester.pumpAndSettle();
    expect(cells, findsNWidgets(27));
    expect(find.text('Réduire'), findsOneWidget);
    await tester.tap(find.text('Réduire'));
    await tester.pumpAndSettle();
    expect(cells, findsNWidgets(AppDetailLayout.friendsVisible));
    expect(find.text(more), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('my own rating shows above friends, and alone if need be',
      (tester) async {
    Future<void> pump(List<({LetterboxdFriend friend, int rating})> ratings) =>
        tester.pumpWidget(ProviderScope(
          key: UniqueKey(),
          overrides: [
            letterboxdScopeProvider.overrideWith((ref) => null),
            letterboxdFriendsFilmProvider('1').overrideWith(
                (ref) async => (slug: 'x', ratings: ratings, mine: 9)),
          ],
          child: MaterialApp(
              theme: buildAppTheme(density: AppDensity.desk),
              home:
                  const Scaffold(body: LetterboxdFriendsSection(tmdbId: '1'))),
        ));
    await pump(const []);
    await tester.pumpAndSettle();
    expect(find.textContaining('Votre note'), findsOneWidget);
    expect(find.textContaining('★★★★½'), findsOneWidget);
    expect(find.textContaining('Vos amis'), findsNothing);

    await pump([
      (friend: const LetterboxdFriend(username: 'a', name: 'Ana'), rating: 6)
    ]);
    await tester.pumpAndSettle();
    final mine = tester.getTopLeft(find.textContaining('Votre note')).dy;
    final friends = tester.getTopLeft(find.textContaining('Vos amis')).dy;
    expect(mine, lessThan(friends));
    expect(tester.takeException(), isNull);
  });
}
