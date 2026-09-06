import 'package:flutter/material.dart';

import 'package:auto_route/auto_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fladder/models/item_base_model.dart';
import 'package:fladder/models/items/series_model.dart';
import 'package:fladder/providers/items/series_details_provider.dart';
import 'package:fladder/providers/user_provider.dart';
import 'package:fladder/screens/dashboard/single_row_section.dart';
import 'package:fladder/screens/details_screens/components/media_meta_line.dart';
import 'package:fladder/screens/details_screens/components/media_stream_selectors.dart';
import 'package:fladder/screens/shared/media/media_cast_row.dart';
import 'package:fladder/screens/shared/media/season_episode_section.dart';
import 'package:fladder/screens/shared/media_detail_scaffold.dart';
import 'package:fladder/theme/app_theme.dart';
import 'package:fladder/util/item_base_model/item_base_model_extensions.dart';
import 'package:fladder/util/item_base_model/play_item_helpers.dart';
import 'package:fladder/util/localization_helper.dart';
import 'package:fladder/util/router_extension.dart';

class SeriesDetailScreen extends ConsumerStatefulWidget {
  final ItemBaseModel item;
  const SeriesDetailScreen({required this.item, super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends ConsumerState<SeriesDetailScreen> {
  AutoDisposeStateNotifierProvider<SeriesDetailViewNotifier, SeriesModel?> get providerId =>
      seriesDetailsProvider(widget.item.id);

  /// Largeur de lecture confortable pour le résumé — ~80 caractères.
  static const _readingWidth = 640.0;

  @override
  Widget build(BuildContext context) {
    final details = ref.watch(providerId);

    if (details == null) {
      return const SizedBox.shrink();
    }

    final currentEpisode = details.nextUp;
    final resolution = currentEpisode?.mediaStreams.currentVersionStream?.detailedResolutionLabel;
    final metaLine = buildMediaMetaLine(
      year: details.overview.yearAired,
      runTime: details.overview.runTime,
      resolution: resolution,
      communityRating: details.overview.communityRating,
      genres: details.overview.genreItems.map((genre) => genre.name).toList(),
    );

    return MediaDetailScaffold(
      label: details.name,
      item: details,
      backDrops: details.images,
      onRefresh: () => ref.read(providerId.notifier).fetchDetails(widget.item),
      title: details.name,
      originalTitle: details.originalTitle,
      metaLine: metaLine,
      onPlay: currentEpisode != null
          ? () async {
              await currentEpisode.play(context, ref);
              ref.read(providerId.notifier).fetchDetails(widget.item);
            }
          : null,
      isFavourite: details.userData.isFavourite,
      onToggleFavourite: () => ref.read(userProvider.notifier).setAsFavorite(
            !details.userData.isFavourite,
            details.id,
          ),
      isPlayed: details.userData.played,
      onTogglePlayed: () => ref.read(userProvider.notifier).markAsPlayed(
            !details.userData.played,
            details.id,
          ),
      actions: (context) => details.generateActions(
        context,
        ref,
        exclude: {
          ItemActions.play,
          ItemActions.playFromStart,
          ItemActions.details,
          ItemActions.markPlayed,
          ItemActions.markUnplayed,
          ItemActions.setFavorite,
        },
        onDeleteSuccesFully: (item) {
          if (context.mounted) context.router.popBack();
        },
      ),
      content: (context, padding) => [
        if (details.overview.summary.isNotEmpty)
          SliverPadding(
            padding: padding,
            sliver: SliverToBoxAdapter(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _readingWidth),
                child: Text(
                  details.overview.summary,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
          ),
        // Saisons et épisodes juste sous le résumé, avant les sélecteurs de
        // flux (qui concernent l'épisode "à suivre", pas la série entière).
        if (details.seasons?.isNotEmpty ?? false)
          SliverPadding(
            padding: const EdgeInsets.only(top: AppSpacing.xl),
            sliver: SliverToBoxAdapter(
              child: SeasonEpisodeSection(seasons: details.seasons!, contentPadding: padding),
            ),
          ),
        if (currentEpisode != null &&
            (currentEpisode.mediaStreams.audioStreams.isNotEmpty ||
                currentEpisode.mediaStreams.subStreams.isNotEmpty))
          SliverPadding(
            padding: padding.copyWith(top: AppSpacing.xl),
            sliver: SliverToBoxAdapter(
              child: MediaStreamSelectors(
                mediaStream: currentEpisode.mediaStreams,
                onChanged: (changed) => ref.read(providerId.notifier).updateEpisodeInfo(
                      currentEpisode.copyWith(mediaStreams: changed),
                    ),
              ),
            ),
          ),
        if (details.overview.people.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.only(top: AppSpacing.xl),
            sliver: SliverToBoxAdapter(
              child: MediaCastRow(people: details.overview.people, contentPadding: padding),
            ),
          ),
        if (details.related.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.only(top: AppSpacing.xl),
            sliver: SingleRowSection(
              title: context.localized.related,
              items: details.related,
              contentPadding: padding,
            ),
          ),
      ],
    );
  }
}
