import 'package:kinos/screens/video_player/components/player_motion.dart';
import 'package:kinos/theme/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/l10n/generated/app_localizations.dart';
import 'package:kinos/providers/video_player_provider.dart';
import 'package:kinos/screens/video_player/components/video_player_seek_indicator.dart';
import 'package:wakelock_plus_platform_interface/wakelock_plus_platform_interface.dart';

class _Wakelock extends WakelockPlusPlatformInterface {
  @override
  Future<void> toggle({required bool enable}) async {}
  @override
  Future<bool> get enabled async => false;
}

void main() {
  testWidgets(
      'controls reverse smoothly and hidden commands leave focus traversal',
      (tester) async {
    final visible = ValueNotifier(true);
    addTearDown(visible.dispose);
    await tester.pumpWidget(MaterialApp(
        home: ValueListenableBuilder(
      valueListenable: visible,
      builder: (_, value, __) => PlayerControlsMotion(
          visible: value,
          child: TextButton(onPressed: () {}, child: const Text('Commande'))),
    )));
    visible.value = false;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final halfway = tester.widget<Opacity>(find.byType(Opacity)).opacity;
    expect(halfway, inExclusiveRange(0, 1));
    visible.value = true;
    await tester.pump();
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity,
        closeTo(halfway, .001));
    await tester.pumpAndSettle();
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
    visible.value = false;
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<ExcludeFocus>(find
                .descendant(
                    of: find.byType(PlayerControlsMotion),
                    matching: find.byType(ExcludeFocus))
                .first)
            .excluding,
        true);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  for (final reduced in [false, true]) {
    testWidgets('play pause survives rapid reversal, reduced=$reduced',
        (tester) async {
      final playing = ValueNotifier(false);
      addTearDown(playing.dispose);
      await tester.pumpWidget(MaterialApp(
          home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: ValueListenableBuilder(
            valueListenable: playing,
            builder: (_, value, __) =>
                Center(child: PlayerPlaybackIcon(playing: value))),
      )));
      playing.value = true;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byIcon(AppIcons.pause), findsOneWidget);
      if (reduced) {
        expect(find.byIcon(AppIcons.play), findsNothing);
      } else {
        expect(find.byIcon(AppIcons.play), findsOneWidget);
      }
      playing.value = false;
      await tester.pumpAndSettle();
      expect(find.byIcon(AppIcons.play), findsOneWidget);
      expect(find.byIcon(AppIcons.pause), findsNothing);
      expect(tester.binding.hasScheduledFrame, false);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('desktop feedback accumulates without performing a second seek',
      (tester) async {
    final controller = SeekIndicatorController();
    final key = GlobalKey<VideoPlayerSeekIndicatorState>();
    await tester.pumpWidget(ProviderScope(
        overrides: [
          videoPlayerProvider.overrideWith(
              (ref) => throw StateError('Feedback must not seek')),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: VideoPlayerSeekIndicator(
              key: key, controller: controller, handleKeyboard: false),
        )));
    controller.show(10);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    controller.show(10);
    await tester.pumpAndSettle(const Duration(milliseconds: 20));
    expect(find.textContaining('20 '), findsOneWidget);
    expect(key.currentState!.visible, true);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(key.currentState!.visible, false);
    controller.show(-10);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    final slide =
        tester.widget<SlideTransition>(find.byType(SlideTransition).last);
    expect(slide.position.value.dx, greaterThan(0));
    await tester.pumpWidget(const SizedBox.shrink());
    controller.show(10);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('seek feedback obeys reduced motion and can unmount mid-burst',
      (tester) async {
    WakelockPlusPlatformInterface.instance = _Wakelock();
    final key = GlobalKey<VideoPlayerSeekIndicatorState>();
    await tester.pumpWidget(ProviderScope(
        overrides: [
          videoPlayerProvider.overrideWith((ref) => VideoPlayerNotifier(ref)),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: VideoPlayerSeekIndicator(key: key)),
        )));
    key.currentState!.onSeekStart(10);
    await tester.pump();
    expect(
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).duration,
        Duration.zero);
    key.currentState!.onSeekStart(10);
    await tester.pump();
    expect(find.textContaining('20 '), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });
}
