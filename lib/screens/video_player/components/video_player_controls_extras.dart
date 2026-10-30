import 'package:kinos/widgets/shared/frosted_surface.dart';
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kinos/models/items/media_segments_model.dart';
import 'package:kinos/providers/video_player_provider.dart';
import 'package:kinos/screens/video_player/components/player_motion.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/theme/app_icons.dart';
import 'package:kinos/screens/video_player/components/video_player_chapters.dart';
import 'package:kinos/screens/video_player/components/video_player_queue.dart';
import 'package:kinos/util/localization_helper.dart';

class ChapterButton extends ConsumerWidget {
  final Duration position;
  const ChapterButton({super.key, required this.position});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentChapters =
        ref.watch(playBackModel.select((value) => value?.chapters));
    if (currentChapters != null) {
      return IconButton(
        onPressed: () {
          showPlayerChapterDialogue(
            context,
            chapters: currentChapters,
            currentPosition: position,
            onChapterTapped: (chapter) => ref.read(videoPlayerProvider).seek(
                  chapter.startPosition,
                ),
          );
        },
        icon: const Icon(
          Icons.video_collection_rounded,
        ),
      );
    } else {
      return Container();
    }
  }
}

class OpenQueueButton extends ConsumerWidget {
  const OpenQueueButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playBackModel);
    return IconButton(
      onPressed: state?.queue.isNotEmpty == true
          ? () {
              ref.read(videoPlayerProvider).pause();
              showFullScreenItemQueue(
                context,
                items: state?.queue ?? [],
                currentItem: state?.item,
                onSectionReorder: (section, oldIndex, newIndex) {
                  return ref
                      .read(videoPlayerProvider.notifier)
                      .reorderAudioQueueSection(
                        section,
                        oldIndex,
                        newIndex,
                      );
                },
                playSelected:
                    ref.read(videoPlayerProvider.notifier).playAudioQueueItem,
              );
            }
          : null,
      icon: const Icon(Icons.view_list_rounded),
    );
  }
}

class SkipSegmentButton extends StatefulWidget {
  final MediaSegment? segment;
  final SegmentSkip? skipType;
  final SegmentVisibility visibility;
  final VoidCallback pressedSkip;
  const SkipSegmentButton({
    required this.segment,
    this.skipType,
    required this.visibility,
    required this.pressedSkip,
    super.key,
  });

  @override
  State<SkipSegmentButton> createState() => _SkipSegmentButtonState();
}

class _SkipSegmentButtonState extends State<SkipSegmentButton> {
  MediaSegment? _lastSegment;
  bool _pressed = false;

  void _activate() {
    if (AppMotion.enabled(context)) setState(() => _pressed = true);
    widget.pressedSkip();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.segment != null) _lastSegment = widget.segment;
    final segment = _lastSegment;
    final visible = widget.segment != null &&
        widget.skipType != SegmentSkip.none &&
        widget.visibility != SegmentVisibility.hidden;
    final duration =
        AppMotion.enabled(context) ? AppDurations.hover : Duration.zero;
    return PlayerControlsMotion(
      visible: visible,
      hiddenOffset: const Offset(AppSpacing.lg, 0),
      child: AnimatedOpacity(
        duration: duration,
        opacity: widget.visibility == SegmentVisibility.partially
            ? AppPlayerStyle.segmentPartialOpacity
            : 1,
        child: AnimatedScale(
          duration: duration,
          curve: AppMotion.easeOut,
          scale: _pressed ? AppMotion.posterActionScale : 1,
          onEnd: () {
            if (mounted && _pressed) setState(() => _pressed = false);
          },
          child: segment == null
              ? const SizedBox.shrink()
              : FocusRing(
                  borderRadius: AppRadii.controlBorder,
                  onActivate: _activate,
                  child: FrostedSurface(
                    borderRadius: AppRadii.controlBorder,
                    child: Material(
                      color: Colors.transparent,
                      child: ExcludeFocus(
                          child: TextButton(
                        onPressed: _activate,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          backgroundColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm),
                          shape: const RoundedRectangleBorder(
                              borderRadius: AppRadii.controlBorder),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          spacing: AppSpacing.xs,
                          children: [
                            Text(context.localized
                                .skipButtonLabel(segment.type.label(context))),
                            const Icon(AppIcons.next),
                          ],
                        ),
                      )),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
