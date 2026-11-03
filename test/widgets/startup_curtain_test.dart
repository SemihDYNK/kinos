import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/screens/shared/startup_curtain.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/motion_input.dart';
import 'package:kinos/screens/shared/kinos_icon.dart';
import 'package:kinos/screens/shared/startup_mark.dart';

void main() {
  testWidgets('signature assembly finishes once before handing off',
      (tester) async {
    var assembled = 0;
    await tester.pumpWidget(
        MaterialApp(home: StartupCurtain(onLogoReady: () => assembled++)));
    await tester.pump();
    await tester.pump(AppDurations.startupLogo ~/ 2);
    expect(assembled, 0);
    await tester.pumpAndSettle();
    expect(assembled, 1);
    await tester.pump(const Duration(seconds: 3));
    expect(assembled, 1);
  });

  testWidgets('disposing during assembly cancels its handoff', (tester) async {
    var assembled = false;
    await tester.pumpWidget(
        MaterialApp(home: StartupCurtain(onLogoReady: () => assembled = true)));
    await tester.pump(AppDurations.startupLogo ~/ 2);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(assembled, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion presents the assembled K immediately',
      (tester) async {
    var assembled = false;
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: StartupCurtain(onLogoReady: () => assembled = true),
    )));
    await tester.pumpAndSettle();
    expect(assembled, isTrue);
    expect(tester.widget<StartupMark>(find.byType(StartupMark)).progress, 1);
  });

  testWidgets('assembled K retains the original SVG signature geometry',
      (tester) async {
    final referenceKey = GlobalKey(), animatedKey = GlobalKey();
    await tester.pumpWidget(MaterialApp(
        home: Row(children: [
      RepaintBoundary(
          key: referenceKey,
          child: const KinosIcon(size: AppBrand.startupMarkSize)),
      RepaintBoundary(key: animatedKey, child: const StartupMark(progress: 1)),
    ])));
    await tester.pumpAndSettle();
    Future<ui.Image> capture(GlobalKey key) async => (await tester.runAsync(
        () => (key.currentContext!.findRenderObject()! as RenderRepaintBoundary)
            .toImage()))!;
    final original = await capture(referenceKey);
    final animated = await capture(animatedKey);
    expect(animated.width, original.width);
    expect(animated.height, original.height);
    final a = (await tester.runAsync(
        () => original.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
    final b = (await tester.runAsync(
        () => animated.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
    var differing = 0;
    for (var i = 0; i < a.lengthInBytes; i += 4) {
      if ((a.getUint8(i + 3) - b.getUint8(i + 3)).abs() > 6) differing++;
    }
    expect(differing, lessThan(original.width * original.height * .015));
    original.dispose();
    animated.dispose();
  });

  testWidgets('opening has a diffuse edge and leaves no veil when complete',
      (tester) async {
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: boundaryKey,
      child: MaterialApp(
          home: Stack(fit: StackFit.expand, children: [
        const ColoredBox(color: Colors.white),
        StartupCurtain(onRevealed: () {}),
      ])),
    ));
    await tester.pump();
    await tester.pump(AppDurations.startupReveal ~/ 2);
    final clipper = tester.widget<ClipPath>(find.byType(ClipPath)).clipper!
        as StartupApertureClipper;
    final boundary = boundaryKey.currentContext!.findRenderObject()!
        as RenderRepaintBoundary;
    final image = (await tester.runAsync(() => boundary.toImage()))!;
    final bytes = (await tester
        .runAsync(() => image.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
    final centre = Offset(image.width / 2, image.height / 2);
    final radius = centre.distance * clipper.progress;
    final edge = <int>{};
    for (var x = (centre.dx + radius - 35).round();
        x < centre.dx + radius + 35;
        x++) {
      final red = bytes.getUint8((centre.dy.floor() * image.width + x) * 4);
      if (red > AppColors.background.r * 255 + 1 && red < 254) edge.add(red);
    }
    image.dispose();
    expect(edge.length, greaterThan(8));
    await tester.pumpAndSettle();
    final finalImage = (await tester.runAsync(() => boundary.toImage()))!;
    final finalBytes = (await tester.runAsync(
        () => finalImage.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
    expect(finalBytes.getUint8(0), 255);
    finalImage.dispose();
  });

  testWidgets('startup shows the K alone and holds its final centred shape',
      (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(const MaterialApp(home: StartupCurtain()));
      expect(find.byType(KinosWordmark), findsNothing);
      await tester.pumpAndSettle();
      final mark = tester.getRect(find.bySemanticsLabel('Kinos'));
      expect(mark.width, closeTo(mark.height, .1));
      expect(mark.center, const Offset(400, 300));
      await tester.pump(const Duration(seconds: 3));
      expect(tester.getRect(find.bySemanticsLabel('Kinos')), mark);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
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
