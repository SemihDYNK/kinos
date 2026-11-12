import 'dart:io';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/jellyfin/jellyfin_open_api.enums.swagger.dart';
import 'package:kinos/models/views_model.dart';
import 'package:kinos/models/view_model.dart';
import 'package:kinos/models/item_base_model.dart';
import 'package:kinos/models/items/images_models.dart';
import 'package:kinos/models/seerr/seerr_dashboard_model.dart';
import 'package:kinos/seerr/seerr_models.dart';
import 'package:kinos/providers/dashboard/catalog_navigation_provider.dart';
import 'package:kinos/providers/user_provider.dart';
import 'package:kinos/providers/views_provider.dart';
import 'package:kinos/routes/auto_router.gr.dart';
import 'package:kinos/widgets/navigation_scaffold/components/catalog_navigation_bar.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/widgets/shared/frosted_surface.dart';
import 'package:kinos/util/motion_input.dart';
import 'package:kinos/util/adaptive_layout/adaptive_layout.dart';
import 'package:kinos/screens/shared/global_hotkeys.dart';
import 'package:kinos/models/settings/client_settings_model.dart';
import 'support/home_visual_fixture.dart' show fixtureMovies;
import 'seerr_discovery_section_test.dart' show shell, TestUser;

class Views extends ViewsNotifier {
  Views(super.ref) {
    state = ViewsModel(views: [
      ViewModel.createEmpty('animation', CollectionType.movies)
          .copyWith(name: 'Animation')
    ]);
  }
}

class CatalogRouter extends RootStackRouter {
  @override
  List<AutoRoute> get routes => [
        AutoRoute(
            page: PageInfo(SeerrSearchRoute.name,
                builder: (_) => const SizedBox.shrink())),
        AutoRoute(
            page: PageInfo(LibrarySearchRoute.name,
                builder: (_) => const SizedBox.shrink())),
        AutoRoute(
            page: PageInfo(SeerrRoute.name,
                builder: (_) => const SizedBox.shrink())),
        AutoRoute(
            page: PageInfo(SettingsRoute.name,
                builder: (_) => const SizedBox.shrink())),
        AutoRoute(
            page: PageInfo(ArrHomeRoute.name,
                builder: (_) => const SizedBox.shrink())),
        AutoRoute(
            initial: true,
            page: PageInfo(DashboardRoute.name,
                builder: (_) => const SizedBox.shrink()))
      ];
}

final searchButton = find.byIcon(Icons.search);

void main() {
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => Directory.systemTemp.path);
  });
  Future<ProviderContainer> mount(WidgetTester tester,
      {double scale = 1,
      double width = 1400,
      double sidebarWidth = 0,
      PageRouteInfo route = const DashboardRoute(),
      bool withResults = false,
      bool reducedMotion = false}) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = CatalogRouter();
    await router.navigate(route);
    addTearDown(router.dispose);
    final key = GlobalKey();
    await tester.pumpWidget(ProviderScope(
        key: key,
        overrides: [
          userProvider.overrideWith(TestUser.new),
          viewsProvider.overrideWith(Views.new),
          quickSearchProvider((query: 'Dune', language: 'fr'))
              .overrideWith((_) async => (
                    library: withResults
                        ? fixtureMovies().take(2).toList()
                        : <ItemBaseModel>[],
                    outside: <SeerrDashboardPosterModel>[]
                  )),
          quickSearchProvider((query: 'Dune 2', language: 'fr'))
              .overrideWith((_) async => (
                    library: fixtureMovies().take(1).toList(),
                    outside: [
                      SeerrDashboardPosterModel(
                          id: '1',
                          type: SeerrMediaType.movie,
                          tmdbId: 1,
                          title: 'Dune : Deuxième partie',
                          overview: '',
                          images: ImagesData(),
                          mediaStatus: SeerrMediaStatus.pending,
                          jellyfinItemId: null,
                          releaseYear: '2024')
                    ]
                  )),
          quickSearchProvider((query: 'All', language: 'fr'))
              .overrideWith((_) async => (
                    library:
                        List<ItemBaseModel>.filled(24, fixtureMovies().first),
                    outside: <SeerrDashboardPosterModel>[]
                  ))
        ],
        child: StackRouterScope(
            controller: router,
            stateHash: 0,
            child: shell(
                SliverToBoxAdapter(
                    child: SizedBox(
                        height: 700,
                        child: Builder(
                            builder: (context) => MediaQuery(
                                  data: MediaQuery.of(context).copyWith(
                                      disableAnimations: reducedMotion),
                                  child: AdaptiveLayout(
                                      data: AdaptiveLayout.of(context)
                                          .copyWith(sideBarWidth: sidebarWidth),
                                      child: const MotionInputBoundary(
                                          child: GlobalHotkeys(
                                              enabledHotkeys: {
                                            GlobalHotKeys.search
                                          },
                                              child: CatalogNavigationBar(
                                                  child: SizedBox.expand(
                                                      key: ValueKey(
                                                          'catalog-content')))))),
                                )))),
                textScale: scale))));
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
        tester.element(find.byType(CatalogNavigationBar)));
  }

  testWidgets('discover keeps the same full-frame origin as the home banner',
      (tester) async {
    await mount(tester);
    final homeTop =
        tester.getTopLeft(find.byKey(const ValueKey('catalog-content'))).dy;
    await mount(tester, route: SeerrSearchRoute());
    expect(tester.getTopLeft(find.byKey(const ValueKey('catalog-content'))).dy,
        homeTop);
  });

  testWidgets('top capsule stays centered regardless of sidebar width',
      (tester) async {
    for (final sidebarWidth in [92.0, 264.0]) {
      await mount(tester, sidebarWidth: sidebarWidth);
      expect(
          tester.getCenter(find.byType(BackdropFilter)).dx, closeTo(700, .5));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });

  testWidgets('active underline slides and can change target mid-flight',
      (tester) async {
    await mount(tester);
    final indicator = find.byKey(const ValueKey('catalog-active-indicator'));
    final start = tester.getCenter(indicator).dx;
    expect(start, closeTo(tester.getCenter(find.text('À la une')).dx, 1));
    await tester.tap(find.text('Films'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final moving = tester.getCenter(indicator).dx;
    expect(moving, greaterThan(start));
    expect(moving, lessThan(tester.getCenter(find.text('Films')).dx));
    await tester.tap(find.text('Séries'));
    await tester.pump();
    await tester.pump();
    expect(tester.getCenter(indicator).dx, closeTo(moving, .01));
    await tester.pumpAndSettle();
    expect(tester.getCenter(indicator).dx,
        closeTo(tester.getCenter(find.text('Séries')).dx, 1));
    expect(tester.takeException(), isNull);
  });

  for (final keyboard in [false, true]) {
    testWidgets(
        'underline is immediate for ${keyboard ? 'keyboard' : 'reduced motion'}',
        (tester) async {
      await mount(tester, reducedMotion: !keyboard);
      if (keyboard) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      } else {
        await tester.tap(find.text('Films'));
      }
      await tester.pump();
      await tester.pump();
      await tester.pump();
      final indicator = find.byKey(const ValueKey('catalog-active-indicator'));
      expect(tester.getCenter(indicator).dx,
          closeTo(tester.getCenter(find.text('Films')).dx, 1));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('top bar contains home destinations but no libraries menu',
      (tester) async {
    final container = await mount(tester);
    await tester.tap(find.text('Films'));
    await tester.pumpAndSettle();
    expect(container.read(catalogScopeProvider).kind, BaseItemKind.movie);
    expect(find.text('Bibliothèques'), findsNothing);
    await tester.tap(find.text('À la une'));
    await tester.pumpAndSettle();
    expect(container.read(catalogScopeProvider), allCatalog);
    expect(tester.takeException(), isNull);
  });
  testWidgets('search opens over the page and Escape returns to navigation',
      (tester) async {
    await mount(tester);
    await tester.tap(searchButton);
    await tester.pumpAndSettle();
    expect(find.byType(EditableText), findsOneWidget);
    await tester.enterText(find.byType(EditableText), 'Dune');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.text('Aucun résultat'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(EditableText), findsNothing);
    expect(find.text('À la une'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('the button becomes the field; results hang below it',
      (tester) async {
    await mount(tester);
    expect(find.text('Ctrl K'), findsNothing);
    final button = tester.getRect(
        find.ancestor(of: searchButton, matching: find.byType(FocusRing)));
    await tester.tap(searchButton);
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(find.byTooltip('Rechercher · Ctrl K'), findsNothing);
    final field = tester.getRect(find.byType(EditableText));
    expect(field.center.dy, closeTo(button.center.dy, 2));
    expect(find.text('Aucun résultat'), findsNothing);
    await tester.enterText(find.byType(EditableText), 'Dune');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    final message = tester.getRect(find.text('Aucun résultat'));
    expect(message.top, greaterThan(field.bottom));
    final capsule = tester.getRect(find
        .ancestor(of: find.text('Films'), matching: find.byType(FrostedSurface))
        .first);
    final popover = tester.getRect(find
        .ancestor(
            of: find.text('Aucun résultat'),
            matching: find.byType(FrostedSurface))
        .first);
    expect(popover.top - capsule.bottom,
        closeTo(AppTopNavigation.searchPopoverGap, 1));
    expect(popover.right, closeTo(capsule.right, 1));
    expect(tester.takeException(), isNull);
  });
  testWidgets('results unroll downward from the capsule', (tester) async {
    await mount(tester);
    await tester.tap(searchButton);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), 'Dune');
    await tester.pump();
    await tester.pump(AppDurations.unroll * .3);
    Rect panel() => tester.getRect(find
        .ancestor(
            of: find.byType(CircularProgressIndicator),
            matching: find.byType(FrostedSurface))
        .first);
    final opening = panel();
    await tester.pump(AppDurations.unroll);
    final open = panel();
    expect(opening.top, closeTo(open.top, .5));
    expect(opening.height, lessThan(open.height));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('the unrolled panel follows its results height smoothly',
      (tester) async {
    await mount(tester);
    await tester.tap(searchButton);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), 'Dune');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    Rect panel(Finder inside) => tester.getRect(
        find.ancestor(of: inside, matching: find.byType(FrostedSurface)).first);
    final small = panel(find.text('Aucun résultat'));
    await tester.enterText(find.byType(EditableText), 'All');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    await tester.pump(AppDurations.unroll * .3);
    final growing = panel(find.byType(ListView));
    await tester.pumpAndSettle();
    final grown = panel(find.byType(ListView));
    expect(growing.top, closeTo(small.top, .5));
    expect(growing.height, greaterThan(small.height));
    expect(growing.height, lessThan(grown.height));
    expect(tester.takeException(), isNull);
  });
  testWidgets('clearing the field hides results; leaving it empty closes it',
      (tester) async {
    await mount(tester);
    await tester.tap(searchButton);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), 'Dune');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.text('Aucun résultat'), findsOneWidget);
    await tester.enterText(find.byType(EditableText), '');
    await tester.pumpAndSettle();
    expect(find.text('Aucun résultat'), findsNothing);
    expect(find.byType(EditableText), findsOneWidget);
    await tester.tap(find.text('Films'));
    await tester.pumpAndSettle();
    expect(find.byType(EditableText), findsNothing);
    expect(searchButton, findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('results are grouped into library and titles to request',
      (tester) async {
    await mount(tester);
    await tester.tap(searchButton);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), 'Dune 2');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    final library = find.text('Dans la bibliothèque');
    final outside = find.text('À demander');
    expect(library, findsOneWidget);
    expect(outside, findsOneWidget);
    expect(
        tester.getTopLeft(library).dy, lessThan(tester.getTopLeft(outside).dy));
    expect(find.text('Dune : Deuxième partie'), findsOneWidget);
    expect(find.textContaining('Film · 2024'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('large text keeps the search accessible without overflow',
      (tester) async {
    await mount(tester, scale: 1.5, width: 1100);
    expect(tester.takeException(), isNull);
    await tester.tap(searchButton);
    await tester.pumpAndSettle();
    expect(find.byType(EditableText), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('arrow keys move between tabs and from search to its results',
      (tester) async {
    final container = await mount(tester, withResults: true);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(container.read(catalogScopeProvider).kind, BaseItemKind.movie);
    await tester.tap(searchButton);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), 'Dune');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    final ring = tester.widget<FocusRing>(find.ancestor(
        of: find.text('Le Chant du Large'), matching: find.byType(FocusRing)));
    expect(ring.focusNode!.hasFocus, isTrue);
    expect(tester.takeException(), isNull);
  });
  testWidgets('tools retain a visible route back to the catalogue',
      (tester) async {
    for (final route in [const SeerrRoute(), const ArrHomeRoute()]) {
      await mount(tester, route: route);
      expect(find.text('À la une'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });
  testWidgets('Ctrl K opens the same search panel', (tester) async {
    await mount(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(find.byType(EditableText), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('large searches retain access to all results', (tester) async {
    await mount(tester);
    await tester.tap(searchButton);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), 'All');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -2000));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(find.text('Voir tous les résultats'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('capsule fits its commands and labels share a centre line',
      (tester) async {
    await mount(tester);
    final glass = tester.getRect(find.byType(BackdropFilter));
    expect(glass.width, lessThan(1200));
    final baseline = tester.getCenter(find.text('Films')).dy;
    for (final label in ['À la une', 'Séries', 'Découvrir']) {
      expect(tester.getCenter(find.text(label)).dy, closeTo(baseline, 1));
    }
    expect(tester.getCenter(searchButton).dy, closeTo(baseline, 1));
    expect(find.text('Rechercher'), findsNothing);
  });
  testWidgets(
      'library content scrolls behind chrome instead of a fixed top gap',
      (tester) async {
    await mount(tester, route: LibrarySearchRoute());
    final content = find.byKey(const ValueKey('catalog-content'));
    expect(tester.getTopLeft(content).dy, closeTo(0, 1));
    expect(AdaptiveLayout.of(tester.element(content)).topBarHeight,
        greaterThanOrEqualTo(AppTopNavigation.contentInset));
  });
  testWidgets('management routes reserve top space inside scrolling content',
      (tester) async {
    for (final route in [
      const ArrHomeRoute(),
      const SeerrRoute(),
      const SettingsRoute()
    ]) {
      await mount(tester, route: route);
      final content = find.byKey(const ValueKey('catalog-content'));
      expect(tester.getTopLeft(content).dy, closeTo(0, 1));
      expect(AdaptiveLayout.of(tester.element(content)).topBarHeight,
          greaterThanOrEqualTo(AppTopNavigation.contentInset));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });
}
