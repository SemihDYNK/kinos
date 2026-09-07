import 'package:flutter/material.dart';

import 'package:fladder/arr/models/arr_library_item.dart';
import 'package:fladder/theme/app_theme.dart';
import 'package:fladder/widgets/shared/labeled_selector.dart';

/// Choix d'une saison entière ou d'un épisode précis, une fois une série
/// sélectionnée — la recherche interactive Sonarr accepte l'un ou l'autre
/// (`seriesId` + `seasonNumber`, ou `episodeId`).
class ArrSeasonEpisodePicker extends StatefulWidget {
  final List<ArrEpisode> episodes;
  final ValueChanged<int> onSearchSeason;
  final ValueChanged<ArrEpisode> onSearchEpisode;

  const ArrSeasonEpisodePicker({
    required this.episodes,
    required this.onSearchSeason,
    required this.onSearchEpisode,
    super.key,
  });

  @override
  State<ArrSeasonEpisodePicker> createState() => _ArrSeasonEpisodePickerState();
}

class _ArrSeasonEpisodePickerState extends State<ArrSeasonEpisodePicker> {
  int? _selectedSeason;

  List<int> get _seasons {
    final seasons =
        widget.episodes.map((episode) => episode.seasonNumber).toSet().toList();
    seasons.sort();
    return seasons;
  }

  String _seasonLabel(int season) =>
      season == 0 ? 'Spéciaux' : 'Saison $season';

  @override
  Widget build(BuildContext context) {
    final seasons = _seasons;
    if (seasons.isEmpty) return const SizedBox.shrink();
    final selectedSeason =
        seasons.contains(_selectedSeason) ? _selectedSeason! : seasons.first;
    final episodesInSeason = widget.episodes
        .where((episode) => episode.seasonNumber == selectedSeason)
        .toList()
      ..sort((a, b) => a.episodeNumber.compareTo(b.episodeNumber));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (seasons.length > 1)
          LabeledSelector(
            label: 'Saison',
            value: _seasonLabel(selectedSeason),
            options: seasons
                .map((season) => (
                      label: _seasonLabel(season),
                      selected: season == selectedSeason,
                      onSelect: () => setState(() => _selectedSeason = season),
                    ))
                .toList(),
          ),
        const SizedBox(height: AppSpacing.sm),
        FocusRing(
          borderRadius: AppRadii.controlBorder,
          onActivate: () => widget.onSearchSeason(selectedSeason),
          child: ExcludeFocus(
            child: OutlinedButton.icon(
              onPressed: () => widget.onSearchSeason(selectedSeason),
              icon: const Icon(Icons.search_rounded),
              label: Text(
                  'Rechercher toute la ${_seasonLabel(selectedSeason).toLowerCase()}'),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Ou un épisode précis',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xs),
        for (final episode in episodesInSeason)
          FocusRing(
            borderRadius: AppRadii.controlBorder,
            onActivate: () => widget.onSearchEpisode(episode),
            child: ExcludeFocus(
              child: InkWell(
                borderRadius: AppRadii.controlBorder,
                onTap: () => widget.onSearchEpisode(episode),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs, vertical: AppSpacing.xs),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 36,
                        child: Text(
                          'E${episode.episodeNumber}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          episode.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
