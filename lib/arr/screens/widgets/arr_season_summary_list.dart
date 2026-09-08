import 'package:flutter/material.dart';

import 'package:kinos/arr/models/arr_media_detail.dart';
import 'package:kinos/theme/app_theme.dart';

/// Liste des saisons d'une série sur la fiche détail — épisodes
/// présents/total et surveillance, par saison. Purement informatif :
/// contrairement à `ArrSeasonEpisodePicker` (recherche interactive), rien
/// ici n'est cliquable.
class ArrSeasonSummaryList extends StatelessWidget {
  final List<ArrSeasonSummary> seasons;

  const ArrSeasonSummaryList({required this.seasons, super.key});

  @override
  Widget build(BuildContext context) {
    if (seasons.isEmpty) return const SizedBox.shrink();
    final sorted = [...seasons]
      ..sort((a, b) => a.seasonNumber.compareTo(b.seasonNumber));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final season in sorted) _SeasonRow(season: season),
      ],
    );
  }
}

class _SeasonRow extends StatelessWidget {
  final ArrSeasonSummary season;
  const _SeasonRow({required this.season});

  @override
  Widget build(BuildContext context) {
    final complete = season.episodeCount > 0 &&
        season.episodeFileCount >= season.episodeCount;
    final label = season.seasonNumber == 0
        ? 'Épisodes spéciaux'
        : 'Saison ${season.seasonNumber}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        children: [
          Icon(
            season.monitored
                ? Icons.bookmark_rounded
                : Icons.bookmark_border_rounded,
            size: 16,
            color: season.monitored
                ? AppColors.textSecondary
                : AppColors.textDisabled,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Text(
            '${season.episodeFileCount}/${season.episodeCount} épisodes',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: complete ? AppColors.success : AppColors.textSecondary),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            season.monitored ? 'Surveillé' : 'Non surveillé',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
