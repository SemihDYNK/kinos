import 'package:kinos/widgets/shared/frosted_surface.dart';
import 'package:kinos/screens/video_player/components/video_progress_bar.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/l10n/generated/app_localizations.dart';
import 'package:kinos/models/items/chapters_model.dart';
import 'package:kinos/models/items/media_segments_model.dart';
import 'package:kinos/models/media_playback_model.dart';
import 'package:kinos/models/playback/direct_playback_model.dart';
import 'package:kinos/providers/pip_provider.dart';
import 'package:kinos/providers/video_player_provider.dart';
import 'package:kinos/screens/video_player/video_player_controls.dart';
import 'package:kinos/screens/video_player/components/video_player_controls_extras.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/adaptive_layout/adaptive_layout.dart';
import 'package:kinos/util/adaptive_layout/adaptive_layout_model.dart';
import 'package:kinos/util/poster_defaults.dart';
import 'package:wakelock_plus_platform_interface/wakelock_plus_platform_interface.dart';
import '../../support/fake_base_player.dart';
import 'player_next_notice_test.dart' show item;

class _Wakelock extends WakelockPlusPlatformInterface {
  @override
  Future<void> toggle({required bool enable}) async {}
  @override
  Future<bool> get enabled async => false;
}

void main() {
  testWidgets('chapter Intro shows the real skip button and seeks to Episode',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    WakelockPlusPlatformInterface.instance = _Wakelock();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('window_manager'), (_) async => false);
    final container = ProviderContainer(overrides: [
      videoPlayerProvider.overrideWith((ref) => VideoPlayerNotifier(ref)),
      pipStateProvider.overrideWith((ref) => Stream.value(false)),
    ]);
    addTearDown(container.dispose);
    final player = FakeBasePlayer();
    await container.read(videoPlayerProvider).setup(player);
    final poster = File('test/widgets/fixtures/home/coast.png').absolute.path;
    container.read(playBackModel.notifier).state = DirectPlaybackModel(
      item: item('Épisode test'),
      media: null,
      mediaSegments: MediaSegmentsModel(),
      chapters: [
        Chapter(name: 'Intro', imageUrl: poster, startPosition: Duration.zero),
        Chapter(
            name: 'Episode',
            imageUrl: poster,
            startPosition: const Duration(seconds: 90)),
        Chapter(
            name: 'Credits',
            imageUrl: poster,
            startPosition: const Duration(minutes: 21)),
      ],
    );
    container.read(mediaPlaybackProvider.notifier).state = MediaPlaybackModel(
        state: VideoPlayerState.fullScreen,
        position: const Duration(seconds: 30),
        duration: const Duration(minutes: 22, seconds: 50));
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildAppTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AdaptiveLayout(
              data: AdaptiveLayoutModel(
                  viewSize: ViewSize.desktop,
                  layoutMode: LayoutMode.single,
                  inputDevice: InputDevice.pointer,
                  platform: TargetPlatform.linux,
                  isDesktop: true,
                  posterDefaults: PosterDefaults(size: 180, ratio: 2 / 3),
                  controller: {},
                  sideBarWidth: 0,
                  topBarHeight: 0,
                  statusBarHeight: 0),
              child: Scaffold(body: DesktopControls())),
        )));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<SkipSegmentButton>(find.byType(SkipSegmentButton))
            .segment
            ?.type,
        MediaSegmentType.intro);
    expect(
        find.descendant(
            of: find.byType(SkipSegmentButton),
            matching: find.byType(FrostedSurface)),
        findsOneWidget);
    final skipRect = tester.getRect(find.byType(SkipSegmentButton));
    final progressRect = tester.getRect(find.byType(VideoProgressBar));
    expect(skipRect.top, greaterThan(450));
    expect(skipRect.right, greaterThan(1200));
    expect(skipRect.bottom, lessThan(progressRect.top));
    await tester.tap(find.descendant(
        of: find.byType(SkipSegmentButton), matching: find.byType(TextButton)));
    expect(player.seekCalls, [const Duration(seconds: 90)]);
    container
        .read(mediaPlaybackProvider.notifier)
        .update((s) => s.copyWith(playing: true));
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(SkipSegmentButton)), skipRect);
    container
        .read(mediaPlaybackProvider.notifier)
        .update((s) => s.copyWith(position: const Duration(seconds: 90)));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<SkipSegmentButton>(find.byType(SkipSegmentButton))
            .segment,
        isNull);
    container.read(mediaPlaybackProvider.notifier).update(
        (s) => s.copyWith(position: const Duration(minutes: 21, seconds: 10)));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<SkipSegmentButton>(find.byType(SkipSegmentButton))
            .segment
            ?.type,
        MediaSegmentType.outro);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    expect(player.seekCalls.last, const Duration(minutes: 22, seconds: 50));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
