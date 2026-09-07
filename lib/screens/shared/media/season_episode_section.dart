import 'package:flutter/material.dart';

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fladder/models/items/episode_model.dart';
import 'package:fladder/models/items/season_model.dart';
import 'package:fladder/theme/app_theme.dart';
import 'package:fladder/util/humanize_duration.dart';
import 'package:fladder/util/localization_helper.dart';
import 'package:fladder/widgets/shared/labeled_selector.dart';
import 'package:fladder/widgets/shared/media_progress_bar.dart';
import 'package:fladder/widgets/shared/media_thumbnail.dart';

/// Sélecteur de saison ([LabeledSelector], même composant que les
/// sélecteurs de piste juste au-dessus) puis grille des épisodes de la
/// saison choisie — une seule saison affichée à la fois, jamais une
/// rangée par saison empilée (l'ancienne présentation, en carrousels
/// horizontaux).
class SeasonEpisodeSection extends ConsumerStatefulWidget {
  final List<SeasonModel> seasons;
  final EdgeInsets contentPadding;

  /// Saison présélectionnée (ex. celle de l'épisode "à suivre") — repli
  /// sur la première saison si absente ou introuvable.
  final String? initialSeasonId;

  const SeasonEpisodeSection({
    required this.seasons,
    required this.contentPadding,
    this.initialSeasonId,
    super.key,
  });

  @override
  ConsumerState<SeasonEpisodeSection> createState() =>
      _SeasonEpisodeSectionState();
}

class _SeasonEpisodeSectionState extends ConsumerState<SeasonEpisodeSection> {
  String? _selectedSeasonId;

  @override
  void initState() {
    super.initState();
    _selectedSeasonId = widget.initialSeasonId;
  }

  String _seasonLabel(BuildContext context, SeasonModel season) =>
      season.seasonName.isNotEmpty
          ? season.seasonName
          : context.localized.season(1);

  @override
  Widget build(BuildContext context) {
    final withEpisodes =
        widget.seasons.where((season) => season.episodes.isNotEmpty).toList();
    if (withEpisodes.isEmpty) return const SizedBox.shrink();

    final selected = withEpisodes
            .firstWhereOrNull((season) => season.id == _selectedSeasonId) ??
        withEpisodes.first;

    return Padding(
      padding: widget.contentPadding.copyWith(top: 0, bottom: 0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const targetTileWidth = 260.0;
          final columns =
              (constraints.maxWidth / (targetTileWidth + AppSpacing.sm))
                  .floor()
                  .clamp(2, 5);
          final tileWidth =
              (constraints.maxWidth - (columns - 1) * AppSpacing.sm) / columns;
          // Vignette 16:9 + libellé (numéro/titre, une ligne) + durée (une
          // ligne) — même principe de calcul que _CastGrid : la hauteur de
          // rangée découle de la largeur de vignette réelle, jamais d'un
          // ratio fixe approximatif.
          final tileHeight = tileWidth * 9 / 16 + AppSpacing.xs + 44;
          final rowAspectRatio = tileWidth / tileHeight;

          return FocusTraversalGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (withEpisodes.length > 1) ...[
                  LabeledSelector(
                    label: context.localized.season(1),
                    value: _seasonLabel(context, selected),
                    options: withEpisodes
                        .map((season) => (
                              label: _seasonLabel(context, season),
                              selected: season.id == selected.id,
                              onSelect: () =>
                                  setState(() => _selectedSeasonId = season.id),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: selected.episodes.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: AppSpacing.sm,
                    mainAxisSpacing: AppSpacing.md,
                    childAspectRatio: rowAspectRatio,
                  ),
                  itemBuilder: (context, index) =>
                      _EpisodeTile(episode: selected.episodes[index]),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EpisodeTile extends StatelessWidget {
  final EpisodeModel episode;

  const _EpisodeTile({required this.episode});

  @override
  Widget build(BuildContext context) {
    return FocusRing(
      borderRadius: AppRadii.controlBorder,
      onActivate: () => episode.navigateTo(context),
      child: ExcludeFocus(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(
                borderRadius: AppRadii.controlBorder,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    MediaThumbnail(
                      thumbnail: episode.images?.thumb ??
                          episode.images?.randomBackDrop,
                      fallback: episode.images?.primary,
                    ),
                    if (episode.userData.played)
                      const Positioned(
                        top: AppSpacing.xxs,
                        right: AppSpacing.xxs,
                        child: Icon(Icons.check_circle_rounded,
                            color: AppColors.textPrimary, size: 18),
                      ),
                    MediaProgressBar(progress: episode.userData.progress),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${episode.episodeRange}. ${episode.name}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textPrimary),
            ),
            if (episode.overview.runTime != null)
              Text(
                episode.overview.runTime.humanize ?? '',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}
