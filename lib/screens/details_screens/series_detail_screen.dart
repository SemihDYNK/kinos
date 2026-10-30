import 'package:flutter/material.dart';

import 'package:auto_route/auto_route.dart';
import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kinos/models/item_base_model.dart';
import 'package:kinos/models/items/series_model.dart';
import 'package:kinos/providers/items/series_details_provider.dart';
import 'package:kinos/providers/user_provider.dart';
import 'package:kinos/screens/dashboard/single_row_section.dart';
import 'package:kinos/screens/details_screens/components/media_info_formatters.dart';
import 'package:kinos/screens/details_screens/components/media_info_section.dart';
import 'package:kinos/screens/details_screens/components/media_meta_line.dart';
import 'package:kinos/screens/details_screens/components/movie_hero_content.dart';
import 'package:kinos/models/items/media_streams_model.dart';
import 'package:kinos/screens/shared/media/season_episode_section.dart';
import 'package:kinos/screens/shared/media_detail_scaffold.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/humanize_duration.dart';
import 'package:kinos/util/item_base_model/item_base_model_extensions.dart';
import 'package:kinos/util/item_base_model/play_item_helpers.dart';
import 'package:kinos/util/localization_helper.dart';
import 'package:kinos/util/router_extension.dart';
import 'package:kinos/widgets/shared/item_actions.dart';

class SeriesDetailScreen extends ConsumerStatefulWidget {
  final ItemBaseModel item;
  const SeriesDetailScreen({required this.item, super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends ConsumerState<SeriesDetailScreen> {
  AutoDisposeStateNotifierProvider<SeriesDetailViewNotifier, SeriesModel?>
      get providerId => seriesDetailsProvider(widget.item.id);

  /// Largeur de lecture confortable pour le résumé — ~80 caractères.

  @override
  Widget build(BuildContext context) {
    final details = ref.watch(providerId);
    // `details` est null tant que le premier fetchDetails n'a pas abouti —
    // et c'est justement PullToRefresh (refreshOnStart: true), à l'intérieur
    // de MediaDetailScaffold, qui le déclenche. Un retour anticipé ici,
    // avant de construire MediaDetailScaffold, empêchait ce déclenchement :
    // l'écran restait bloqué sur le fond du Hero de DetailsScreen, sans
    // jamais charger quoi que ce soit. MediaDetailScaffold doit donc
    // toujours être construit ; seul son contenu dérivé de `details` est
    // conditionnel, avec repli sur `widget.item` (déjà disponible) tant que
    // le chargement n'est pas terminé.
    final item = details ?? widget.item;

    final currentEpisode = details?.nextUp;
    // Saison de l'épisode "à suivre" : la section saisons/épisodes s'y
    // ouvre directement, plutôt que sur la première saison par défaut.
    final initialSeasonId = details?.seasons
        ?.firstWhereOrNull((season) => season.season == currentEpisode?.season)
        ?.id;
    // Métadonnées de série, pas d'épisode : nombre de saisons et durée
    // moyenne d'un épisode remplacent durée totale et résolution (qui
    // n'ont pas de sens au niveau de la série entière).
    final seasonCount = details?.seasons
            ?.where((season) => season.episodes.isNotEmpty)
            .length ??
        0;
    final metaLine = details == null
        ? ''
        : buildMediaMetaLine(
            year: details.overview.yearAired,
            extras: [
              if (seasonCount > 0)
                '$seasonCount ${context.localized.season(seasonCount)}',
              if (details.overview.runTime?.humanize != null)
                details.overview.runTime!.humanize!,
            ],
            communityRating: details.overview.communityRating,
            genres:
                details.overview.genreItems.map((genre) => genre.name).toList(),
          );

    final version = currentEpisode?.mediaStreams.currentVersionStream;
    final info = details == null
        ? const <({String label, String value})>[]
        : <({String label, String value})>[
            if (details.overview.directors.isNotEmpty)
              (
                label: context.localized
                    .director(details.overview.directors.length),
                value: details.overview.directors.map((p) => p.name).join(', '),
              ),
            if (details.overview.writers.isNotEmpty)
              (
                label:
                    context.localized.writer(details.overview.writers.length),
                value: details.overview.writers.map((p) => p.name).join(', '),
              ),
            if (details.overview.studios.isNotEmpty)
              (
                label:
                    context.localized.studio(details.overview.studios.length),
                value: details.overview.studios.map((s) => s.name).join(', '),
              ),
            if (details.overview.yearAired != null)
              (
                label: context.localized.releaseDate,
                value: details.overview.yearAired.toString()
              ),
            if (details.overview.productionLocations.isNotEmpty)
              (
                label: 'Pays',
                value: details.overview.productionLocations.join(', ')
              ),
            if (details.overview.communityRating != null &&
                details.overview.communityRating != 0)
              (
                label: context.localized.communityRating,
                value: details.overview.communityRating!.toStringAsFixed(1)
              ),
          ];

    final technicalInfo = details == null
        ? const <({String label, String value})>[]
        : <({String label, String value})>[
            if (version?.container != null)
              (label: 'Conteneur', value: version!.container!.toUpperCase()),
            if (version?.videoStreams.firstOrNull?.codec.isNotEmpty ?? false)
              (
                label: 'Codec vidéo',
                value: version!.videoStreams.first.codec.toUpperCase()
              ),
            if (currentEpisode
                    ?.mediaStreams.currentAudioStream?.codec.isNotEmpty ??
                false)
              (
                label: 'Codec audio',
                value: currentEpisode!.mediaStreams.currentAudioStream!.codec
                    .toUpperCase()
              ),
            if (formatFileSize(version?.size) != null)
              (label: 'Taille', value: formatFileSize(version?.size)!),
            if (formatBitrate(version?.bitrate) != null)
              (label: 'Débit', value: formatBitrate(version?.bitrate)!),
          ];

    return MediaDetailScaffold(
      label: item.name,
      item: item,
      backDrops: item.images,
      onRefresh: () => ref.read(providerId.notifier).fetchDetails(widget.item),
      title: item.name,
      originalTitle: details?.originalTitle,
      metaLine: metaLine,
      cinematic: true,
      seriesLayout: true,
      heroContent: details == null
          ? null
          : MovieHeroContent(
              summary: details.overview.summary,
              streams: currentEpisode?.mediaStreams ??
                  MediaStreamsModel(versionStreams: const []),
              onStreamsChanged: (changed) {
                if (currentEpisode != null) {
                  ref.read(providerId.notifier).updateEpisodeInfo(
                      currentEpisode.copyWith(mediaStreams: changed));
                }
              },
            ),
      onPlay: currentEpisode != null
          ? () async {
              await currentEpisode.play(context, ref);
              ref.read(providerId.notifier).fetchDetails(widget.item);
            }
          : null,
      // "Reprendre S1 E3" / "Lire S1 E1" selon l'état de visionnage de
      // l'épisode "à suivre" — cf. EpisodeModel.playButtonLabel.
      playLabel: currentEpisode?.playButtonLabel(context.localized),
      isFavourite: item.userData.isFavourite,
      onToggleFavourite: () async {
        final response = await ref.read(userProvider.notifier).setAsFavorite(
              !item.userData.isFavourite,
              item.id,
            );
        if (!mounted || response == null) return;
        ref.read(providerId.notifier).updateUserData(item, response.bodyOrThrow);
      },
      isPlayed: item.userData.played,
      onTogglePlayed: () async {
        final response = await ref.read(userProvider.notifier).markAsPlayed(
              !item.userData.played,
              item.id,
            );
        if (!mounted || response == null) return;
        ref.read(providerId.notifier).updateUserData(item, response.bodyOrThrow);
      },
      actions: details == null
          ? null
          : (context) => [
                if (technicalInfo.isNotEmpty)
                  ItemActionButton(
                    icon: const Icon(Icons.info_outline_rounded),
                    label: const Text('Informations techniques'),
                    action: () => showMediaInfoSheet(
                        context, 'Informations techniques', technicalInfo),
                  ),
                ...details.generateActions(
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
              ],
      content: (context, padding) => details == null
          ? []
          : [
              if (details.seasons?.isNotEmpty ?? false)
                SliverPadding(
                  padding: const EdgeInsets.only(top: AppSpacing.xl),
                  sliver: SliverToBoxAdapter(
                    child: SeasonEpisodeSection(
                      seriesPresentation: true,
                      seasons: details.seasons!,
                      contentPadding: padding,
                      initialSeasonId: initialSeasonId,
                    ),
                  ),
                ),
              if (details.overview.people.isNotEmpty || info.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.only(top: AppSpacing.xl),
                  sliver: SliverToBoxAdapter(
                    child: MediaInfoSection(
                        cinematic: true,
                        people: details.overview.people,
                        info: info,
                        contentPadding: padding),
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
