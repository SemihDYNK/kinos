import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/jellyfin/jellyfin_open_api.swagger.dart';
import 'package:kinos/letterboxd/home/letterboxd_home_providers.dart';
import 'package:kinos/models/item_base_model.dart';
import 'package:kinos/models/items/movie_model.dart';
import 'package:kinos/providers/connectivity_provider.dart'
    show offlineStateProvider;
import 'package:kinos/providers/dashboard/genre_browse_provider.dart';
import 'package:kinos/providers/user_provider.dart';
import 'package:kinos/routes/auto_router.gr.dart';
import 'package:kinos/screens/dashboard/genre_browse_section.dart';
import 'package:kinos/screens/dashboard/genre_page_screen.dart';

import 'seerr_discovery_section_test.dart' show shell, TestUser;
import 'support/page_shell.dart';

BrowseGenre genre(String label) => (label: label, names: [label], image: null);

ItemBaseModel movie(String id, String name, {int? year}) =>
    MovieModel.fromBaseDto(
        BaseItemDto(id: id, name: name, productionYear: year), null);

void main() {
  const scope = (kind: BaseItemKind.movie, libraryId: null);
  final genres = [
    for (final g in ['Action', 'Comédie', 'Drame', 'Horreur', 'Western'])
      genre(g)
  ];

  testWidgets('tiles scroll sideways and open the genre page on the router',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = RecordingRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        userProvider.overrideWith(TestUser.new),
        browseGenresProvider(scope).overrideWith((ref) async => genres),
      ],
      child: StackRouterScope(
          controller: router,
          stateHash: 0,
          child: shell(const GenreBrowseSection(
              scope: scope, contentPadding: EdgeInsets.zero))),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Genres'), findsOneWidget);
    expect(find.text('Action'), findsOneWidget);
    expect(find.text('Western'), findsNothing,
        reason: 'four tiles are visible at 1400 px; the rest scrolls');

    await tester.tap(find.byTooltip('Défiler vers la droite'));
    await tester.pumpAndSettle();
    expect(find.text('Western'), findsOneWidget);
    expect(find.text('Action'), findsNothing);
    await tester.tap(find.byTooltip('Défiler vers la gauche'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Action'));
    await tester.pump();
    final opened = router.opened as GenrePageRoute;
    final args = opened.args as GenrePageRouteArgs;
    expect(args.label, 'Action');
    expect(args.names, ['Action']);
    expect(args.kind, BaseItemKind.movie);
    expect(args.libraryId, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no genres, no row', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        userProvider.overrideWith(TestUser.new),
        browseGenresProvider(scope).overrideWith((ref) async => const []),
      ],
      child: shell(const GenreBrowseSection(
          scope: scope, contentPadding: EdgeInsets.zero)),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Genres'), findsNothing);
  });

  group('genre page', () {
    Future<RecordingRouter> open(WidgetTester tester,
        {required Map<int, List<ItemBaseModel>> decades}) async {
      tester.view.physicalSize = const Size(1400, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final router = RecordingRouter();
      addTearDown(router.dispose);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          userProvider.overrideWith(TestUser.new),
          offlineStateProvider.overrideWith((ref) => false),
          letterboxdGenreRowsProvider('Action')
              .overrideWith((ref) async => const LetterboxdHomeRows()),
          genrePageProvider(genrePageKey(scope, ['Action']))
              .overrideWith((ref) async => (
                    topRated: [movie('a', 'Le meilleur', year: 2019)],
                    recent: <ItemBaseModel>[],
                    unvisited: <ItemBaseModel>[],
                    movies: <ItemBaseModel>[],
                    series: <ItemBaseModel>[],
                    decades: decades,
                  )),
        ],
        child: pageShell(
            const GenrePageScreen(
                label: 'Action', names: ['Action'], kind: BaseItemKind.movie),
            router),
      ));
      await tester.pumpAndSettle();
      return router;
    }

    testWidgets('rows, decades, captions, and back to the router',
        (tester) async {
      final router = await open(tester, decades: {
        2010: [movie('b', 'Un film de 2013', year: 2013)],
        1990: [movie('c', 'Un film de 1995', year: 1995)],
      });
      expect(find.text('Action'), findsOneWidget);
      expect(find.text('Les mieux notés'), findsOneWidget);
      expect(find.text('Ajoutés récemment'), findsNothing,
          reason: 'empty rows are not shown');
      final d2010 = tester.getTopLeft(find.text('Les 2010s')).dy;
      final d1990 = tester.getTopLeft(find.text('Les 1990s')).dy;
      expect(d2010, lessThan(d1990), reason: 'newest decade first');
      expect(find.text('Le meilleur'), findsOneWidget,
          reason: 'every poster carries its title');
      expect(find.text('Voir tout : Action'), findsOneWidget);

      await tester.tap(find.byTooltip('Retour · Échap'));
      await tester.pump();
      expect(router.popped, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the banner leaves more room than a fixed strip',
        (tester) async {
      await open(tester, decades: const {});
      final title = tester.getBottomLeft(find.text('Action')).dy;
      expect(title, greaterThanOrEqualTo(340 - 8),
          reason: 'banner at least AppGenrePage.bannerMinHeight tall');
    });
  });
}
