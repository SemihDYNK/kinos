import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kinos/playback/series_track_preferences.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/widgets/shared/track_label.dart';

/// Rappel des langues retenues pour une série, sous les sélecteurs de
/// pistes, avec de quoi les oublier (retour aux langues du profil).
class SeriesTrackMemory extends ConsumerWidget {
  const SeriesTrackMemory({required this.seriesId, super.key});
  final String seriesId;

  static String describe(SeriesTrackPreference pref) {
    final parts = [
      if (pref.audioLanguage case final audio?)
        'audio ${trackLanguageName(audio)?.toLowerCase() ?? audio}',
      if (pref.subtitlesOff)
        'sans sous-titres'
      else if (pref.subtitleLanguage case final sub?)
        'sous-titres ${trackLanguageName(sub)?.toLowerCase() ?? sub}'
            '${pref.subtitleForced ? ' forcés' : ''}',
    ];
    return 'Retenu pour la série : ${parts.join(' · ')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pref = ref.watch(seriesTrackPreferenceProvider(seriesId)).valueOrNull;
    if (pref == null || pref.isEmpty) return const SizedBox.shrink();
    final style = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(color: AppColors.textPrimary.withValues(alpha: .75));
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xs, AppSpacing.xxs, AppSpacing.xxs, 0),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.xs,
        children: [
          Text(describe(pref), style: style),
          TextButton(
            onPressed: () => ref.read(seriesTracksProvider).forget(seriesId),
            child: const Text('Oublier'),
          ),
        ],
      ),
    );
  }
}
