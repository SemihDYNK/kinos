import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/jellyfin/jellyfin_open_api.swagger.dart';
import 'package:kinos/models/items/images_models.dart';
import 'package:kinos/models/items/movie_model.dart';
import 'package:kinos/screens/dashboard/hero_carousel.dart';

import 'seerr_discovery_section_test.dart' show shell;

void main() {
  testWidgets('hero uses about three quarters of the viewport height',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final movie = MovieModel.fromBaseDto(
        const BaseItemDto(id: 'film', name: 'Un film'), null);
    await tester.pumpWidget(ProviderScope(
        child: shell(SliverToBoxAdapter(child: HeroCarousel(items: [movie])))));
    await tester.pumpAndSettle();
    final height = tester.getSize(find.byType(HeroCarousel)).height;
    expect(height, inInclusiveRange(630, 720));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  for (final available in [true, false]) {
    testWidgets(
        'hero ${available ? 'shows logo' : 'keeps title if logo fails'}',
        (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final logo = ImageData(
          path: File(available
                  ? 'test/widgets/fixtures/home/coast.png'
                  : '/tmp/kinos-absent-title-card.png')
              .absolute
              .path,
          key: available ? 'title-card' : 'missing-title-card');
      if (available) {
        await tester.runAsync(() async {
          final ready = Completer<void>();
          final stream = logo.imageProvider.resolve(const ImageConfiguration());
          final listener = ImageStreamListener((_, __) => ready.complete());
          stream.addListener(listener);
          await ready.future;
          stream.removeListener(listener);
        });
      }
      final movie = MovieModel.fromBaseDto(
              const BaseItemDto(id: 'logo-film', name: 'Titre accessible'),
              null)
          .copyWith(images: ImagesData(logo: logo));
      await tester.pumpWidget(ProviderScope(
          child:
              shell(SliverToBoxAdapter(child: HeroCarousel(items: [movie])))));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      if (available) {
        expect(find.image(logo.imageProvider), findsOneWidget);
        expect(find.text('TITRE ACCESSIBLE'), findsNothing);
        final image = tester.widget<Image>(find.image(logo.imageProvider));
        expect(image.fit, BoxFit.contain);
      } else {
        expect(find.text('TITRE ACCESSIBLE'), findsOneWidget);
      }
      expect(find.bySemanticsLabel('Titre accessible'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }
}
