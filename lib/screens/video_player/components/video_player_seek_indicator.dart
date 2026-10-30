import 'package:flutter/material.dart';
import 'package:kinos/theme/app_theme.dart';

import 'package:async/async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import 'package:kinos/models/account_model.dart';
import 'package:kinos/models/settings/video_player_settings.dart';
import 'package:kinos/providers/settings/video_player_settings_provider.dart';
import 'package:kinos/providers/user_provider.dart';
import 'package:kinos/providers/video_player_provider.dart';
import 'package:kinos/util/input_handler.dart';
import 'package:kinos/util/localization_helper.dart';

/// Controller to trigger the seek indicator from outside (e.g., double-tap).
/// The parent widget creates this controller and passes it to [VideoPlayerSeekIndicator],
/// then calls [seekBack] or [seekForward] to trigger the indicator.
class SeekIndicatorController {
  VoidCallback? _seekBack;
  VoidCallback? _seekForward;
  ValueChanged<int>? _show;

  void show(int seconds) => _show?.call(seconds);

  void seekBack() => _seekBack?.call();
  void seekForward() => _seekForward?.call();
}

class VideoPlayerSeekIndicator extends ConsumerStatefulWidget {
  final SeekIndicatorController? controller;
  final bool handleKeyboard;

  const VideoPlayerSeekIndicator(
      {this.controller, this.handleKeyboard = true, super.key});
  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      VideoPlayerSeekIndicatorState();
}

class VideoPlayerSeekIndicatorState
    extends ConsumerState<VideoPlayerSeekIndicator> {
  RestartableTimer? timer;

  bool visible = false;
  int seekPosition = 0;
  int _pendingSeek = 0;

  @override
  void initState() {
    super.initState();
    _attachController();
  }

  void _attachController() {
    widget.controller?._seekBack = seekBack;
    widget.controller?._seekForward = seekForward;
    widget.controller?._show = (seconds) => onSeekStart(seconds, seek: false);
  }

  void _detachController(SeekIndicatorController? controller) {
    controller?._seekBack = null;
    controller?._seekForward = null;
    controller?._show = null;
  }

  @override
  void didUpdateWidget(covariant VideoPlayerSeekIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _detachController(oldWidget.controller);
      _attachController();
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    _detachController(widget.controller);
    super.dispose();
  }

  void onSeekEnd() {
    setState(() {
      visible = false;
    });
    timer?.cancel();
    timer = null;
    final pending = _pendingSeek;
    _pendingSeek = 0;
    if (pending == 0) return;
    final mediaPlayback = ref.read(mediaPlaybackProvider);
    final newPosition = (mediaPlayback.position.inSeconds + pending)
        .clamp(0, mediaPlayback.duration.inSeconds);
    ref.read(videoPlayerProvider).seek(Duration(seconds: newPosition));
  }

  void onSeekStart(int value, {bool seek = true}) {
    if (value == 0) return;
    if (timer == null) {
      timer = RestartableTimer(
          const Duration(milliseconds: 500), () => onSeekEnd());
      setState(() {
        seekPosition = 0;
        _pendingSeek = 0;
      });
    } else {
      timer?.reset();
    }
    setState(() {
      visible = true;
      seekPosition += value;
      if (seek) _pendingSeek += value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isForward = seekPosition > 0;
    final displayValue = seekPosition.abs();

    return InputHandler<VideoHotKeys>(
      autoFocus: false,
      listenRawKeyboard: widget.handleKeyboard,
      keyMap: ref.watch(videoPlayerSettingsProvider
          .select((value) => value.currentShortcuts)),
      keyMapResult: (result) => widget.handleKeyboard && _onKey(result),
      child: IgnorePointer(
        child: AnimatedOpacity(
          duration:
              AppMotion.enabled(context) ? AppDurations.popover : Duration.zero,
          opacity: (visible && seekPosition != 0) ? 1 : 0,
          child: Center(
            child: AnimatedSwitcher(
              duration: AppMotion.enabled(context)
                  ? AppDurations.popover
                  : Duration.zero,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: animation.drive(Tween(
                    begin: Offset(
                        (child.key as ValueKey<int>).value > 0
                            ? -AppMotion.playerSeekTravel
                            : AppMotion.playerSeekTravel,
                        0),
                    end: Offset.zero,
                  ).chain(CurveTween(curve: AppMotion.easeOut))),
                  child: child,
                ),
              ),
              child: Container(
                key: ValueKey(seekPosition),
                decoration: const BoxDecoration(
                  color: AppPlayerStyle.surface,
                  borderRadius: AppRadii.sheetBorder,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: AppSpacing.sm,
                    children: [
                      Icon(
                        isForward
                            ? IconsaxPlusLinear.forward
                            : IconsaxPlusLinear.backward,
                        color: AppColors.textPrimary,
                      ),
                      Text(
                        "$displayValue ${context.localized.seconds(displayValue)}",
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textPrimary,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void seekBack() {
    final seconds = -ref.read(userProvider.select((value) =>
        (value?.userSettings?.skipBackDuration ??
                UserSettings().skipBackDuration)
            .inSeconds));
    onSeekStart(seconds);
  }

  void seekForward() {
    final seconds = ref.read(userProvider.select((value) =>
        (value?.userSettings?.skipForwardDuration ??
                UserSettings().skipForwardDuration)
            .inSeconds));
    onSeekStart(seconds);
  }

  bool _onKey(VideoHotKeys value) {
    switch (value) {
      case VideoHotKeys.seekForward:
        seekForward();
        return true;
      case VideoHotKeys.seekBack:
        seekBack();
        return true;
      default:
        return false;
    }
  }
}
