import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/jellyfin/jellyfin_open_api.swagger.dart' show BaseItemDto;
import 'package:kinos/models/items/movie_model.dart';
import 'package:kinos/routes/auto_router.gr.dart';
import 'package:kinos/screens/shared/media_navigation.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/motion_input.dart';
import 'package:kinos/widgets/shared/page_motion.dart';

class _Router extends RootStackRouter {
  _Router(this.home);
  final Widget home;
  @override
  List<AutoRoute> get routes => [
        AutoRoute(
            initial: true,
            page: PageInfo(DashboardRoute.name, builder: (_) => home)),
        CustomRoute(
            page: PageInfo(DetailsRoute.name, builder: (data) {
              final args = data.argsAs<DetailsRouteArgs>();
              return MediaNavigationScope(
                  tag: args.tag,
                  child: Material(
                      child: Column(children: [
                    const SizedBox(
                        height: 300,
                        width: 700,
                        child: MediaArtwork(
                            child: ColoredBox(color: Colors.blue))),
                    TextButton(
                        onPressed: () => data.router.maybePop(),
                        child: const Text('Retour')),
                  ])));
            }),
            customRouteBuilder: mediaPageRoute),
      ];
}

void main() {
  for (final reduced in [false, true]) {
    testWidgets(
        'artwork round trip retains source focus and scroll (reduced: $reduced)',
        (tester) async {
      final scroll = ScrollController(initialScrollOffset: 100);
      addTearDown(scroll.dispose);
      final movie = MovieModel.fromBaseDto(
          const BaseItemDto(id: 'movie', name: 'Film'), null);
      late FocusNode origin;
      final router = _Router(ListView(controller: scroll, children: [
        const SizedBox(height: 150),
        for (var i = 0; i < 2; i++)
          MediaNavigation(builder: (context) {
            if (i == 0) origin = MediaNavigationScope.focusOf(context)!;
            return SizedBox(
                height: 100,
                child: FocusRing(
                    focusNode: MediaNavigationScope.focusOf(context),
                    onActivate: () => openMediaDetails(context, movie),
                    child: MediaArtwork(
                        child: ColoredBox(
                            color: Colors.grey, child: Text('Ouvrir $i')))));
          }),
        const SizedBox(height: 2000),
      ]));
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(
          routerConfig: router.config(),
          theme: ThemeData.dark(),
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
              child: MotionInputBoundary(child: child!))));
      await tester.pumpAndSettle();
      final tags = tester
          .widgetList<Hero>(find.byType(Hero))
          .map((hero) => hero.tag)
          .toSet();
      expect(tags.length, reduced ? 0 : 2);
      await tester.tap(find.text('Ouvrir 0'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(find.text('Retour'), findsOneWidget);
      await tester.tap(find.text('Retour'));
      await tester.pumpAndSettle();
      expect(scroll.offset, 100);
      expect(origin.hasFocus, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('a flight can reverse early and motion preference can change',
      (tester) async {
    final movie =
        MovieModel.fromBaseDto(const BaseItemDto(id: 'm', name: 'Film'), null);
    var reduced = false;
    late StateSetter update;
    final router = _Router(MediaNavigation(
        builder: (context) => FocusRing(
            onActivate: () => openMediaDetails(context, movie),
            focusNode: MediaNavigationScope.focusOf(context),
            child: const MediaArtwork(
                child: SizedBox(height: 100, child: Text('Ouvrir'))))));
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(
        routerConfig: router.config(),
        builder: (context, child) =>
            StatefulBuilder(builder: (context, setState) {
              update = setState;
              return MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(disableAnimations: reduced),
                  child: MotionInputBoundary(child: child!));
            })));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ouvrir'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    router.maybePop();
    await tester.pumpAndSettle();
    expect(find.text('Ouvrir'), findsOneWidget);
    await tester.tap(find.text('Ouvrir'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    update(() => reduced = true);
    await tester.pumpAndSettle();
    expect(find.text('Retour'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('keyboard navigation has zero route duration', (tester) async {
    final movie =
        MovieModel.fromBaseDto(const BaseItemDto(id: 'm', name: 'Film'), null);
    final router = _Router(MediaNavigation(
        builder: (context) => FocusRing(
            autofocus: true,
            onActivate: () => openMediaDetails(context, movie),
            child: const Text('Ouvrir'))));
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(
        routerConfig: router.config(),
        builder: (_, child) => MotionInputBoundary(child: child!)));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    final context = tester.element(find.text('Retour'));
    expect(ModalRoute.of(context)!.transitionDuration, Duration.zero);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
