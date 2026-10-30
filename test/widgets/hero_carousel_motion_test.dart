import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/jellyfin/jellyfin_open_api.swagger.dart';
import 'package:kinos/models/items/movie_model.dart';
import 'package:kinos/screens/dashboard/hero_carousel.dart';
import 'package:kinos/util/motion_input.dart';
import 'package:kinos/screens/dashboard/home_hero_backdrop.dart';
import 'package:kinos/models/items/images_models.dart';
import 'support/home_visual_fixture.dart' show homeArtwork;
import 'seerr_discovery_section_test.dart' show shell;

void main() {
  final movies = [
    for (var i = 0; i < 3; i++)
      MovieModel.fromBaseDto(
          BaseItemDto(id: '$i', name: 'Film $i', overview: 'Résumé $i'), null)
  ];
  double opacity(WidgetTester tester, String role) =>
      tester.widget<Opacity>(find.byKey(ValueKey(role))).opacity;
  Future<void> mount(WidgetTester tester,
      {bool reduced = false, ValueNotifier<bool>? preference}) async {
    final reducedPreference = preference ?? ValueNotifier(reduced);
    if (preference == null) addTearDown(reducedPreference.dispose);
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
        child: shell(SliverToBoxAdapter(
      child: ValueListenableBuilder<bool>(
          valueListenable: reducedPreference,
          builder: (context, reduced, _) => MediaQuery(
                data:
                    MediaQuery.of(context).copyWith(disableAnimations: reduced),
                child: MotionInputBoundary(child: HeroCarousel(items: movies)),
              )),
    ))));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'hero stages title and synopsis without replay on mount or stale controls',
      (tester) async {
    await mount(tester);
    expect(opacity(tester, 'hero-title-reveal'), 1);
    await tester.tap(find.byIcon(Icons.chevron_right_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    expect(find.text('2 / 3'), findsOneWidget);
    expect(opacity(tester, 'hero-title-reveal'), inExclusiveRange(0, 1));
    expect(opacity(tester, 'hero-synopsis-reveal'), 0);
    await tester.pump(const Duration(milliseconds: 100));
    expect(opacity(tester, 'hero-synopsis-reveal'), inExclusiveRange(0, 1));
    await tester.tap(find.byIcon(Icons.chevron_right_rounded));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.chevron_left_rounded));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('2 / 3'), findsOneWidget);
    expect(find.text('FILM 1'), findsOneWidget);
    expect(find.text('FILM 2'), findsNothing);
    expect(find.byWidgetPredicate((widget) => widget is FilledButton),
        findsOneWidget);
    expect(opacity(tester, 'hero-title-reveal'), 1);
    expect(opacity(tester, 'hero-synopsis-reveal'), 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('reducing motion completes an active title entrance immediately',
      (tester) async {
    final reduced = ValueNotifier(false);
    addTearDown(reduced.dispose);
    await mount(tester, preference: reduced);
    await tester.tap(find.byIcon(Icons.chevron_right_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    reduced.value = true;
    await tester.pump();
    await tester.pump();
    expect(opacity(tester, 'hero-title-reveal'), 1);
    expect(opacity(tester, 'hero-synopsis-reveal'), 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('backdrop supports rapid A B A and reduced motion mid-fade',
      (tester) async {
    await tester.runAsync(() => precacheImage(
        homeArtwork.imageProvider, tester.element(find.byType(View))));
    final image = ValueNotifier<ImageData>(homeArtwork);
    final reduced = ValueNotifier(false);
    addTearDown(image.dispose);
    addTearDown(reduced.dispose);
    await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
            home: ValueListenableBuilder<bool>(
      valueListenable: reduced,
      builder: (context, reduce, _) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduce),
        child: SizedBox(
            width: 600,
            height: 300,
            child: ValueListenableBuilder<ImageData>(
                valueListenable: image,
                builder: (_, value, __) => HomeHeroBackdrop(image: value))),
      ),
    ))));
    await tester.pumpAndSettle();
    for (var i = 0; i < 8; i++) {
      image.value = homeArtwork.copyWith(key: i.isEven ? 'other' : 'coast');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      expect(tester.takeException(), isNull);
    }
    reduced.value = true;
    await tester.pump();
    await tester.pump();
    expect(
        find.descendant(
            of: find.byType(HomeHeroBackdrop),
            matching: find.byType(AnimatedSwitcher)),
        findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final keyboard in [false, true]) {
    testWidgets(
        'hero text is immediate for ${keyboard ? 'keyboard' : 'reduced motion'}',
        (tester) async {
      await mount(tester, reduced: !keyboard);
      if (keyboard) {
        await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
        tester
            .widget<IconButton>(
                find.widgetWithIcon(IconButton, Icons.chevron_right_rounded))
            .onPressed!();
      } else {
        await tester.tap(find.byIcon(Icons.chevron_right_rounded));
      }
      await tester.pump();
      await tester.pump();
      expect(opacity(tester, 'hero-title-reveal'), 1);
      expect(opacity(tester, 'hero-synopsis-reveal'), 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
