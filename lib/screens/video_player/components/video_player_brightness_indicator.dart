import 'package:flutter/material.dart';

import 'package:async/async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import 'package:kinos/providers/settings/video_player_settings_provider.dart';
import 'package:kinos/util/localization_helper.dart';
import 'package:kinos/theme/app_theme.dart';

class VideoPlayerBrightnessIndicator extends ConsumerStatefulWidget {
  const VideoPlayerBrightnessIndicator({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _VideoPlayerBrightnessIndicatorState();
}

class _VideoPlayerBrightnessIndicatorState
    extends ConsumerState<VideoPlayerBrightnessIndicator> {
  late double currentBrightness = ref.read(videoPlayerSettingsProvider
      .select((value) => value.screenBrightness ?? 1.0));

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
      videoPlayerSettingsProvider.select((value) => value.screenBrightness),
      (previous, next) {
        if (next == null) return;
        setState(() {
          showIndicator = true;
          currentBrightness = next;
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
                  const Icon(
                    IconsaxPlusLinear.sun_1,
                  ),
                  Text(
                    context.localized
                        .brightnessIndicator((currentBrightness * 100).round()),
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
