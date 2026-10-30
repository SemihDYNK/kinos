import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinos/models/items/movie_model.dart';
import 'package:kinos/jellyfin/jellyfin_open_api.swagger.dart' show BaseItemDto;
import 'package:kinos/screens/dashboard/hero_carousel.dart';
import 'package:kinos/providers/theme/palette_service_provider.dart';
import 'package:kinos/theme/palette_service.dart';
import 'seerr_discovery_section_test.dart' show shell;
import 'package:kinos/models/items/images_models.dart';
import 'package:kinos/screens/shared/media_hero_title.dart';

class _PendingImage extends ImageProvider<_PendingImage> {
  final result = Completer<ImageInfo>();
  int loads = 0;
  @override
  Future<_PendingImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);
  @override
  ImageStreamCompleter loadImage(
      _PendingImage key, ImageDecoderCallback decode) {
    loads++;
    return OneFrameImageStreamCompleter(result.future);
  }
}

class _TestImage extends ImageData {
  _TestImage(this.provider) : super(path: 'pending-logo', key: 'pending-logo');
  final ImageProvider provider;
  @override
  ImageProvider get imageProvider => provider;
}

void main() {
  testWidgets(
      'carousel preloads only adjacent backdrops and logos, including wraparound',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final providers = List.generate(4, (_) => _PendingImage());
    final backdrops = List.generate(4, (_) => _PendingImage());
    final movies = [
      for (var i = 0; i < providers.length; i++)
        MovieModel.fromBaseDto(BaseItemDto(id: '$i', name: 'Film $i'), null)
            .copyWith(
                images: ImagesData(
                    logo: _TestImage(providers[i]),
                    backDrop: [_TestImage(backdrops[i])]))
    ];
    final palettes = InMemoryPaletteCache();
    for (var i = 0; i < movies.length; i++) {
      await palettes.write('$i', const Color(0xFF245E61).toARGB32());
    }
    await tester.pumpWidget(ProviderScope(overrides: [
      paletteServiceProvider.overrideWithValue(PaletteService(palettes))
    ], child: shell(SliverToBoxAdapter(child: HeroCarousel(items: movies)))));
    await tester.pump();
    expect(providers.map((provider) => provider.loads).toList(), [1, 1, 0, 1]);
    expect(backdrops.map((provider) => provider.loads).toList(), [1, 1, 0, 1]);
    await tester.tap(find.byIcon(Icons.chevron_right_rounded));
    await tester.pump();
    await tester.pump();
    expect(find.text('2 / 4'), findsOneWidget);
    expect(providers.map((provider) => provider.loads).toList(), [1, 1, 1, 1]);
    expect(backdrops.map((provider) => provider.loads).toList(), [1, 1, 1, 1]);
    for (final provider in [...providers, ...backdrops]) {
      provider.result.completeError(StateError('Logo unavailable'));
    }
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'loading logo reserves space without flashing text; errors retain fallback',
      (tester) async {
    final provider = _PendingImage();
    await tester.pumpWidget(MaterialApp(
        home: Center(
            child: SizedBox(
                width: 480,
                child: MediaHeroTitle(
                    title: 'Le film',
                    logo: _TestImage(provider),
                    availableWidth: 1200)))));
    await tester.pump();
    expect(find.text('LE FILM'), findsNothing);
    expect(find.bySemanticsLabel('Le film'), findsOneWidget);
    final pendingBounds = tester.getSize(find.byType(MediaHeroTitle));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.getSize(find.byType(MediaHeroTitle)), pendingBounds);
    provider.result.completeError(StateError('Logo unavailable'));
    await tester.pump();
    await tester.pump();
    expect(find.text('LE FILM'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
