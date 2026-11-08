import 'package:flutter/material.dart';
import 'package:kinos/models/items/media_streams_model.dart';
import 'package:kinos/screens/details_screens/components/media_stream_selectors.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/widgets/shared/frosted_surface.dart';

/// Film and episode reading block and track controls in the cinematic hero.
class MovieHeroContent extends StatelessWidget {
  const MovieHeroContent(
      {required this.summary,
      required this.streams,
      required this.onStreamsChanged,
      this.onSearchSubtitles,
      super.key});
  final String summary;
  final MediaStreamsModel streams;
  final ValueChanged<MediaStreamsModel> onStreamsChanged;
  final VoidCallback? onSearchSubtitles;
  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (summary.isNotEmpty)
            ConstrainedBox(
                constraints: const BoxConstraints(
                    maxWidth: AppDetailLayout.movieSynopsisWidth),
                child: Text(summary,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppColors.textPrimary))),
          if (streams.audioStreams.isNotEmpty ||
              streams.subStreams.isNotEmpty ||
              streams.versionStreams.length > 1) ...[
            const SizedBox(height: AppSpacing.md),
            FrostedSurface(
                borderRadius: AppRadii.controlBorder,
                child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    child: MediaStreamSelectors(
                        mediaStream: streams,
                        onChanged: onStreamsChanged,
                        onSearchSubtitles: onSearchSubtitles))),
          ],
        ],
      );
}
