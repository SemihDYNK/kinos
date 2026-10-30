import 'dart:ui' as ui;
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/screens/dashboard/home_hero_section.dart';
import 'package:kinos/screens/dashboard/hero_carousel.dart';
import 'package:kinos/theme/app_theme.dart';
import 'support/home_visual_fixture.dart';
import 'seerr_discovery_section_test.dart' show PendingDetailsRouter;

void main() {
  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => Directory.systemTemp.path,
    );
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final family in manifest) {
      final loader = FontLoader(family['family'] as String);
      for (final font in family['fonts'] as List) {
        loader.addFont(rootBundle.load(font['asset'] as String));
      }
      await loader.load();
    }
  });
  final cases = [
    (
      name: 'desktop-1280',
      size: const Size(1280, 800),
      scale: 1.0,
      density: AppDensity.desk,
      empty: false,
      long: false,
      expanded: false,
      emptyHero: false
    ),
    (
      name: 'desktop-1440',
      size: const Size(1440, 900),
      scale: 1.0,
      density: AppDensity.desk,
      empty: false,
      long: false,
      expanded: false,
      emptyHero: false
    ),
    (
      name: 'desktop-1920',
      size: const Size(1920, 1080),
      scale: 1.0,
      density: AppDensity.desk,
      empty: false,
      long: false,
      expanded: false,
      emptyHero: false
    ),
    (
      name: 'large-text',
      size: const Size(1280, 800),
      scale: 1.5,
      density: AppDensity.desk,
      empty: false,
      long: true,
      expanded: false,
      emptyHero: false
    ),
    (
      name: 'empty-resume',
      size: const Size(1440, 900),
      scale: 1.0,
      density: AppDensity.desk,
      empty: true,
      long: false,
      expanded: false,
      emptyHero: false
    ),
    (
      name: 'couch',
      size: const Size(1920, 1080),
      scale: 1.0,
      density: AppDensity.couch,
      empty: false,
      long: false,
      expanded: false,
      emptyHero: false
    ),
    (
      name: 'expanded-navigation',
      size: const Size(1280, 800),
      scale: 1.5,
      density: AppDensity.desk,
      empty: false,
      long: true,
      expanded: true,
      emptyHero: false
    ),
    (
      name: 'empty-hero',
      size: const Size(1440, 900),
      scale: 1.0,
      density: AppDensity.desk,
      empty: false,
      long: false,
      expanded: false,
      emptyHero: true
    ),
  ];
  for (final c in cases) {
    testWidgets('home layout ${c.name}', (tester) async {
      tester.view.physicalSize = c.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final router = PendingDetailsRouter();
      addTearDown(router.dispose);
      // File decoding is real asynchronous IO; preload it before deterministic pumps.
      await tester.runAsync(() async {
        final stream =
            homeArtwork.imageProvider.resolve(const ImageConfiguration());
        final done = Completer<void>();
        final listener = ImageStreamListener((_, __) {
          if (!done.isCompleted) done.complete();
        }, onError: (Object error, StackTrace? stack) {
          if (!done.isCompleted) done.completeError(error, stack);
        });
        stream.addListener(listener);
        await done.future;
        stream.removeListener(listener);
      });
      await tester.pumpWidget(RepaintBoundary(
          child: homeVisualFixture(
              viewport: c.size,
              router: router,
              textScale: c.scale,
              density: c.density,
              emptyResume: c.empty,
              longTitle: c.long,
              expandedNavigation: c.expanded,
              emptyHero: c.emptyHero)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(HomeHeroSection), findsOneWidget);
      await expectLater(find.byType(MaterialApp),
          matchesGoldenFile('fixtures/home/${c.name}.png'));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }
  testWidgets('hero extends behind floating rail but ends before later rows',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = PendingDetailsRouter();
    addTearDown(router.dispose);
    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: homeVisualFixture(
            viewport: const Size(1440, 1000),
            router: router,
            emptyResume: true,
            reducedMotion: true)));
    await tester.pumpAndSettle();
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final bytes = await tester.runAsync(() async {
      final image = await boundary.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      return data!;
    });
    final offset = (500 * 1440 + 90) * 4;
    final belowHero =
        tester.getRect(find.byType(HeroCarousel)).bottom.ceil() + 5;
    final afterOffset = (belowHero * 1440 + 1400) * 4;
    expect(bytes!.getUint8(afterOffset), 10);
    expect(bytes.getUint8(afterOffset + 1), 10);
    expect(bytes.getUint8(afterOffset + 2), 10);
    expect([
      bytes.getUint8(offset),
      bytes.getUint8(offset + 1),
      bytes.getUint8(offset + 2)
    ], isNot([10, 10, 10]),
        reason: 'The gutter beside the capsule must expose the hero');
    expect(tester.getRect(find.byType(HeroCarousel)).left, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
