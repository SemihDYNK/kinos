import 'package:kinos/widgets/shared/animated_media_icon.dart';
import 'package:flutter/services.dart';
import 'package:kinos/util/motion_input.dart';
import 'package:flutter/material.dart';
import 'package:kinos/widgets/shared/frosted_surface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/widgets/shared/anchored_popover.dart';

void main() {
  testWidgets(
      'option check animates without moving the label or delaying selection',
      (tester) async {
    final selected = ValueNotifier(false);
    addTearDown(selected.dispose);
    var activations = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SizedBox(
      width: 300,
      child: ValueListenableBuilder(
        valueListenable: selected,
        builder: (_, value, __) => PopoverOptionList(options: [
          PopoverOption(
            content: const Text('Piste audio'),
            selected: value,
            onSelect: () {
              activations++;
              selected.value = true;
            },
          )
        ]),
      ),
    ))));
    final width = tester.getSize(find.text('Piste audio')).width;
    await tester.tap(find.text('Piste audio'));
    expect(activations, 1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(find.byType(AnimatedWatchedIcon), findsOneWidget);
    expect(tester.getSize(find.text('Piste audio')).width, width);
    expect(tester.binding.hasScheduledFrame, true);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('popover closes faster than it opens', (tester) async {
    final controller = AnchoredPopoverController();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Center(
                child: AnchoredPopover(
      controller: controller,
      child: const Text('Menu'),
      popoverBuilder: (_, close) => const Text('Contenu rapide'),
    )))));
    controller.show();
    await tester.pumpAndSettle();
    controller.hide();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 130));
    await tester.pump();
    expect(find.text('Contenu rapide'), findsNothing);
  });

  for (final immediate in [false, true]) {
    testWidgets('popover reverses in place, keyboard immediate: $immediate',
        (tester) async {
      final strategy = FocusManager.instance.highlightStrategy;
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.automatic;
      addTearDown(() => FocusManager.instance.highlightStrategy = strategy);
      final controller = AnchoredPopoverController();
      await tester.pumpWidget(MotionInputBoundary(
          child: MaterialApp(
              home: Scaffold(
                  body: Center(
        child: AnchoredPopover(
            controller: controller,
            popoverBuilder: (_, close) =>
                TextButton(onPressed: close, child: const Text('Choix')),
            child: TextButton(
                onPressed: controller.toggle, child: const Text('Menu'))),
      )))));
      if (immediate) await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      controller.show();
      await tester.pump();
      // Le fondu du déroulé finit dans le premier tiers de l'animation.
      await tester.pump(const Duration(milliseconds: 10));
      final reveal = find
          .ancestor(
              of: find.text('Choix'), matching: find.byType(FadeTransition))
          .first;
      expect(tester.widget<FadeTransition>(reveal).opacity.value,
          immediate ? equals(1) : inExclusiveRange(0, 1));
      controller.hide();
      expect(controller.isOpen, isFalse);
      await tester.pump();
      if (!immediate) {
        await tester.pump(const Duration(milliseconds: 30));
        expect(find.text('Choix'), findsOneWidget);
      }
      controller.show();
      expect(controller.isOpen, isTrue);
      await tester.pumpAndSettle();
      expect(find.text('Choix'), findsOneWidget);
      controller.hide();
      await tester.pumpAndSettle();
      expect(find.text('Choix'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('reduced motion settles a menu already opening or closing',
      (tester) async {
    final reduced = ValueNotifier(false);
    addTearDown(reduced.dispose);
    final controller = AnchoredPopoverController();
    await tester.pumpWidget(MaterialApp(
        home: ValueListenableBuilder(
      valueListenable: reduced,
      builder: (_, reduce, __) => MediaQuery(
          data: MediaQueryData(disableAnimations: reduce),
          child: Scaffold(
              body: Center(
                  child: AnchoredPopover(
                      controller: controller,
                      popoverBuilder: (_, close) => const Text('Contenu'),
                      child: const Text('Déclencheur'))))),
    )));
    controller.show();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    reduced.value = true;
    await tester.pump();
    await tester.pump();
    final reveal = find
        .ancestor(
            of: find.text('Contenu'), matching: find.byType(FadeTransition))
        .first;
    expect(tester.widget<FadeTransition>(reveal).opacity.value, 1);
    reduced.value = false;
    await tester.pump();
    controller.hide();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    reduced.value = true;
    await tester.pumpAndSettle();
    expect(find.text('Contenu'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a tall menu keeps one side and one direction while unrolling',
      (tester) async {
    // 900 px de haut : un menu de 400 px ne tient pas au-dessus du
    // déclencheur (à 300 px du haut) mais tient en dessous. Quand il se
    // déroulait avec une hauteur qui grandit, il tenait d'abord au-dessus,
    // puis basculait en dessous.
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = AnchoredPopoverController();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Padding(
      padding: const EdgeInsets.only(top: 300),
      child: Align(
        alignment: Alignment.topCenter,
        child: AnchoredPopover(
            controller: controller,
            popoverBuilder: (_, close) => const SizedBox(
                height: 400, width: 240, child: Center(child: Text('Long'))),
            child: const SizedBox(width: 120, height: 40, child: Text('Menu'))),
      ),
    ))));
    controller.show();
    await tester.pump();
    final tops = <double>[];
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 40));
      tops.add(tester.getTopLeft(find.byType(FrostedSurface)).dy);
    }
    // Trop haut pour tenir au-dessus : en dessous dès la première image,
    // jamais de saut d'un côté à l'autre pendant le déroulé.
    expect(tops.toSet(), hasLength(1), reason: 'placement is stable: $tops');
    expect(tops.first, greaterThan(300 + 40));
    await tester.pumpAndSettle();
    controller.hide();
    final closing = <double>[];
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 30));
      if (find.byType(FrostedSurface).evaluate().isNotEmpty) {
        closing.add(tester.getTopLeft(find.byType(FrostedSurface)).dy);
      }
    }
    expect(closing.toSet().length, lessThanOrEqualTo(1),
        reason: 'closing does not jump either: $closing');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
