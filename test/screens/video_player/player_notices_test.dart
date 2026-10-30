import 'package:kinos/screens/video_player/components/player_motion.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/l10n/generated/app_localizations.dart';
import 'package:kinos/models/items/media_segments_model.dart';
import 'package:kinos/screens/video_player/components/video_player_controls_extras.dart';

void main() {
  testWidgets(
      'buffering remains legible without continuous motion when animations are disabled',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: PlayerBufferingIndicator(buffering: true)),
    ));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    expect(
        tester
            .widget<CircularProgressIndicator>(
                find.byType(CircularProgressIndicator))
            .value,
        isNotNull);
    expect(tester.binding.hasScheduledFrame, false);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'short buffering is invisible and sustained buffering appears then cancels safely',
      (tester) async {
    final buffering = ValueNotifier(false);
    addTearDown(buffering.dispose);
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ValueListenableBuilder(
          valueListenable: buffering,
          builder: (_, value, __) =>
              PlayerBufferingIndicator(buffering: value)),
    ));
    bool visible() => tester
        .widget<PlayerControlsMotion>(find.byType(PlayerControlsMotion))
        .visible;
    buffering.value = true;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(visible(), false);
    buffering.value = false;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(visible(), false);
    buffering.value = true;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(visible(), true);
    buffering.value = false;
    await tester.pumpAndSettle();
    expect(visible(), false);
    buffering.value = true;
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  for (final type in [MediaSegmentType.intro, MediaSegmentType.outro]) {
    testWidgets('server $type marker exposes a keyboard reachable skip action',
        (tester) async {
      var skipped = 0;
      await tester.pumpWidget(ProviderScope(
          child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
            body: SkipSegmentButton(
          segment: MediaSegment(
              type: type,
              start: Duration.zero,
              end: const Duration(seconds: 60)),
          skipType: SegmentSkip.askToSkip,
          visibility: SegmentVisibility.visible,
          pressedSkip: () => skipped++,
        )),
      )));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(skipped, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('missing server markers produce no skip button', (tester) async {
    await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
          body: SkipSegmentButton(
              segment: null,
              skipType: SegmentSkip.askToSkip,
              visibility: SegmentVisibility.visible,
              pressedSkip: () {})),
    )));
    expect(find.byType(TextButton), findsNothing);
  });

  testWidgets('hidden segment button cannot seek', (tester) async {
    var skipped = 0;
    await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
          body: SkipSegmentButton(
        segment: MediaSegment(
            type: MediaSegmentType.intro,
            start: Duration.zero,
            end: const Duration(seconds: 60)),
        skipType: SegmentSkip.askToSkip,
        visibility: SegmentVisibility.hidden,
        pressedSkip: () => skipped++,
      )),
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextButton), warnIfMissed: false);
    expect(skipped, 0);
  });
}
