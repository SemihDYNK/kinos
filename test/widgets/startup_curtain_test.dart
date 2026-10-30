import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/screens/shared/startup_curtain.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/motion_input.dart';
import 'package:kinos/screens/shared/kinos_icon.dart';

void main() {
  testWidgets('wordmark places its O at screen centre before opening',
      (tester) async {
    await tester
        .pumpWidget(MaterialApp(home: StartupCurtain(onRevealed: () {})));
    await tester.pump();
    await tester.pump(AppDurations.startupReveal ~/ 3);
    final wordmark = tester.getRect(find.byType(KinosWordmark));
    final centreOfO = wordmark.topLeft +
        Offset(
          wordmark.width * AppBrand.wordmarkOAnchor.dx,
          wordmark.height * AppBrand.wordmarkOAnchor.dy,
        );
    expect(centreOfO.dx, closeTo(400, .1));
    expect(centreOfO.dy, closeTo(300, .1));
    await tester.pumpAndSettle();
  });

  testWidgets('destination failure cannot trap navigation behind the logo',
      (tester) async {
    var completed = false;
    await tester.pumpWidget(MaterialApp(
        home:
            StartupCurtain(ready: false, onRevealed: () => completed = true)));
    await tester.pump(AppDurations.startupLoadTimeout);
    await tester.pumpAndSettle();
    expect(completed, isTrue);
  });

  testWidgets('slow destination keeps the logo until its first frame is ready',
      (tester) async {
    final ready = ValueNotifier(false);
    addTearDown(ready.dispose);
    var completed = false;
    await tester.pumpWidget(MaterialApp(
        home: ValueListenableBuilder<bool>(
      valueListenable: ready,
      builder: (_, value, __) =>
          StartupCurtain(ready: value, onRevealed: () => completed = true),
    )));
    await tester.pump(const Duration(seconds: 3));
    expect(completed, isFalse);
    expect(
        tester.widget<ClipPath>(find.byType(ClipPath)).clipper,
        isA<StartupApertureClipper>()
            .having((clipper) => clipper.progress, 'opening', 0));
    ready.value = true;
    await tester.pump();
    await tester.pump();
    await tester.pump(AppDurations.startupReveal ~/ 2);
    expect(completed, isFalse);
    expect(
        (tester.widget<ClipPath>(find.byType(ClipPath)).clipper!
                as StartupApertureClipper)
            .progress,
        allOf(greaterThan(0), lessThan(1)));
    await tester.pumpAndSettle();
    expect(completed, isTrue);
  });

  testWidgets('launching with the keyboard keeps the circular opening',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: MotionInputBoundary(child: StartupCurtain(onRevealed: () {})),
    ));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(find.byType(ClipPath), findsOneWidget);
    await tester.pumpAndSettle();
  });

  test('circular opening keeps the outside covered and uncovers the centre',
      () {
    const size = Size(800, 600);
    expect(
        const StartupApertureClipper(0)
            .getClip(size)
            .contains(const Offset(400, 300)),
        isTrue);
    final halfway = const StartupApertureClipper(.5).getClip(size);
    expect(halfway.contains(const Offset(400, 300)), isFalse);
    expect(halfway.contains(const Offset(1, 1)), isTrue);
    expect(
        const StartupApertureClipper(1)
            .getClip(size)
            .contains(const Offset(1, 1)),
        isFalse);
  });

  testWidgets('disposing during reveal cancels its completion', (tester) async {
    var completed = false;
    await tester.pumpWidget(MaterialApp(
      home: StartupCurtain(onRevealed: () => completed = true),
    ));
    await tester.pump();
    await tester.pump(AppDurations.hover);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(completed, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('launch wordmark appears without blocking startup work',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: StartupCurtain()));
    final fade = find.byType(FadeTransition).last;
    expect(tester.widget<FadeTransition>(fade).opacity.value, 0);
    await tester.pump();
    await tester.pump(AppDurations.startupReveal);
    expect(tester.widget<FadeTransition>(fade).opacity.value, 1);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('exit reveals destination and completes once', (tester) async {
    var completed = 0;
    await tester.pumpWidget(MaterialApp(
      home: StartupCurtain(onRevealed: () => completed++),
    ));
    await tester.pump(AppDurations.startupReveal ~/ 2);
    expect(completed, 0);
    await tester.pumpAndSettle();
    expect(completed, 1);
  });

  testWidgets('reduced motion finishes without a scale transition',
      (tester) async {
    var completed = false;
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: StartupCurtain(onRevealed: () => completed = true),
      ),
    ));
    await tester.pumpAndSettle();
    expect(completed, isTrue);
    expect(find.byType(ScaleTransition), findsNothing);
  });
}
