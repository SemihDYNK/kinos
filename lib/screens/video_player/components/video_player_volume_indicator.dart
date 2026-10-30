import 'package:kinos/screens/video_player/components/player_motion.dart';
import 'package:flutter/material.dart';

import 'package:async/async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import 'package:kinos/providers/settings/video_player_settings_provider.dart';
import 'package:kinos/util/localization_helper.dart';
import 'package:kinos/theme/app_theme.dart';

class VideoPlayerVolumeIndicator extends ConsumerStatefulWidget {
  const VideoPlayerVolumeIndicator({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _VideoPlayerVolumeIndicatorState();
}

class _VideoPlayerVolumeIndicatorState
    extends ConsumerState<VideoPlayerVolumeIndicator>
    with SingleTickerProviderStateMixin {
  late final _pulse =
      AnimationController(vsync: this, duration: AppDurations.selection);
  Animation<double> _scale = const AlwaysStoppedAnimation(1);
  late double currentVolume = ref.read(
      videoPlayerSettingsProvider.select((value) => value.internalVolume));

  bool showIndicator = false;
  late final timer = RestartableTimer(const Duration(seconds: 1), () {
    setState(() {
      showIndicator = false;
    });
  });

  @override
  void dispose() {
    showIndicator = false;
    timer.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!AppMotion.enabled(context)) {
      _pulse.stop();
      _scale = const AlwaysStoppedAnimation(1);
    }
  }

  void _animateVolume() {
    if (!AppMotion.enabled(context)) return;
    _scale = TweenSequence<double>([
      TweenSequenceItem(
          weight: 1,
          tween: Tween(begin: _scale.value, end: AppMotion.playerVolumePulse)
              .chain(CurveTween(curve: AppMotion.easeOut))),
      TweenSequenceItem(
          weight: 1,
          tween: Tween(begin: AppMotion.playerVolumePulse, end: 1.0)
              .chain(CurveTween(curve: AppMotion.easeOut))),
    ]).animate(_pulse);
    _pulse.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      videoPlayerSettingsProvider.select((value) => value.internalVolume),
      (previous, next) {
        setState(() {
          showIndicator = true;
          currentVolume = next;
          _animateVolume();
        });
        timer.reset();
      },
    );
    return IgnorePointer(
      child: PlayerControlsMotion(
        visible: showIndicator,
        child: Center(
          child: Container(
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
                  AnimatedBuilder(
                    animation: _pulse,
                    child: Icon(volumeIcon(currentVolume)),
                    builder: (context, child) =>
                        Transform.scale(scale: _scale.value, child: child),
                  ),
                  Text(
                    context.localized.volumeIndicator(currentVolume.round()),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textPrimary,
                        ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

IconData volumeIcon(double value) {
  if (value <= 0) {
    return IconsaxPlusLinear.volume_mute;
  }
  if (value < 50) {
    return IconsaxPlusLinear.volume_low_1;
  }
  return IconsaxPlusLinear.volume_high;
}
