import 'package:flutter/material.dart';

import 'package:collection/collection.dart';

import 'package:kinos/models/items/media_streams_model.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/localization_helper.dart';
import 'package:kinos/widgets/shared/labeled_selector.dart';
import 'package:kinos/widgets/shared/track_label.dart';

/// Sélecteurs de version, piste audio et sous-titres — [LabeledSelector],
/// jamais une pastille remplie (cf. CLAUDE.md, pas de couleur d'accent
/// décorative).
class MediaStreamSelectors extends StatelessWidget {
  final MediaStreamsModel mediaStream;
  final ValueChanged<MediaStreamsModel> onChanged;

  const MediaStreamSelectors({
    required this.mediaStream,
    required this.onChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final selectors = <Widget>[
      if (mediaStream.versionStreams.length > 1)
        LabeledSelector(
          label: context.localized.version,
          value: mediaStream.currentVersionStream?.name ?? '',
          options: mediaStream.versionStreams
              .map((e) => (
                    label: e.name,
                    selected: e == mediaStream.currentVersionStream,
                    subtitle: null,
                    onSelect: () => onChanged(
                        mediaStream.copyWith(versionStreamIndex: e.index)),
                  ))
              .toList(),
        ),
      if (mediaStream.audioStreams.isNotEmpty)
        LabeledSelector(
          label: context.localized.audio(1),
          value: formatAudioTrackLabel(context,
                  mediaStream.currentAudioStream ?? AudioStreamModel.no())
              .primary,
          options: mediaStream.audioStreams.map((e) {
            final selected = mediaStream.currentAudioStream?.index == e.index;
            final info = formatAudioTrackLabel(context, e);
            return (
              label: info.primary,
              selected: selected,
              subtitle: info.secondaryFlags.isEmpty
                  ? null
                  : Text(info.secondaryLine,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.textSecondary)),
              onSelect: () => onChanged(
                  mediaStream.copyWith(defaultAudioStreamIndex: e.index)),
            );
          }).toList(),
        ),
      if (mediaStream.subStreams.isNotEmpty)
        LabeledSelector(
          label: context.localized.subtitle,
          value: formatSubtitleTrackLabel(
                  context, mediaStream.currentSubStream ?? SubStreamModel.no())
              .primary,
          options: [SubStreamModel.no(), ...mediaStream.subStreams]
              .mapIndexed((index, e) {
            final selected =
                (mediaStream.currentSubStream ?? SubStreamModel.no()) == e;
            final info = formatSubtitleTrackLabel(context, e);
            return (
              label: info.primary,
              selected: selected,
              subtitle: info.secondaryFlags.isEmpty
                  ? null
                  : Text(info.secondaryLine,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.textSecondary)),
              onSelect: () => onChanged(
                  mediaStream.copyWith(defaultSubStreamIndex: e.index)),
            );
          }).toList(),
        ),
    ];

    if (selectors.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.sm,
      children: selectors,
    );
  }
}
