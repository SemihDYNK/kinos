import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/l10n/generated/app_localizations.dart';
import 'package:kinos/models/media_playback_model.dart';
import 'package:kinos/providers/pip_provider.dart';
import 'package:kinos/providers/video_player_provider.dart';
import 'package:kinos/screens/video_player/video_player.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/adaptive_layout/adaptive_layout.dart';
import 'package:kinos/util/adaptive_layout/adaptive_layout_model.dart';
import 'package:kinos/util/poster_defaults.dart';
import 'package:kinos/util/themes_data.dart';
import 'package:kinos/widgets/navigation_scaffold/components/floating_player_bar.dart';
import 'package:kinos/widgets/navigation_scaffold/components/shared/player_bar_shared.dart';
import 'package:wakelock_plus_platform_interface/wakelock_plus_platform_interface.dart';
import '../../support/fake_base_player.dart';

class _Wakelock extends WakelockPlusPlatformInterface {
  @override
  Future<void> toggle({required bool enable}) async {}
  @override
  Future<bool> get enabled async => false;
}

class _Video extends FakeBasePlayer {
  @override
  Widget? videoWidget(Key key, BoxFit fit) =>
      SizedBox.expand(key: key, child: const ColoredBox(color: Colors.blue));
}

void main() {
  testWidgets('mini player survives until its hero finishes expanding',
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
    final player = _Video();
    await container.read(videoPlayerProvider).setup(player);
    container.read(mediaPlaybackProvider.notifier).state = MediaPlaybackModel(
        state: VideoPlayerState.minimized,
        duration: const Duration(minutes: 30));
    final theme = buildAppTheme();
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: ThemesData(
            light: theme,
            dark: theme,
            child: MaterialApp(
              theme: theme,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (_, child) => AdaptiveLayout(
                  data: const AdaptiveLayoutModel(
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
                  child: child!),
              home: Scaffold(
                  body: Consumer(
                      builder: (_, ref, __) => Align(
                            alignment: Alignment.bottomCenter,
                            child: ref.watch(mediaPlaybackProvider
                                        .select((s) => s.state)) ==
                                    VideoPlayerState.minimized
                                ? const FloatingPlayerBar()
                                : const SizedBox.shrink(),
                          ))),
            ))));
    await tester.pumpAndSettle();
    final miniWidth =
        tester.getSize(find.byKey(const ValueKey('mini_player_video'))).width;
    await tester.tap(find.byTooltip('Expand player'));
    await tester.pump();
    expect(container.read(mediaPlaybackProvider).state,
        VideoPlayerState.minimized);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(VideoPlayer), findsOneWidget);
    final expandingWidth =
        tester.getSize(find.byKey(const Key('VideoPlayer'))).width;
    expect(expandingWidth, greaterThan(miniWidth));
    expect(expandingWidth, lessThan(1400));
    expect(
        find.byWidgetPredicate((w) => w is Hero && w.tag == videoPlayerHeroTag,
            skipOffstage: false),
        findsWidgets);
    await tester.pumpAndSettle();
    expect(container.read(mediaPlaybackProvider).state,
        VideoPlayerState.fullScreen);
    await tester.tap(find.byTooltip('Réduire'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final shrinkingWidth =
        tester.getSize(find.byKey(const ValueKey('mini_player_video'))).width;
    expect(shrinkingWidth, greaterThan(miniWidth));
    expect(shrinkingWidth, lessThan(1400));
    await tester.pumpAndSettle();
    expect(find.byType(VideoPlayer), findsNothing);
    expect(container.read(mediaPlaybackProvider).state,
        VideoPlayerState.minimized);
    expect(
        tester.getSize(find.byKey(const ValueKey('mini_player_video'))).width,
        miniWidth);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
