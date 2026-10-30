import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/screens/dashboard/home_hero_backdrop.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/theme/palette_service.dart';

void main() {
  testWidgets('fractional hero edge leaves no dark raster seam',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
            home: RepaintBoundary(
                key: key,
                child: const ColoredBox(
                    color: Color(0xFF465A50),
                    child: Column(children: [
                      SizedBox(
                          height: 600.75, child: HomeHeroBackdrop(image: null)),
                      Expanded(child: SizedBox()),
                    ]))))));
    await tester.pumpAndSettle();
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final bytes = await tester.runAsync(() async {
      final image = await boundary.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      return data!;
    });
    for (final y in [599, 600, 601]) {
      final offset = (y * 1000 + 200) * 4;
      for (var channel = 0; channel < 3; channel++) {
        expect(bytes!.getUint8(offset + channel),
            closeTo([70, 90, 80][channel], 2),
            reason: 'The image fade must not darken its final raster row ($y)');
      }
    }
  });

  for (final cinematic in [false, true]) {
    testWidgets(
        'hero scrim protects text on a white image, cinematic=$cinematic',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey();
      await tester.pumpWidget(ProviderScope(
          child: MaterialApp(
              theme: buildAppTheme(),
              home: RepaintBoundary(
                  key: key,
                  child: Stack(fit: StackFit.expand, children: [
                    const ColoredBox(color: Colors.white),
                    HomeHeroBackdrop(image: null, cinematic: cinematic)
                  ])))));
      await tester.pumpAndSettle();
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final data = await tester.runAsync(() async {
        final image = await boundary.toImage();
        final bytes =
            await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        image.dispose();
        return bytes!;
      });
      final upperPixel = (40 * 1000 + 950) * 4;
      expect(data!.getUint8(upperPixel), greaterThan(cinematic ? 200 : 150),
          reason:
              'The upper artwork must remain visible rather than covered by the former 75% scrim');
      final pixel = (360 * 1000 + 450) * 4;
      final bg = Color.fromARGB(255, data.getUint8(pixel),
          data.getUint8(pixel + 1), data.getUint8(pixel + 2));
      final rightPixel = (360 * 1000 + 950) * 4;
      final right = Color.fromARGB(255, data.getUint8(rightPixel),
          data.getUint8(rightPixel + 1), data.getUint8(rightPixel + 2));
      expect(right, bg,
          reason: 'The scrim must treat both sides of the same image equally');
      final secondary =
          Color.alphaBlend(AppColors.textPrimary.withValues(alpha: .75), bg);
      expect(
          contrastRatio(AppColors.textPrimary, bg), greaterThanOrEqualTo(4.5));
      expect(contrastRatio(secondary, bg), greaterThanOrEqualTo(4.5));
    });
  }
}
