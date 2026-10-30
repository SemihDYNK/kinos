import 'package:kinos/screens/shared/media_detail_scaffold.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/jellyfin/jellyfin_open_api.swagger.dart';
import 'package:kinos/models/items/movie_model.dart';
import 'package:kinos/models/items/series_model.dart';
import 'package:kinos/models/items/images_models.dart';
import 'package:kinos/models/item_base_model.dart';
import 'package:kinos/screens/dashboard/home_hero_backdrop.dart';
import 'package:kinos/providers/theme/app_theme_provider.dart';
import 'package:kinos/providers/theme/palette_service_provider.dart';
import 'package:kinos/screens/dashboard/hero_carousel.dart';
import 'package:kinos/theme/palette_service.dart';
import 'support/home_visual_fixture.dart' show fixtureMovies, homeArtwork;
import 'seerr_discovery_section_test.dart' show shell;

class PendingPaletteService extends PaletteService {
  PendingPaletteService() : super(InMemoryPaletteCache());
  final pending = <String, Completer<HeroPalette>>{};
  @override
  Future<HeroPalette> forItem(
          {required String itemId, required ImageProvider image}) =>
      (pending[itemId] ??= Completer<HeroPalette>()).future;
}

void main() {
  testWidgets('leaving a detail restores the retained page tint',
      (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('window_manager'), (_) async => null);
    final service = PaletteService(InMemoryPaletteCache());
    final previous = service.fromSeed(const Color(0xFF70452A));
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(heroPaletteProvider.notifier).state = previous;
    var visible = true;
    late StateSetter update;
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: shell(SliverToBoxAdapter(
            child: SizedBox(
                height: 900,
                child: StatefulBuilder(builder: (context, setState) {
                  update = setState;
                  return visible
                      ? MediaDetailScaffold(
                          label: 'Film',
                          title: 'Film',
                          metaLine: '',
                          content: (_, __) => [])
                      : const SizedBox.shrink();
                }))))));
    await tester.pumpAndSettle();
    container.read(heroPaletteProvider.notifier).state =
        service.fromSeed(const Color(0xFF246B69));
    update(() => visible = false);
    await tester.pumpAndSettle();
    expect(container.read(heroPaletteProvider), same(previous));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'late palette cannot replace active slide and missing image clears tint',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => '/tmp');
    await tester.runAsync(() async {
      final done = Completer<void>();
      final stream =
          homeArtwork.imageProvider.resolve(const ImageConfiguration());
      final listener = ImageStreamListener((_, __) {
        if (!done.isCompleted) done.complete();
      });
      stream.addListener(listener);
      await done.future;
      stream.removeListener(listener);
    });
    final service = PendingPaletteService();
    final container = ProviderContainer(
        overrides: [paletteServiceProvider.overrideWithValue(service)]);
    addTearDown(container.dispose);
    final movies = <ItemBaseModel>[
      SeriesModel.fromBaseDto(
              const BaseItemDto(id: 'fixture-0', name: 'Série'), null)
          .copyWith(
              images: ImagesData(
                  primary: homeArtwork.copyWith(key: 'portrait'),
                  backDrop: [homeArtwork])),
      fixtureMovies()[1],
    ];
    movies.add(MovieModel.fromBaseDto(
        const BaseItemDto(id: 'missing', name: 'Sans image'), null));
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: shell(SliverToBoxAdapter(child: HeroCarousel(items: movies)))));
    await tester.pump();
    expect(
        tester
            .widget<HomeHeroBackdrop>(find.byType(HomeHeroBackdrop))
            .image
            ?.key,
        'coast');
    final previousPalette = PaletteService(InMemoryPaletteCache())
        .fromSeed(const Color(0xFF70452A));
    container.read(heroPaletteProvider.notifier).state = previousPalette;
    final next = find.byIcon(Icons.chevron_right_rounded);
    await tester.tap(next);
    await tester.pump();
    expect(container.read(heroPaletteProvider), previousPalette,
        reason:
            'Keep the previous tint until the next one is ready, without a grey flash');
    final palette = PaletteService(InMemoryPaletteCache())
        .fromSeed(const Color(0xFF246B69));
    service.pending['fixture-1']!.complete(palette);
    await tester.pump();
    service.pending['fixture-0']!.complete(HeroPalette.fallback);
    await tester.pump();
    expect(container.read(heroPaletteProvider).tint, palette.tint);
    await tester.tap(next);
    await tester.pump();
    expect(container.read(heroPaletteProvider).isFallback, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
