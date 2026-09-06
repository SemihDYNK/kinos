import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fladder/models/items/episode_model.dart';
import 'package:fladder/models/items/season_model.dart';
import 'package:fladder/theme/app_theme.dart';
import 'package:fladder/util/fladder_image.dart';
import 'package:fladder/util/humanize_duration.dart';
import 'package:fladder/util/item_base_model/play_item_helpers.dart';
import 'package:fladder/util/localization_helper.dart';
import 'package:fladder/widgets/shared/focus_row.dart';

/// Saisons et épisodes d'une série — une rangée horizontale d'épisodes par
/// saison, sobre : vignette 16:9, numéro et titre, coche discrète si vu.
class SeasonEpisodeSection extends ConsumerWidget {
  final List<SeasonModel> seasons;
  final EdgeInsets contentPadding;

  const SeasonEpisodeSection({
    required this.seasons,
    required this.contentPadding,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final withEpisodes = seasons.where((season) => season.episodes.isNotEmpty).toList();
    if (withEpisodes.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: contentPadding.copyWith(top: 0, bottom: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final season in withEpisodes) ...[
            Text(
              season.seasonName.isNotEmpty ? season.seasonName : context.localized.season(1),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 200,
              child: FocusRow(
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: season.episodes.length,
                  separatorBuilder: (context, index) => const SizedBox(width: AppSpacing.sm),
                  itemBuilder: (context, index) => _EpisodeCard(episode: season.episodes[index], ref: ref),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ],
      ),
    );
  }
}

class _EpisodeCard extends StatelessWidget {
  final EpisodeModel episode;
  final WidgetRef ref;

  const _EpisodeCard({required this.episode, required this.ref});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: FocusRing(
        borderRadius: AppRadii.controlBorder,
        onActivate: () => episode.play(context, ref),
        child: ExcludeFocus(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: AppRadii.controlBorder,
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const ColoredBox(color: AppColors.surface),
                      FladderImage(image: episode.getPosters?.primary, fit: BoxFit.cover),
                      if (episode.userData.played)
                        const Positioned(
                          top: AppSpacing.xxs,
                          right: AppSpacing.xxs,
                          child: Icon(Icons.check_circle_rounded, color: AppColors.textPrimary, size: 18),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${episode.episode}. ${episode.name}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary),
              ),
              if (episode.overview.runTime != null)
                Text(
                  episode.overview.runTime.humanize ?? '',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
