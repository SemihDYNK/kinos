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
    // Les amis et « +N » sont sur la même ligne : le bloc ne pousse pas le
    // logo et les boutons du bandeau vers le haut.
    final firstRow = tester.getTopLeft(cells.first).dy;
    expect(tester.getTopLeft(cells.last).dy, firstRow);
    expect(
        tester.getTopLeft(find.text(more)).dy,
        closeTo(
            firstRow +
                (AppDetailLayout.friendAvatarSize + AppSpacing.lg) / 2 -
                10,
            40),
        reason: 'the +N cell shares the row, not a second one');
    expect(tester.getSize(find.byType(LetterboxdFriendsSection)).height,
        lessThan(2 * (AppDetailLayout.friendAvatarSize + AppSpacing.lg)));
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

  testWidgets('stars keep one size whatever the rating', (tester) async {
    final ratings = [
      (friend: const LetterboxdFriend(username: 'a', name: 'A'), rating: 10),
      (friend: const LetterboxdFriend(username: 'b', name: 'B'), rating: 7),
      (friend: const LetterboxdFriend(username: 'c', name: 'C'), rating: 5),
    ];
    await tester.pumpWidget(ProviderScope(
      overrides: [
        letterboxdScopeProvider.overrideWith((ref) => null),
        letterboxdFriendsFilmProvider('1').overrideWith(
            (ref) async => (slug: 'x', ratings: ratings, mine: null)),
      ],
      child: MaterialApp(
          theme: buildAppTheme(density: AppDensity.desk),
          home: const Scaffold(body: LetterboxdFriendsSection(tmdbId: '1'))),
    ));
    await tester.pumpAndSettle();
    final full = tester.widgetList<Icon>(find.byIcon(Icons.star_rounded));
    final half = tester.widgetList<Icon>(find.byIcon(Icons.star_half_rounded));
    expect(full, hasLength(5 + 3 + 2));
    expect(half, hasLength(2));
    for (final icon in [...full, ...half]) {
      expect(icon.size, AppDetailLayout.friendStarSize);
    }
    // Cinq étoiles et demie tiennent dans une cellule d'ami.
    expect(5.5 * AppDetailLayout.friendStarSize,
        lessThanOrEqualTo(AppDetailLayout.friendCellWidth));
    expect(tester.takeException(), isNull);
  });
}
