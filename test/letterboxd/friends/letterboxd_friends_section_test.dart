import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/letterboxd/friends/letterboxd_friends_parser.dart';
import 'package:kinos/letterboxd/friends/letterboxd_reviews.dart';
import 'package:kinos/letterboxd/friends/letterboxd_friends_providers.dart';
import 'package:kinos/letterboxd/friends/letterboxd_friends_section.dart';
import 'package:kinos/letterboxd/letterboxd_providers.dart';
import 'package:kinos/providers/user_provider.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/widgets/shared/frosted_surface.dart';

import '../../widgets/seerr_discovery_section_test.dart' show TestUser;

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
        letterboxdFriendsFilmProvider('120').overrideWith((ref) async => (
              slug: 'lotr',
              ratings: ratings,
              mine: null,
              reviews: const <String, LetterboxdReview>{}
            )),
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

  testWidgets('your photo and rating lead the row, then a bar, then friends',
      (tester) async {
    Future<void> pump(List<({LetterboxdFriend friend, int rating})> ratings) =>
        tester.pumpWidget(ProviderScope(
          key: UniqueKey(),
          overrides: [
            userProvider.overrideWith(TestUser.new),
            letterboxdScopeProvider.overrideWith((ref) => null),
            letterboxdFriendsFilmProvider('1').overrideWith((ref) async => (
                  slug: 'x',
                  ratings: ratings,
                  mine: 9,
                  reviews: const <String, LetterboxdReview>{}
                )),
          ],
          child: MaterialApp(
              theme: buildAppTheme(density: AppDensity.desk),
              home:
                  const Scaffold(body: LetterboxdFriendsSection(tmdbId: '1'))),
        ));
    final mineCell = find.byTooltip('Vous · ★★★★½');

    await pump(const []);
    await tester.pumpAndSettle();
    expect(mineCell, findsOneWidget);
    expect(find.textContaining('Votre note sur Letterboxd'), findsOneWidget);
    expect(find.textContaining('Vos amis'), findsNothing);

    await pump([
      (friend: const LetterboxdFriend(username: 'a', name: 'Ana'), rating: 6)
    ]);
    await tester.pumpAndSettle();
    expect(find.textContaining('Vos amis'), findsOneWidget);
    final mine = tester.getTopLeft(mineCell);
    final friend = tester.getTopLeft(find.byTooltip('Ana · ★★★'));
    expect(mine.dy, friend.dy, reason: 'same row');
    expect(
        tester.getSize(mineCell), tester.getSize(find.byTooltip('Ana · ★★★')),
        reason: 'same cell size as a friend');
    expect(mine.dx, lessThan(friend.dx), reason: 'your cell comes first');
    final bar = find.byWidgetPredicate((w) =>
        w is SizedBox &&
        w.width == 1 &&
        w.height == AppDetailLayout.friendDividerHeight);
    expect(bar, findsOneWidget);
    final barX = tester.getTopLeft(bar).dx;
    expect(barX, greaterThan(mine.dx));
    expect(barX, lessThan(friend.dx));
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
        letterboxdFriendsFilmProvider('1').overrideWith((ref) async => (
              slug: 'x',
              ratings: ratings,
              mine: null,
              reviews: const <String, LetterboxdReview>{}
            )),
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

  testWidgets('a written review opens its card; arrows go to the next one',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final ana = LetterboxdFriend(username: 'ana', name: 'Ana');
    final bob = LetterboxdFriend(username: 'bob', name: 'Bob');
    final cy = LetterboxdFriend(username: 'cy', name: 'Cy');
    await tester.pumpWidget(ProviderScope(
      overrides: [
        letterboxdScopeProvider.overrideWith((ref) => null),
        letterboxdFriendsFilmProvider('1').overrideWith((ref) async => (
              slug: 'x',
              ratings: [
                (friend: ana, rating: 9),
                (friend: bob, rating: 6),
                (friend: cy, rating: 4),
              ],
              mine: null,
              reviews: const <String, LetterboxdReview>{
                'ana': LetterboxdReview(
                    id: '1', slug: 'x', excerpt: 'Un chef-d\'œuvre.'),
                'cy': LetterboxdReview(
                    id: '2', slug: 'x', excerpt: 'La fin !', spoilers: true),
              },
            )),
      ],
      child: MaterialApp(
          theme: buildAppTheme(density: AppDensity.desk),
          home: const Scaffold(
              body: SingleChildScrollView(
                  child: LetterboxdFriendsSection(tmdbId: '1')))),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('2 critiques'), findsOneWidget);
    // Deux guillemets : Ana et Cy ont écrit, pas Bob.
    expect(find.byIcon(Icons.format_quote_rounded), findsNWidgets(2));
    await tester.tap(find.byWidgetPredicate(
        (w) => w is Tooltip && (w.message ?? '').startsWith('Ana')));
    await tester.pumpAndSettle();
    expect(find.text('Un chef-d\'œuvre.'), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);
    final first = tester.getTopLeft(find.byType(FrostedSurface)).dx;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    // La tuile a suivi la photo de Cy, plus à droite dans la rangée.
    expect(tester.getTopLeft(find.byType(FrostedSurface)).dx,
        greaterThan(first));
    // Critique à spoilers : voilée jusqu'à « Afficher quand même ».
    expect(find.text('La fin !'), findsNothing);
    await tester.tap(find.text('Afficher quand même'));
    await tester.pumpAndSettle();
    expect(find.text('La fin !'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('La fin !'), findsNothing);
  });
}
