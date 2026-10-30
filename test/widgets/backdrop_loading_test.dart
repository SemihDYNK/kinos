import 'dart:ui' as ui;
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/models/items/images_models.dart';
import 'package:kinos/screens/dashboard/home_hero_backdrop.dart';
import 'seerr_discovery_section_test.dart' show shell;
import 'support/home_visual_fixture.dart' show homeArtwork;

class PendingImage extends ImageProvider<PendingImage> {
  final result = Completer<ImageInfo>();
  @override
  Future<PendingImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);
  @override
  ImageStreamCompleter loadImage(
          PendingImage key, ImageDecoderCallback decode) =>
      OneFrameImageStreamCompleter(result.future);
}

class PendingArtwork extends ImageData {
  PendingArtwork(this.provider) : super(path: 'pending', key: 'pending');
  final ImageProvider provider;
  @override
  ImageProvider get imageProvider => provider;
}

void main() {
  testWidgets(
      'replaces the source only after decode, then retains the ready banner',
      (tester) async {
    final pending = PendingImage();
    final next = PendingImage();
    var image = PendingArtwork(pending);
    late StateSetter update;
    await tester.pumpWidget(ProviderScope(child: shell(
        SliverToBoxAdapter(child: StatefulBuilder(builder: (context, setState) {
      update = setState;
      return SizedBox(
          height: 600,
          child: HomeHeroBackdrop(
              image: image, cinematic: true, fallback: homeArtwork));
    })))));
    await tester.pump();
    expect(find.byKey(const ValueKey('coast')), findsWidgets);
    final decoded = await tester.runAsync(() async {
      final codec = await ui
          .instantiateImageCodec(await File(homeArtwork.path).readAsBytes());
      final frame = await codec.getNextFrame();
      codec.dispose();
      return frame.image;
    });
    pending.result.complete(ImageInfo(image: decoded!));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('coast')), findsNothing);
    expect(find.byKey(const ValueKey('pending')), findsWidgets);
    update(() => image = PendingArtwork(next));
    await tester.pump();
    expect(find.byKey(const ValueKey('pending')), findsWidgets);
    next.result.completeError(StateError('Unavailable replacement'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pending')), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('keeps visible source artwork while the banner loads or fails',
      (tester) async {
    final pending = PendingImage();
    await tester.pumpWidget(ProviderScope(
        child: shell(SliverToBoxAdapter(
            child: SizedBox(
                height: 600,
                child: HomeHeroBackdrop(
                    image: PendingArtwork(pending), fallback: homeArtwork))))));
    await tester.pump();
    expect(find.byKey(const ValueKey('coast')), findsWidgets);
    pending.result.completeError(StateError('Image unavailable'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('coast')), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
