import 'package:flutter/material.dart';

import 'package:collection/collection.dart';

import 'package:fladder/models/items/media_streams_model.dart';
import 'package:fladder/theme/app_theme.dart';
import 'package:fladder/util/localization_helper.dart';
import 'package:fladder/widgets/shared/modal_bottom_sheet.dart';

/// Sélecteurs de version, piste audio et sous-titres — sobres : un texte
/// "Libellé · valeur" qui ouvre une liste de choix, jamais une pastille
/// remplie (cf. CLAUDE.md, pas de couleur d'accent décorative).
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
        _StreamSelector(
          label: context.localized.version,
          value: mediaStream.currentVersionStream?.name ?? '',
          options: mediaStream.versionStreams
              .map((e) => (
                    label: e.name,
                    selected: e == mediaStream.currentVersionStream,
                    onSelect: () => onChanged(mediaStream.copyWith(versionStreamIndex: e.index)),
                  ))
              .toList(),
        ),
      if (mediaStream.audioStreams.isNotEmpty)
        _StreamSelector(
          label: context.localized.audio(1),
          value: mediaStream.currentAudioStream?.displayTitle ?? '',
          options: mediaStream.audioStreams
              .map((e) => (
                    label: e.displayTitle,
                    selected: mediaStream.currentAudioStream?.index == e.index,
                    onSelect: () => onChanged(mediaStream.copyWith(defaultAudioStreamIndex: e.index)),
                  ))
              .toList(),
        ),
      if (mediaStream.subStreams.isNotEmpty)
        _StreamSelector(
          label: context.localized.subtitle,
          value: mediaStream.currentSubStream?.displayTitle ?? context.localized.off,
          options: [SubStreamModel.no(), ...mediaStream.subStreams]
              .mapIndexed((index, e) => (
                    label: index == 0 ? context.localized.off : e.displayTitle,
                    selected: (mediaStream.currentSubStream ?? SubStreamModel.no()) == e,
                    onSelect: () => onChanged(mediaStream.copyWith(defaultSubStreamIndex: e.index)),
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

class _StreamSelector extends StatelessWidget {
  final String label;
  final String value;
  final List<({String label, bool selected, VoidCallback onSelect})> options;

  const _StreamSelector({
    required this.label,
    required this.value,
    required this.options,
  });

  void _open(BuildContext context) {
    showBottomSheetPill(
      context: context,
      content: (context, scrollController) => ListView(
        controller: scrollController,
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: Text(label, style: Theme.of(context).textTheme.headlineSmall),
          ),
          for (final option in options)
            FocusRing(
              borderRadius: AppRadii.controlBorder,
              onActivate: () {
                option.onSelect();
                Navigator.of(context).pop();
              },
              child: ExcludeFocus(
                child: ListTile(
                  onTap: () {
                    option.onSelect();
                    Navigator.of(context).pop();
                  },
                  title: Text(
                    option.label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: option.selected ? AppColors.textPrimary : AppColors.textSecondary,
                        ),
                  ),
                  trailing: option.selected ? const Icon(Icons.check_rounded, color: AppColors.textPrimary) : null,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FocusRing(
      borderRadius: AppRadii.controlBorder,
      onActivate: () => _open(context),
      child: ExcludeFocus(
        child: InkWell(
          borderRadius: AppRadii.controlBorder,
          onTap: () => _open(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.xxs),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$label · ',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                ),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary),
                ),
                const SizedBox(width: AppSpacing.xxs),
                const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
