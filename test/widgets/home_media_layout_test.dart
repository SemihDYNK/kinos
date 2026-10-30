import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/jellyfin/jellyfin_open_api.swagger.dart';
import 'package:kinos/models/items/movie_model.dart';
import 'package:kinos/screens/dashboard/continue_watching_section.dart';
import 'package:kinos/screens/dashboard/single_row_section.dart';
import 'package:kinos/util/kinos_image.dart';
import 'package:kinos/widgets/shared/media_thumbnail.dart';
import 'package:kinos/theme/app_theme.dart';
import 'seerr_discovery_section_test.dart' show shell;

void main() {
  testWidgets('resume stays on one row and scrolls with buttons and keyboard',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final movies = List.generate(
        12,
        (i) => MovieModel.fromBaseDto(
            BaseItemDto(id: '$i', name: 'Reprise $i'), null));
    await tester.pumpWidget(ProviderScope(
        child: shell(ContinueWatchingSection(
            items: movies, contentPadding: const EdgeInsets.all(32)))));
    await tester.pumpAndSettle();
    final firstY = tester.getTopLeft(find.text('Reprise 0')).dy;
    expect(tester.getTopLeft(find.text('Reprise 11')).dy, closeTo(firstY, .01));
    final before = tester.getTopLeft(find.text('Reprise 0')).dx;
    await tester.tap(find.byTooltip('Défiler vers la droite'));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Reprise 0')).dx, lessThan(before));
    final first = tester.widget<FocusRing>(find
        .ancestor(of: find.text('Reprise 0'), matching: find.byType(FocusRing))
        .first);
    first.focusNode!.requestFocus();
    await tester.pumpAndSettle();
    for (var i = 0; i < 11; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
    }
    final last = tester.widget<FocusRing>(find
        .ancestor(of: find.text('Reprise 11'), matching: find.byType(FocusRing))
        .first);
    expect(last.focusNode!.hasFocus, isTrue);
    expect(
        tester.getRect(find.text('Reprise 11')).right, lessThanOrEqualTo(1440));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('sparse and full resume rows use the same local width',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final movies = List.generate(
        4,
        (i) => MovieModel.fromBaseDto(
            BaseItemDto(id: '$i', name: 'Film $i'), null));
    Future<double> measure(int count) async {
      await tester.pumpWidget(ProviderScope(
          child: shell(SliverPadding(
        padding: const EdgeInsets.only(left: 264),
        sliver: ContinueWatchingSection(
            items: movies.take(count).toList(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 32)),
      ))));
      await tester.pumpAndSettle();
      return tester.getSize(find.byType(MediaThumbnail).first).width;
    }

    final sparse = await measure(1);
    final full = await measure(4);
    expect(sparse, closeTo(full, .01));
    await tester.pumpWidget(const SizedBox.shrink());
  });
  for (final viewport in [const Size(1280, 900), const Size(1920, 1080)]) {
    for (final textScale in [1.0, 1.5]) {
      testWidgets(
          'poster images keep classic geometry at ${viewport.width} and text scale $textScale',
          (tester) async {
        tester.view.physicalSize = viewport;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final movies = List.generate(
            12,
            (i) => MovieModel.fromBaseDto(
                BaseItemDto(id: '$i', name: 'Titre $i'), null));
        await tester.pumpWidget(ProviderScope(
            child: shell(
                SingleRowSection(
                    title: 'Films',
                    items: movies,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 64)),
                textScale: textScale)));
        await tester.pumpAndSettle();
        final images = find.byType(KinosImage);
        expect(images.evaluate().length, inInclusiveRange(6, 8));
        for (final element in images.evaluate()) {
          final size =
              tester.getSize(find.byElementPredicate((e) => e == element));
          expect(size.width / size.height, closeTo(2 / 3, .001));
        }
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
  for (final scale in [1.0, 1.5]) {
    testWidgets('resume images remain 16:9 at text scale $scale',
        (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final movies = List.generate(
          4,
          (i) => MovieModel.fromBaseDto(
              BaseItemDto(id: '$i', name: 'Un long titre de cinéma $i'), null));
      await tester.pumpWidget(ProviderScope(
          child: shell(
              ContinueWatchingSection(
                  items: movies, contentPadding: const EdgeInsets.all(32)),
              textScale: scale)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (final element in find.byType(MediaThumbnail).evaluate()) {
        final size =
            tester.getSize(find.byElementPredicate((e) => e == element));
        expect(size.width / size.height, closeTo(16 / 9, .01));
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
