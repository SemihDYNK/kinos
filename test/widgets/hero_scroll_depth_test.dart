import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kinos/screens/dashboard/hero_scroll_depth.dart';
import 'package:kinos/theme/app_theme.dart';

void main() {
  const bannerHeight = 400.0;
  const textHeight = 100.0;

  Future<ScrollController> pump(WidgetTester tester,
      {bool reduced = false, bool textAtTop = false}) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(MediaQuery(
      data: MediaQueryData(
          size: const Size(800, 600), disableAnimations: reduced),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: CustomScrollView(controller: controller, slivers: [
          SliverToBoxAdapter(
            child: SizedBox(
              height: bannerHeight,
              child: Stack(children: [
                const Positioned.fill(
                    child: HeroScrollDepth(
                        layer: HeroDepthLayer.image,
                        child: ColoredBox(
                            key: Key('image'), color: AppColors.surface))),
                Positioned(
                    left: 0,
                    right: 0,
                    top: textAtTop ? AppSpacing.md : null,
                    bottom: textAtTop ? null : 0,
                    child: HeroScrollDepth(
                        layer: HeroDepthLayer.text,
                        child: Focus(
                            autofocus: true,
                            child: const SizedBox(
                                key: Key('text'), height: textHeight)))),
              ]),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 2000)),
        ]),
      ),
    ));
    await tester.pump();
    return controller;
  }

  Opacity opacityAbove(WidgetTester tester, String key) => tester.widget(
      find.ancestor(of: find.byKey(Key(key)), matching: find.byType(Opacity)));

  double imageTop(WidgetTester tester) =>
      tester.getTopLeft(find.byKey(const Key('image'))).dy;

  testWidgets(
      'l\'image défile à moitié vitesse et s\'éteint, le texte '
      's\'efface en approchant du haut', (tester) async {
    final controller = await pump(tester);
    expect(opacityAbove(tester, 'image').opacity, 1);
    expect(opacityAbove(tester, 'text').opacity, 1);
    final focused = FocusManager.instance.primaryFocus;

    controller.jumpTo(100);
    await tester.pump();
    expect(imageTop(tester), -100 + 100 * AppMotion.heroParallax);
    final dimmed = opacityAbove(tester, 'image').opacity;
    expect(dimmed, allOf(greaterThan(0), lessThan(1)));
    expect(opacityAbove(tester, 'text').opacity, 1,
        reason: 'le texte est encore bas dans l\'écran');

    // Haut du texte à 300 px du début : à 300, il touche le haut.
    controller.jumpTo(300);
    await tester.pump();
    expect(opacityAbove(tester, 'image').opacity, lessThan(dimmed));
    expect(opacityAbove(tester, 'text').opacity,
        allOf(greaterThan(0), lessThan(1)));

    controller.jumpTo(350);
    await tester.pump();
    expect(opacityAbove(tester, 'image').opacity, 0);
    expect(opacityAbove(tester, 'text').opacity, 0);
    expect(FocusManager.instance.primaryFocus, same(focused),
        reason: 'franchir les seuils ne reconstruit pas le contenu');

    controller.jumpTo(0);
    await tester.pump();
    expect(imageTop(tester), 0);
    expect(opacityAbove(tester, 'image').opacity, 1);
    expect(opacityAbove(tester, 'text').opacity, 1);
  });

  testWidgets('animations réduites : le bandeau défile d\'un bloc',
      (tester) async {
    final controller = await pump(tester, reduced: true);
    controller.jumpTo(200);
    await tester.pump();
    expect(imageTop(tester), -200);
    expect(opacityAbove(tester, 'image').opacity, 1);
    expect(opacityAbove(tester, 'text').opacity, 1);
  });

  testWidgets('un texte qui commence près du haut reste net au repos',
      (tester) async {
    final controller = await pump(tester, textAtTop: true);
    expect(opacityAbove(tester, 'text').opacity, 1);
    controller.jumpTo(AppSpacing.md + textHeight / 4);
    await tester.pump();
    expect(opacityAbove(tester, 'text').opacity,
        allOf(greaterThan(0), lessThan(1)));
  });
}
