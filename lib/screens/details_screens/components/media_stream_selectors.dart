import 'package:flutter/material.dart';

import 'package:collection/collection.dart';

import 'package:fladder/models/items/media_streams_model.dart';
import 'package:fladder/theme/app_theme.dart';
import 'package:fladder/util/localization_helper.dart';
import 'package:fladder/widgets/shared/labeled_selector.dart';

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
                    onSelect: () => onChanged(
                        mediaStream.copyWith(versionStreamIndex: e.index)),
                  ))
              .toList(),
        ),
      if (mediaStream.audioStreams.isNotEmpty)
        LabeledSelector(
          label: context.localized.audio(1),
          value: mediaStream.currentAudioStream?.displayTitle ?? '',
          options: mediaStream.audioStreams
              .map((e) => (
                    label: e.displayTitle,
                    selected: mediaStream.currentAudioStream?.index == e.index,
                    onSelect: () => onChanged(
                        mediaStream.copyWith(defaultAudioStreamIndex: e.index)),
                  ))
              .toList(),
        ),
      if (mediaStream.subStreams.isNotEmpty)
        LabeledSelector(
          label: context.localized.subtitle,
          value: mediaStream.currentSubStream?.displayTitle ??
              context.localized.off,
          options: [SubStreamModel.no(), ...mediaStream.subStreams]
              .mapIndexed((index, e) => (
                    label: index == 0 ? context.localized.off : e.displayTitle,
                    selected:
                        (mediaStream.currentSubStream ?? SubStreamModel.no()) ==
                            e,
                    onSelect: () => onChanged(
                        mediaStream.copyWith(defaultSubStreamIndex: e.index)),
                  ))
              .toList(),
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
