import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/l10n/generated/app_localizations.dart';
import 'package:kinos/models/item_base_model.dart';
import 'package:kinos/models/items/overview_model.dart';
import 'package:kinos/models/items/item_shared_models.dart';
import 'package:kinos/models/media_playback_model.dart';
import 'package:kinos/models/playback/playback_model.dart';
import 'package:kinos/providers/video_player_provider.dart';
import 'package:kinos/screens/video_player/components/video_player_next_wrapper.dart';
import 'package:kinos/screens/video_player/components/player_motion.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/adaptive_layout/adaptive_layout.dart';
import 'package:kinos/util/adaptive_layout/adaptive_layout_model.dart';
import 'package:kinos/util/poster_defaults.dart';
import 'package:wakelock_plus_platform_interface/wakelock_plus_platform_interface.dart';

class _Wakelock extends WakelockPlusPlatformInterface {
  @override
  Future<void> toggle({required bool enable}) async {}
  @override
  Future<bool> get enabled async => false;
}

ItemBaseModel item(String id) => ItemBaseModel(
    name: id,
    id: id,
    overview: const OverviewModel(genres: [], summary: ''),
    parentId: null,
    playlistId: null,
    images: null,
    childCount: null,
    primaryRatio: null,
    userData: const UserData(),
    canDownload: null,
    canDelete: null,
    jellyType: null);

void main() {
  testWidgets(
      'next episode card enters from the side and hidden actions lose focus',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    WakelockPlusPlatformInterface.instance = _Wakelock();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('window_manager'), (_) async => false);
    final current = item('Actuel');
    final next = item('Épisode suivant test');
    final container = ProviderContainer(overrides: [
      videoPlayerProvider.overrideWith((ref) => VideoPlayerNotifier(ref)),
    ]);
    addTearDown(container.dispose);
    container.read(playBackModel.notifier).state = PlaybackModel(
        item: current, media: null, playbackInfo: null, queue: [current, next]);
    container.read(mediaPlaybackProvider.notifier).state = MediaPlaybackModel(
        state: VideoPlayerState.fullScreen,
        duration: const Duration(minutes: 10),
        playing: true);
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
              child: Scaffold(
                  body: VideoPlayerNextWrapper(
                video: SizedBox.expand(),
                controls: Text('Commandes'),
              ))),
        )));
    final notice = find
        .ancestor(
            of: find.text('Épisode suivant test'),
            matching: find.byType(PlayerControlsMotion))
        .first;
    expect(tester.widget<PlayerControlsMotion>(notice).visible, false);
    container.read(mediaPlaybackProvider.notifier).update(
        (s) => s.copyWith(position: const Duration(minutes: 9, seconds: 40)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(tester.widget<PlayerControlsMotion>(notice).visible, true);
    final opacity =
        find.descendant(of: notice, matching: find.byType(Opacity)).first;
    expect(tester.widget<Opacity>(opacity).opacity, inExclusiveRange(0, 1));
    await tester.pump(const Duration(milliseconds: 300));
    container
        .read(mediaPlaybackProvider.notifier)
        .update((s) => s.copyWith(position: const Duration(minutes: 2)));
    await tester.pump();
    expect(tester.widget<PlayerControlsMotion>(notice).visible, false);
    await tester.pumpAndSettle();
    final focus =
        find.descendant(of: notice, matching: find.byType(ExcludeFocus)).first;
    expect(tester.widget<ExcludeFocus>(focus).excluding, true);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
}
