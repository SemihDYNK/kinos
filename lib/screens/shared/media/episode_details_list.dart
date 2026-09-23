import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import 'package:kinos/models/items/episode_model.dart';
import 'package:kinos/providers/settings/client_settings_provider.dart';
import 'package:kinos/screens/shared/media/episode_posters.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/adaptive_layout/adaptive_layout.dart';
import 'package:kinos/util/humanize_duration.dart';
import 'package:kinos/util/item_base_model/item_base_model_extensions.dart';
import 'package:kinos/util/list_padding.dart';
import 'package:kinos/util/localization_helper.dart';

enum EpisodeDetailsViewType {
  list(icon: IconsaxPlusBold.grid_6),
  grid(icon: IconsaxPlusBold.grid_2);

  const EpisodeDetailsViewType({required this.icon});

  String label(BuildContext context) => switch (this) {
        EpisodeDetailsViewType.list => context.localized.list,
        EpisodeDetailsViewType.grid => context.localized.grid,
      };

  final IconData icon;
}

class EpisodeDetailsList extends ConsumerWidget {
  final EpisodeDetailsViewType viewType;
  final List<EpisodeModel> episodes;
  final EdgeInsets? padding;
  const EpisodeDetailsList({required this.viewType, required this.episodes, this.padding, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = MediaQuery.sizeOf(context).width /
        ((AdaptiveLayout.poster(context).gridRatio * 2) *
            ref.watch(clientSettingsProvider.select((value) => value.posterSize)));
    final decimals = size - size.toInt();
    // Vue grille : hauteur de vignette dérivée de la largeur réelle,
    // jamais d'un ratio fixe (`childAspectRatio` reconverti en pixels par
    // le delegate via une division flottante — l'arrondi qui en ressort
    // peut être inférieur de quelques dixièmes de pixel à la hauteur que
    // le libellé sous l'image (`EpisodePoster.showLabel`, une ligne)
    // réclame quand même en entier : débordement visible en debug, bande
    // rayée sur toutes les vignettes à la fois. Même correction que
    // `season_episode_section.dart`/`media_info_section.dart`. Largeur de
    // grille dérivée de la même base que `crossAxisCount` ci-dessous
    // (`MediaQuery.sizeOf(context).width`), pas une nouvelle mesure qui
    // pourrait diverger.
    final crossAxisCount = size.toInt().clamp(1, double.maxFinite).toInt();
    final crossAxisSpacing = (8 * decimals) + 8;
    final gridWidth =
        MediaQuery.sizeOf(context).width - (padding?.horizontal ?? 0);
    final tileWidth =
        (gridWidth - (crossAxisCount - 1) * crossAxisSpacing) / crossAxisCount;
    // EpisodePoster : image 1,76:1 (cf. son AspectRatio interne, neutralisé
    // par la hauteur exacte que `mainAxisExtent` lui impose désormais) +
    // libellé d'une ligne sous l'image (marge `AppSpacing.xxs` puis le
    // texte, cf. `EpisodePoster.showLabel`) — 24 en repli généreux pour
    // cette ligne plutôt qu'une mesure exacte du style de texte par défaut
    // (pas de rendu réel disponible ici pour la calculer).
    final tileHeight = tileWidth / 1.76 + AppSpacing.xxs + 24;
    final textStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
        );
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: switch (viewType) {
        EpisodeDetailsViewType.list => ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: padding,
            itemCount: episodes.length,
            itemBuilder: (context, index) {
              final episode = episodes[index];
              List<Widget> children = [
                Flexible(
                  flex: 1,
                  child: EpisodePoster(
                    episode: episode,
                    showLabel: false,
                    actions: episode.generateActions(context, ref),
                    onTap: () => episode.navigateTo(context),
                    isCurrentEpisode: false,
                  ),
                ),
                const SizedBox(width: 16, height: 16),
                Flexible(
                  flex: 3,
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Flexible(
                        child: Column(
                          mainAxisSize: MainAxisSize.max,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SelectableText(
                                  episode.seasonEpisodeLabel(context.localized),
                                  style: textStyle,
                                ),
                                if (episode.overview.runTime != null)
                                  SelectableText(
                                    " - ${episode.overview.runTime!.humanize!}",
                                    style: textStyle,
                                  ),
                              ],
                            ),
                            SelectableText(
                              episode.name,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            SelectableText(
                              episode.overview.summary,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ].addPadding(const EdgeInsets.symmetric(vertical: 4)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ];
              return LayoutBuilder(
                builder: (context, constraints) {
                  return Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: constraints.maxWidth > 800
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: children,
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: children,
                              ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        EpisodeDetailsViewType.grid => GridView.builder(
            shrinkWrap: true,
            padding: padding,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: crossAxisSpacing,
                crossAxisSpacing: crossAxisSpacing,
                mainAxisExtent: tileHeight),
            itemCount: episodes.length,
            itemBuilder: (context, index) {
              final episode = episodes[index];
              return EpisodePoster(
                episode: episode,
                actions: episode.generateActions(context, ref),
                onTap: () => episode.navigateTo(context),
                isCurrentEpisode: false,
              );
            },
          )
      },
    );
  }
}
