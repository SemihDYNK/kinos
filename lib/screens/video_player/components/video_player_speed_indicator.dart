import 'dart:math';

import 'package:flutter/material.dart';

import 'package:async/async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import 'package:kinos/providers/settings/video_player_settings_provider.dart';
import 'package:kinos/util/localization_helper.dart';
import 'package:kinos/theme/app_theme.dart';

class VideoPlayerSpeedIndicator extends ConsumerStatefulWidget {
  const VideoPlayerSpeedIndicator({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _VideoPlayerSpeedIndicatorState();
}

class _VideoPlayerSpeedIndicatorState
    extends ConsumerState<VideoPlayerSpeedIndicator> {
  late double currentSpeed = ref.read(playbackRateProvider);

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      playbackRateProvider,
      (previous, next) {
        setState(() {
          showIndicator = true;
          currentSpeed = next;
        });
        timer.reset();
      },
    );
    return IgnorePointer(
      child: AnimatedOpacity(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : AppDurations.pageTransition,
        opacity: showIndicator ? 1 : 0,
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
                  Transform.rotate(
                    angle: currentSpeed < 1 ? pi : 0,
                    child: Icon(
                      speedIcon(currentSpeed),
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    context.localized.speedIndicator(currentSpeed),
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
    );
  }
}

IconData speedIcon(double value) {
  if (value < 1) {
    return IconsaxPlusBroken.flash;
  }
  if (value == 1) {
    return IconsaxPlusLinear.flash_slash;
  }
  return IconsaxPlusLinear.flash;
}
