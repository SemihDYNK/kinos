import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/focus_provider.dart';
import 'package:kinos/util/motion_input.dart';

void main() {
  testWidgets('home cards share poster hover motion and keep their bounds',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: Center(
              child: SizedBox(
                  width: 180,
                  height: 270,
                  child: FocusRing(
                    posterMotion: true,
                    onActivate: () {},
                    child: const ColoredBox(color: Colors.black),
                  ))),
        )));
    await tester.pumpAndSettle();
    final ring = find.byType(FocusRing);
    final bounds = tester.getRect(ring);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(bounds.center);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    final transforms = tester.widgetList<Transform>(
        find.descendant(of: ring, matching: find.byType(Transform)));
    expect(transforms.any((t) => t.transform.storage[0] > 1), isTrue);
    expect(tester.getRect(ring), bounds);
    await tester.pumpAndSettle();
    final decoration = tester
        .widget<AnimatedContainer>(find
            .descendant(of: ring, matching: find.byType(AnimatedContainer))
            .first)
        .decoration as BoxDecoration;
    expect(decoration.border!.top.color, AppColors.posterHoverBorder);
    await mouse.removePointer();
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  for (final reduced in [false, true]) {
    testWidgets(
        'poster hover reverses without moving layout, reduced: $reduced',
        (tester) async {
      await tester.pumpWidget(ProviderScope(
          child: MotionInputBoundary(
              child: MaterialApp(
        theme: buildAppTheme(),
        home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduced),
            child: Scaffold(
              body: Center(
                  child: SizedBox(
                      width: 180,
                      height: 270,
                      child: FocusButton(
                        posterMotion: true,
                        onTap: () {},
                        child: const ColoredBox(color: Colors.black),
                        focusedOverlays: const [
                          Center(child: Icon(Icons.play_arrow))
                        ],
                      ))),
            )),
      ))));
      await tester.pumpAndSettle();
      final bounds = tester.getRect(find.byType(FocusButton));
      double scale() => tester
          .widgetList<Transform>(find.descendant(
            of: find.byType(FocusButton),
            matching: find.byType(Transform),
          ))
          .firstWhere((t) =>
              t.transform.storage[0] != 1 || t.transform.storage[13] == 0)
          .transform
          .storage[0];
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(bounds.center);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(tester.getRect(find.byType(FocusButton)), bounds);
      expect(scale(), reduced ? 1 : greaterThan(1));
      expect(tester.binding.hasScheduledFrame, !reduced);
      final surface = tester.widget<AnimatedContainer>(find
          .descendant(
              of: find.byType(FocusButton),
              matching: find.byType(AnimatedContainer))
          .first);
      expect((surface.foregroundDecoration as BoxDecoration).border!.top.color,
          AppColors.posterHoverBorder);
      final beforeExit = scale();
      await mouse.moveTo(Offset.zero);
      await tester.pump();
      expect(scale(), closeTo(beforeExit, .0001));
      await tester.pumpAndSettle();
      expect(scale(), 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(scale(), 1);
      expect(
          tester
              .state<FocusButtonState>(find.byType(FocusButton))
              .focusNode
              .hasFocus,
          isTrue);
      final focusedSurface = tester.widget<AnimatedContainer>(find
          .descendant(
              of: find.byType(FocusButton),
              matching: find.byType(AnimatedContainer))
          .first);
      expect(
          (focusedSurface.foregroundDecoration as BoxDecoration)
              .border!
              .top
              .color,
          AppColors.focus);
      await mouse.moveTo(bounds.center);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(scale(), reduced ? 1 : greaterThan(1));
      expect(tester.takeException(), isNull);
      await mouse.removePointer();
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
