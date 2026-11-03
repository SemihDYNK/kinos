import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kinos/models/media_playback_model.dart';
import 'package:kinos/models/playback/playback_model.dart';
import 'package:kinos/models/playback/tv_playback_model.dart';
import 'package:kinos/providers/settings/video_player_settings_provider.dart';
import 'package:kinos/providers/video_player_provider.dart';
import 'package:kinos/screens/video_player/components/video_player_guide_wrapper.dart';
import 'package:kinos/screens/video_player/components/video_player_next_wrapper.dart';
import 'package:kinos/screens/video_player/video_player_controls.dart';
import 'package:kinos/util/adaptive_layout/adaptive_layout.dart';
import 'package:kinos/util/themes_data.dart';
import 'package:kinos/widgets/shared/ambient_blur.dart';
import 'package:kinos/widgets/shared/back_intent_dpad.dart';

class VideoPlayer extends ConsumerStatefulWidget {
  const VideoPlayer({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _VideoPlayerState();
}

class _VideoPlayerState extends ConsumerState<VideoPlayer>
    with WidgetsBindingObserver {
  double lastScale = 0.0;

  bool errorPlaying = false;
  Animation<double>? _expansionAnimation;

  late PlaybackModel? currentPlaybackModel = ref.read(playBackModel);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    //Don't manage the wakelock on desktop focus loss
    if (!(AdaptiveLayout.of(context).isDesktop || kIsWeb)) {
      if (state == AppLifecycleState.resumed) {
        // Android drops the keep-screen-on flag on resume; re-apply it.
        ref.read(videoPlayerProvider).reassertWakelock();
      }
    }
  }

  @override
  void dispose() {
    _expansionAnimation?.removeStatusListener(_onExpansionStatus);
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() {
      if (!mounted) return;
      final animation = ModalRoute.of(context)?.animation;
      if (ref.read(mediaPlaybackProvider).state == VideoPlayerState.minimized &&
          animation != null &&
          animation.status != AnimationStatus.completed) {
        // Keep the source Hero alive until the video has finished expanding.
        _expansionAnimation = animation;
        animation.addStatusListener(_onExpansionStatus);
      } else {
        _onExpansionStatus(AnimationStatus.completed);
      }
      final orientations = ref.read(videoPlayerSettingsProvider
          .select((value) => value.allowedOrientations));
      SystemChrome.setPreferredOrientations(orientations?.isNotEmpty == true
          ? orientations!.toList()
          : DeviceOrientation.values);
      return ref
          .read(videoPlayerSettingsProvider.notifier)
          .setSavedBrightness();
    });
  }

  void _onExpansionStatus(AnimationStatus status) {
    if (!mounted || status != AnimationStatus.completed) return;
    _expansionAnimation?.removeStatusListener(_onExpansionStatus);
    _expansionAnimation = null;
    ref
        .read(mediaPlaybackProvider.notifier)
        .update((state) => state.copyWith(state: VideoPlayerState.fullScreen));
  }

  @override
  Widget build(BuildContext context) {
    final fillScreen = ref
        .watch(videoPlayerSettingsProvider.select((value) => value.fillScreen));
    final videoFit = ref
        .watch(videoPlayerSettingsProvider.select((value) => value.videoFit));
    final padding = MediaQuery.of(context).padding;

    final playerController =
        ref.watch(videoPlayerProvider.select((value) => value));

    //Watch playbackModel type changes to switch between normal players
    ref.listen(
      playBackModel,
      (previous, next) {
        if (next == null) return;
        if (previous.runtimeType != next.runtimeType) {
          setState(() {
            currentPlaybackModel = next;
            errorPlaying = false;
          });
        }
      },
    );

    ref.listen(
      videoPlayerSettingsProvider.select((value) => value.allowedOrientations),
      (previous, next) {
        if (previous != next) {
          SystemChrome.setPreferredOrientations(next?.isNotEmpty == true
              ? next!.toList()
              : DeviceOrientation.values);
        }
      },
    );

    final player = Padding(
      padding: fillScreen
          ? EdgeInsets.zero
          : EdgeInsets.only(left: padding.left, right: padding.right),
      child: playerController.videoWidget(
        const Key("VideoPlayer"),
        fillScreen
            ? (MediaQuery.of(context).orientation == Orientation.portrait
                ? videoFit
                : BoxFit.cover)
            : videoFit,
      ),
    );

    return BackIntentDpad(
      child: Material(
        color: Colors.black,
        child: Theme(
          data: ThemesData.of(context).dark,
          child: Container(
            color: Colors.black,
            child: GestureDetector(
              onScaleUpdate: (details) {
                lastScale = details.scale;
              },
              onScaleEnd: (details) {
                if (lastScale < 1.0) {
                  ref
                      .read(videoPlayerSettingsProvider.notifier)
                      .setFillScreen(false, context: context);
                } else if (lastScale > 1.0) {
                  ref
                      .read(videoPlayerSettingsProvider.notifier)
                      .setFillScreen(true, context: context);
                }
                lastScale = 0.0;
              },
              child: Stack(children: [
                if (!kIsWeb &&
                    ref.watch(videoPlayerSettingsProvider
                        .select((value) => value.ambientBlur)))
                  AmbientBlur(
                    captureFrame: playerController.takeScreenshot,
                  ),
                switch (currentPlaybackModel) {
                  TvPlaybackModel _ => VideoPlayerGuideWrapper(
                      key: const Key("VideoPlayerGuideWrapper"),
                      child: player,
                    ),
                  _ => VideoPlayerNextWrapper(
                      video: player,
                      controls: const DesktopControls(),
                      overlays: [
                        if (errorPlaying) const _VideoErrorWidget(),
                      ],
                    ),
                }
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _VideoErrorWidget extends StatelessWidget {
  const _VideoErrorWidget();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_rounded,
            size: 46,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: 8),
          Text(
            "Error playing file",
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ],
      ),
    );
  }
}
