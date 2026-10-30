import 'package:kinos/providers/theme/palette_service_provider.dart';
import 'package:kinos/theme/palette_service.dart';
import 'package:kinos/providers/seerr_search_provider.dart';
import 'package:kinos/screens/seerr/seerr_search_screen.dart';
import 'package:flutter/services.dart';
import 'package:kinos/screens/seerr/widgets/seerr_poster_row.dart';
import 'package:kinos/util/focus_provider.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/models/items/images_models.dart';
import 'package:kinos/models/seerr/seerr_dashboard_model.dart';
import 'package:kinos/providers/seerr_dashboard_provider.dart';
import 'package:kinos/providers/seerr_user_provider.dart';
import 'package:kinos/routes/auto_router.gr.dart';
import 'package:kinos/screens/dashboard/hero_carousel.dart';
import 'package:kinos/screens/seerr/seerr_discover_screen.dart';
import 'package:kinos/seerr/seerr_models.dart';
import 'seerr_discovery_section_test.dart' show shell, PendingDetailsRouter;
import 'support/home_visual_fixture.dart' show homeArtwork;

class TestPalette extends PaletteService {
  TestPalette() : super(InMemoryPaletteCache());
  @override
  Future<HeroPalette> forItem(
          {required String itemId, required ImageProvider image}) async =>
      HeroPalette.fallback;
}

SeerrDashboardPosterModel poster(SeerrMediaType type) =>
    SeerrDashboardPosterModel(
      id: type.name,
      type: type,
      tmdbId: 42,
      title: type == SeerrMediaType.movie ? 'Film test' : 'Série test',
      overview: 'Résumé',
      images: ImagesData(primary: homeArtwork, backDrop: [homeArtwork]),
      mediaStatus: SeerrMediaStatus.unknown,
      jellyfinItemId: null,
    );

class Dashboard extends SeerrDashboard {
  @override
  SeerrDashboardModel build() => SeerrDashboardModel(
        trending: [poster(SeerrMediaType.movie), poster(SeerrMediaType.tvshow)],
        popularMovies: [poster(SeerrMediaType.movie)],
        popularSeries: [poster(SeerrMediaType.tvshow)],
      );
  @override
  Future<void> fetchDashboard() async {}
}

class User extends SeerrUser {
  @override
  SeerrUserModel? build() => null;
}

class RecoveringDashboard extends Dashboard {
  var calls = 0;
  @override
  SeerrDashboardModel build() => const SeerrDashboardModel();
  @override
  Future<void> fetchDashboard() async {
    if (++calls == 1) throw StateError('offline');
    state = super.build();
  }
}

class Search extends SeerrSearch {
  final calls = <String>[];
  @override
  SeerrSearchModel build() => SeerrSearchModel();
  @override
  Future<void> init() async {
    calls.add('init');
  }

  @override
  Future<void> setSearchMode(SeerrSearchMode mode) async {
    calls.add('mode');
    await Future<void>.delayed(Duration.zero);
    state = state.copyWith(searchMode: mode);
  }

  @override
  Future<void> submit([String? value]) async {
    calls.add('submit');
    state = state.copyWith(results: [poster(SeerrMediaType.movie)]);
  }
}

void main() {
  testWidgets(
      'discover reuses hero, filters types and opens external details with artwork',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = PendingDetailsRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          paletteServiceProvider.overrideWithValue(TestPalette()),
          seerrDashboardProvider.overrideWith(Dashboard.new),
          seerrUserProvider.overrideWith(User.new),
        ],
        child: StackRouterScope(
            controller: router,
            stateHash: 0,
            child: shell(
                const SliverFillRemaining(child: SeerrDiscoverScreen())))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(HeroCarousel), findsOneWidget);
    expect(find.text('Rechercher...'), findsNothing);
    expect(
        tester.widget<HeroCarousel>(find.byType(HeroCarousel)).items.length, 2);
    await tester.ensureVisible(find.text('Séries'));
    await tester.tap(find.text('Séries'));
    await tester.pumpAndSettle();
    final scroll = tester.state<ScrollableState>(find
        .descendant(
            of: find.byType(SeerrDiscoverScreen),
            matching: find.byType(Scrollable))
        .first);
    scroll.position.jumpTo(0);
    await tester.pumpAndSettle();
    final hero = tester.widget<HeroCarousel>(find.byType(HeroCarousel));
    expect(hero.items.single.title, 'Série test');
    expect(find.text('Films populaires'), findsNothing);
    await tester.tap(find.text('Afficher les détails'));
    await tester.pump();
    final route = router.opened as SeerrDetailsRoute;
    expect(route.args!.mediaType, 'tvshow');
    expect(route.args!.tag, isNotNull);
    expect(route.args!.poster!.title, 'Série test');
    router.returned.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
  testWidgets('failed discovery can be retried without an endless spinner',
      (tester) async {
    await tester.pumpWidget(ProviderScope(overrides: [
      paletteServiceProvider.overrideWithValue(TestPalette()),
      seerrDashboardProvider.overrideWith(RecoveringDashboard.new),
      seerrUserProvider.overrideWith(User.new),
    ], child: shell(const SliverFillRemaining(child: SeerrDiscoverScreen()))));
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('Erreur'), findsOneWidget);
    await tester.tap(find.textContaining('Erreur'));
    await tester.pumpAndSettle();
    expect(find.byType(HeroCarousel), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('discovery rail arrows and keyboard reveal off-screen posters',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          paletteServiceProvider.overrideWithValue(TestPalette()),
          seerrUserProvider.overrideWith(User.new)
        ],
        child: shell(SliverToBoxAdapter(
            child: SeerrPosterRow(
          label: 'Tendances',
          showStatus: true,
          posters: List.generate(
              12,
              (index) => poster(SeerrMediaType.movie)
                  .copyWith(id: 'poster-$index', tmdbId: index)),
        )))));
    await tester.pumpAndSettle();
    final horizontal = find.byType(SingleChildScrollView);
    final scroll = tester.widget<SingleChildScrollView>(horizontal).controller!;
    expect(scroll.offset, 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(scroll.offset, greaterThan(0));
    scroll.jumpTo(0);
    final first =
        tester.state<FocusButtonState>(find.byType(FocusButton).first);
    first.focusNode.requestFocus();
    await tester.pumpAndSettle();
    for (var i = 0; i < 9; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
    }
    expect(scroll.offset, greaterThan(0));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
  testWidgets('browse initializes its mode before requesting the first results',
      (tester) async {
    final router = PendingDetailsRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          paletteServiceProvider.overrideWithValue(TestPalette()),
          seerrSearchProvider.overrideWith(Search.new),
          seerrDashboardProvider.overrideWith(Dashboard.new),
          seerrUserProvider.overrideWith(User.new),
        ],
        child: StackRouterScope(
            controller: router,
            stateHash: 0,
            child: shell(const SliverFillRemaining(
                child: SeerrSearchScreen(
                    mode: SeerrSearchMode.discoverMovies))))));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
        tester.element(find.byType(SeerrSearchScreen)));
    final search = container.read(seerrSearchProvider.notifier) as Search;
    expect(search.calls, ['init', 'mode', 'submit']);
    expect(find.text('Film test'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
