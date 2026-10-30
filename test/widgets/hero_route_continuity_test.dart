import 'package:kinos/screens/dashboard/home_hero_backdrop.dart';
import 'package:kinos/util/adaptive_layout/adaptive_layout_model.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/l10n/generated/app_localizations.dart';
import 'package:kinos/providers/theme/palette_service_provider.dart';
import 'package:kinos/routes/auto_router.gr.dart';
import 'package:kinos/screens/dashboard/home_hero_section.dart';
import 'package:kinos/screens/shared/media_detail_scaffold.dart';
import 'package:kinos/screens/shared/media_navigation.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/theme/palette_service.dart';
import 'package:kinos/util/adaptive_layout/adaptive_layout.dart';
import 'package:kinos/util/motion_input.dart';
import 'package:kinos/util/poster_defaults.dart';
import 'package:kinos/widgets/shared/page_motion.dart';
import 'support/home_visual_fixture.dart' show fixtureMovies;

class _Router extends RootStackRouter {
  final movies = fixtureMovies();
  @override
  List<AutoRoute> get routes => [
        AutoRoute(
            initial: true,
            page: PageInfo(DashboardRoute.name,
                builder: (_) => Scaffold(
                        body: CustomScrollView(slivers: [
                      HomeHeroSection(
                          heroItems: [movies.first],
                          resumeItems: [movies.first],
                          contentPadding:
                              const EdgeInsets.all(AppSpacing.screenPadding))
                    ])))),
        CustomRoute(
            customRouteBuilder: mediaPageRoute,
            page: PageInfo(DetailsRoute.name, builder: (data) {
              final args = data.argsAs<DetailsRouteArgs>();
              return MediaNavigationScope(
                  tag: args.tag,
                  child: MediaDetailScaffold(
                      item: args.item,
                      label: 'Film',
                      title: args.item!.title,
                      cinematic: true,
                      backDrops: args.item!.images,
                      metaLine: '2025',
                      content: (_, __) => []));
            })),
      ];
}

void main() {
  testWidgets(
      'real carousel artwork and title fly into a real detail scaffold and back',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('window_manager'), (_) async => null);
    final router = _Router();
    addTearDown(router.dispose);
    final cache = InMemoryPaletteCache();
    for (final movie in router.movies) {
      await cache.write(movie.id, const Color(0xFF245E61).toARGB32());
    }
    await tester.pumpWidget(ProviderScope(
        overrides: [
          paletteServiceProvider.overrideWithValue(PaletteService(cache)),
        ],
        child: MaterialApp.router(
            routerConfig: router.config(),
            theme: buildAppTheme(),
            locale: const Locale('fr'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (_, child) => MotionInputBoundary(
                child: AdaptiveLayout(
                    data: const AdaptiveLayoutModel(
                        viewSize: ViewSize.desktop,
                        layoutMode: LayoutMode.single,
                        inputDevice: InputDevice.pointer,
                        platform: TargetPlatform.linux,
                        isDesktop: true,
                        posterDefaults: PosterDefaults(size: 180, ratio: 2 / 3),
                        controller: {},
                        sideBarWidth: 68,
                        topBarHeight: 0,
                        statusBarHeight: 0),
                    child: child!)))));
    await tester.pumpAndSettle();
    expect(
        tester
            .widgetList<Hero>(find.byType(Hero))
            .map((hero) => hero.tag)
            .toSet()
            .length,
        3);
    await tester.tap(find.byIcon(Icons.info_outline));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(find.byType(MediaDetailScaffold), findsOneWidget);
    expect(
        tester.widget<HomeHeroBackdrop>(find.byType(HomeHeroBackdrop)).fallback,
        same(router.movies.first.images!.backDrop!.first));
    router.maybePop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(find.byType(HomeHeroSection), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
