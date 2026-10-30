import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/home_visual_fixture.dart' show homeArtwork;
import 'support/rest_visual_fixture.dart';
import 'seerr_discovery_section_test.dart' show PendingDetailsRouter;

void main() {
  setUpAll(() async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
        const MethodChannel('window_manager'), (_) async => null);
    messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (_) async => Directory.systemTemp.path);
    messenger.setMockMethodCallHandler(
        const MethodChannel('flutter_keyboard_visibility'), (_) async => null);
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
  for (final screen in [
    'detail',
    'movie',
    'episode-detail',
    'series-detail',
    'submenu',
    'episodes',
    'library',
    'settings',
    'requests',
    'arr'
  ]) {
    for (final large in [false, true]) {
      testWidgets('$screen ${large ? 'large text' : 'desktop'}',
          (tester) async {
        final size = large ? const Size(1280, 1000) : const Size(1440, 1000);
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final router = PendingDetailsRouter();
        addTearDown(router.dispose);
        await tester.runAsync(() async {
          final ready = Completer<void>();
          final stream =
              homeArtwork.imageProvider.resolve(const ImageConfiguration());
          final listener = ImageStreamListener((_, __) {
            if (!ready.isCompleted) ready.complete();
          });
          stream.addListener(listener);
          await ready.future;
          stream.removeListener(listener);
        });
        await tester.pumpWidget(restVisualFixture(
            screen: screen,
            viewport: size,
            router: router,
            textScale: large ? 1.5 : 1));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (screen == 'library') {
          final field = tester.widget<TextField>(find.byType(TextField).first);
          expect(field.decoration?.enabledBorder, InputBorder.none);
          expect(field.decoration?.focusedBorder, InputBorder.none);
        }
        await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
                'fixtures/rest/$screen-${large ? 'large' : 'desktop'}.png'));
        if (screen == 'movie') {
          await tester.tap(find.textContaining('Audio ·'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await expectLater(
              find.byType(MaterialApp),
              matchesGoldenFile(
                  'fixtures/rest/movie-audio-menu-${large ? 'large' : 'desktop'}.png'));
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      });
    }
  }
}
