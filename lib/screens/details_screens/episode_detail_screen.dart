import 'package:flutter/material.dart';

import 'package:auto_route/auto_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:kinos/models/item_base_model.dart';
import 'package:kinos/providers/items/episode_details_provider.dart';
import 'package:kinos/providers/user_provider.dart';
import 'package:kinos/screens/details_screens/components/media_info_formatters.dart';
import 'package:kinos/screens/details_screens/components/media_info_section.dart';
import 'package:kinos/screens/details_screens/components/media_meta_line.dart';
import 'package:kinos/screens/details_screens/components/movie_hero_content.dart';
import 'package:kinos/playback/series_track_preferences.dart';
import 'package:kinos/screens/details_screens/components/series_track_memory.dart';
import 'package:kinos/screens/shared/media_detail_scaffold.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/humanize_duration.dart';
import 'package:kinos/util/item_base_model/item_base_model_extensions.dart';
import 'package:kinos/util/item_base_model/play_item_helpers.dart';
import 'package:kinos/util/localization_helper.dart';
import 'package:kinos/util/router_extension.dart';
import 'package:kinos/widgets/shared/item_actions.dart';

/// Fiche d'un épisode ouvert directement (recherche, "Continuer à
/// regarder"...) — même structure que [MediaDetailScaffold] pour film et
/// série (bandeau plein cadre, bloc titre superposé, voile, alignement
/// unique du contenu), avec un lien vers la série parente sous le titre.
class EpisodeDetailScreen extends ConsumerStatefulWidget {
  final ItemBaseModel item;
  const EpisodeDetailScreen({required this.item, super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _EpisodeDetailScreenState();
}

class _EpisodeDetailScreenState extends ConsumerState<EpisodeDetailScreen> {
  AutoDisposeStateNotifierProvider<EpisodeDetailsProvider, EpisodeDetailModel>
      get providerId => episodeDetailsProvider(widget.item.id);

  /// Largeur de lecture confortable pour le résumé — ~80 caractères.

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(providerId);
    // `state.episode` est null tant que le premier fetchDetails n'a pas
    // abouti — cf. le même repli que movie/series_detail_screen.dart :
    // MediaDetailScaffold doit toujours être construit (c'est son
    // PullToRefresh interne qui déclenche fetchDetails), avec repli sur
    // `widget.item` tant que le chargement n'est pas terminé.
    final details = state.episode;
    final series = state.series;
    final item = details ?? widget.item;

    // Langues retenues pour la série : les sélecteurs les montrent, et y
    // changer de piste les retient (comme pendant la lecture).
    final seriesId = details == null ? null : seriesIdOf(details);
    final seriesTracks = seriesId == null
        ? null
        : ref.watch(seriesTrackPreferenceProvider(seriesId)).valueOrNull;
    final streams = details == null
        ? null
        : applySeriesTracks(details.mediaStreams, seriesTracks);

    final version = streams?.currentVersionStream;
    final metaLine = details == null
        ? ''
        : buildMediaMetaLine(
            extras: [
              details.seasonEpisodeLabel(context.localized),
              if (details.dateAired != null)
                DateFormat.yMMMd(Localizations.localeOf(context).toString())
                    .format(details.dateAired!),
              if (details.overview.runTime?.humanize != null)
                details.overview.runTime!.humanize!,
            ],
            communityRating: details.overview.communityRating,
            genres: (series?.overview.genreItems ?? details.overview.genreItems)
                .map((genre) => genre.name)
                .toList(),
          );

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
            if (details.dateAired != null)
              (
                label: context.localized.releaseDate,
                value:
                    DateFormat.yMMMd(Localizations.localeOf(context).toString())
                        .format(details.dateAired!),
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
            if (streams!.currentAudioStream?.codec.isNotEmpty ?? false)
              (
                label: 'Codec audio',
                value: streams.currentAudioStream!.codec.toUpperCase()
              ),
            if (formatFileSize(version?.size) != null)
              (label: 'Taille', value: formatFileSize(version?.size)!),
            if (formatBitrate(version?.bitrate) != null)
              (label: 'Débit', value: formatBitrate(version?.bitrate)!),
          ];

    return MediaDetailScaffold(
      label: item.name,
      item: item,
      // L'épisode a sa propre vignette (le plan qui l'illustre) ; à
      // défaut, celle de la série.
      backDrops: details?.images ?? series?.images ?? widget.item.images,
      onRefresh: () async =>
          await ref.read(providerId.notifier).fetchDetails(widget.item),
      title: item.name,
      useTitleLogo: false,
      cinematic: true,
      parentLink: series == null
          ? null
          : (label: series.name, onTap: () => series.navigateTo(context)),
      metaLine: metaLine,
      heroContent: details == null
          ? null
          : MovieHeroContent(
              summary: details.overview.summary,
              streams: streams!,
              onStreamsChanged: (changed) {
                ref
                    .read(providerId.notifier)
                    .updateEpisode(details.copyWith(mediaStreams: changed));
                ref.read(seriesTracksProvider).remember(details, changed);
              },
              trackMemory: seriesId == null
                  ? null
                  : SeriesTrackMemory(seriesId: seriesId),
            ),
      onPlay: details == null
          ? null
          : () async {
              await details.play(context, ref);
              ref.read(providerId.notifier).fetchDetails(widget.item);
            },
      // "Reprendre S1 E3" / "Lire S1 E1" selon l'état de visionnage.
      playLabel: details?.playButtonLabel(context.localized),
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
                    if (series == null) ItemActions.openShow,
                  },
                  onDeleteSuccesFully: (item) {
                    if (context.mounted) context.router.popBack();
                  },
                ),
              ],
      content: (context, padding) => details == null
          ? []
          : [
              if (details.overview.people.isNotEmpty ||
                  state.guestActors.isNotEmpty ||
                  info.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.only(top: AppSpacing.xl),
                  sliver: SliverToBoxAdapter(
                    child: MediaInfoSection(
                      cinematic: true,
                      people: [
                        ...details.overview.people,
                        ...state.guestActors,
                      ],
                      info: info,
                      contentPadding: padding,
                    ),
                  ),
                ),
            ],
    );
  }
}
