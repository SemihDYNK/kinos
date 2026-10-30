import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/util/motion_input.dart';
import 'package:kinos/widgets/shared/animated_media_icon.dart';

void main() {
  testWidgets('heart has a pronounced beat and a gentle removal',
      (tester) async {
    final selected = ValueNotifier(false);
    addTearDown(selected.dispose);
    await tester.pumpWidget(MaterialApp(
        home: ValueListenableBuilder(
      valueListenable: selected,
      builder: (_, value, __) =>
          Center(child: AnimatedFavouriteIcon(selected: value)),
    )));
    double scale() => tester
        .widget<Transform>(find.byType(Transform).last)
        .transform
        .storage[0];
    selected.value = true;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(scale(), closeTo(1.30, .02));
    await tester.pump(const Duration(milliseconds: 120));
    expect(scale(), lessThan(1));
    await tester.pumpAndSettle();
    expect(scale(), 1);
    selected.value = false;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(scale(), inExclusiveRange(.85, 1));
    await tester.pumpAndSettle();
    expect(scale(), 1);
    expect(tester.takeException(), isNull);
  });

  for (final heldShortcutKey in [false, true]) {
    testWidgets(
        'desktop mouse animates and reverses, held shortcut key: $heldShortcutKey',
        (tester) async {
      final strategy = FocusManager.instance.highlightStrategy;
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.automatic;
      addTearDown(() => FocusManager.instance.highlightStrategy = strategy);
      final selected = ValueNotifier(false);
      addTearDown(selected.dispose);
      await tester.pumpWidget(MotionInputBoundary(
          child: MaterialApp(
              home: ValueListenableBuilder(
        valueListenable: selected,
        builder: (_, value, __) => Center(
            child: GestureDetector(
                onTap: () => selected.value = !selected.value,
                child: AnimatedFavouriteIcon(selected: value))),
      ))));
      await tester.pumpAndSettle();
      if (heldShortcutKey) {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
        addTearDown(() => tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft));
      }
      await tester.tap(
          find
              .ancestor(
                  of: find.byType(AnimatedFavouriteIcon),
                  matching: find.byType(GestureDetector))
              .first,
          kind: PointerDeviceKind.mouse);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(tester.binding.hasScheduledFrame, isTrue);
      final before = tester
          .widget<Transform>(find.byType(Transform).last)
          .transform
          .storage[0];
      expect(before, greaterThan(1));
      selected.value = false;
      await tester.pump();
      expect(
          tester
              .widget<Transform>(find.byType(Transform).last)
              .transform
              .storage[0],
          closeTo(before, .0001));
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(tester.takeException(), isNull);
    });
  }

  for (final keyboard in [false, true]) {
    testWidgets(
        'selection is immediate for ${keyboard ? 'keyboard, including delayed state' : 'reduced motion'}',
        (tester) async {
      final selected = ValueNotifier(false);
      addTearDown(selected.dispose);
      await tester.pumpWidget(MotionInputBoundary(
          child: MaterialApp(
              home: MediaQuery(
        data: MediaQueryData(disableAnimations: !keyboard),
        child: ValueListenableBuilder(
            valueListenable: selected,
            builder: (_, value, __) =>
                Center(child: AnimatedWatchedIcon(selected: value))),
      ))));
      await tester.pumpAndSettle();
      if (keyboard) await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      selected.value = true;
      await tester.pump();
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('enabling reduced motion interrupts an active selection',
      (tester) async {
    final reduced = ValueNotifier(false);
    final selected = ValueNotifier(false);
    addTearDown(reduced.dispose);
    addTearDown(selected.dispose);
    await tester.pumpWidget(MaterialApp(
        home: ValueListenableBuilder(
            valueListenable: reduced,
            builder: (_, reduce, __) => MediaQuery(
                data: MediaQueryData(disableAnimations: reduce),
                child: ValueListenableBuilder(
                    valueListenable: selected,
                    builder: (_, value, __) => Center(
                        child: AnimatedFavouriteIcon(selected: value)))))));
    await tester.pumpAndSettle();
    selected.value = true;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    reduced.value = true;
    await tester.pump();
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });
}
