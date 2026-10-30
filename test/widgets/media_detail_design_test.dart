import 'package:kinos/models/items/media_streams_model.dart';
import 'package:kinos/screens/details_screens/components/movie_hero_content.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/models/items/images_models.dart';
import 'package:kinos/screens/shared/media_detail_scaffold.dart';
import 'package:kinos/screens/dashboard/home_hero_backdrop.dart';
import 'package:kinos/util/adaptive_layout/adaptive_layout.dart';
import 'seerr_discovery_section_test.dart' show shell;

void main() {
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('window_manager'), (_) async => null);
  });
  for (final scenario in [
    (episode: false, parent: false),
    (episode: true, parent: false),
    (episode: true, parent: true)
  ]) {
    final episode = scenario.episode;
    testWidgets(
        episode
            ? 'episode keeps its own title, parent loaded: ${scenario.parent}'
            : 'detail adopts full frame hero and metadata logo',
        (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final logo = ImageData(
          path: File('test/widgets/fixtures/home/coast.png').absolute.path,
          key: 'detail-logo');
      await tester.runAsync(() async {
        final ready = Completer<void>();
        final stream = logo.imageProvider.resolve(const ImageConfiguration());
        final listener = ImageStreamListener((_, __) => ready.complete());
        stream.addListener(listener);
        await ready.future;
        stream.removeListener(listener);
      });
      await tester.pumpWidget(ProviderScope(
          child: shell(SliverToBoxAdapter(
              child: SizedBox(
                  height: 900,
                  child: Builder(
                      builder: (context) => AdaptiveLayout(
                          data: AdaptiveLayout.of(context)
                              .copyWith(sideBarWidth: 264),
                          child: MediaDetailScaffold(
                              label: 'Film',
                              title: episode ? 'L’orage' : 'Le film',
                              parentLink: scenario.parent
                                  ? (label: 'Série', onTap: () {})
                                  : null,
                              metaLine: '2025',
                              cinematic: true,
                              useTitleLogo: !episode,
                              playLabel: episode ? 'Lire S1 · É2' : null,
                              heroContent: MovieHeroContent(
                                  summary:
                                      'Le synopsis du film est intégré au bandeau.',
                                  streams: MediaStreamsModel(
                                      versionStreams: const []),
                                  onStreamsChanged: (_) {}),
                              backDrops: ImagesData(logo: logo),
                              onPlay: () {},
                              content: (context, padding) => []))))))));
      await tester.pumpAndSettle();
      expect(find.image(logo.imageProvider),
          episode ? findsNothing : findsOneWidget);
      if (episode) {
        expect(find.text('L’ORAGE'), findsOneWidget);
        expect(find.text('Lire S1 · É2'), findsOneWidget);
      }
      expect(
          find.text('Série'), scenario.parent ? findsOneWidget : findsNothing);
      {
        expect(tester.getSize(find.byType(HomeHeroBackdrop)).height,
            greaterThanOrEqualTo(760));
        expect(
            tester
                .widget<HomeHeroBackdrop>(find.byType(HomeHeroBackdrop))
                .cinematic,
            isTrue);
        final summary = tester
            .getRect(find.text('Le synopsis du film est intégré au bandeau.'));
        expect(
            summary.bottom,
            lessThanOrEqualTo(
                tester.getRect(find.byType(HomeHeroBackdrop)).bottom));
        expect(
            summary.top,
            greaterThan(tester
                .getRect(
                    find.byWidgetPredicate((widget) => widget is FilledButton))
                .bottom));
      }
      expect(find.byType(HomeHeroBackdrop), findsOneWidget);
      final tail =
          tester.getRect(find.byKey(const ValueKey('detail-tint-fade')));
      expect(tail.top,
          closeTo(tester.getRect(find.byType(HomeHeroBackdrop)).bottom, .01));
      expect(tail.height, 112);
      expect(tester.getRect(find.byType(HomeHeroBackdrop)).left, 0);
      expect(tester.getRect(find.byType(HomeHeroBackdrop)).top, 0);
      expect(
          tester
              .getRect(
                  find.byWidgetPredicate((widget) => widget is FilledButton))
              .left,
          greaterThan(264));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }
}
