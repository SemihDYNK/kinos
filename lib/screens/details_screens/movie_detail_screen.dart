import 'package:kinos/letterboxd/friends/letterboxd_friends_section.dart';
import 'package:kinos/anilist/anilist_mapping_dialog.dart';
import 'package:kinos/models/items/movie_model.dart';
import 'package:flutter/material.dart';

import 'package:auto_route/auto_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:intl/intl.dart';

import 'package:kinos/models/item_base_model.dart';
import 'package:kinos/providers/items/movies_details_provider.dart';
import 'package:kinos/providers/user_provider.dart';
import 'package:kinos/screens/dashboard/single_row_section.dart';
import 'package:kinos/screens/details_screens/components/media_info_formatters.dart';
import 'package:kinos/screens/details_screens/components/media_info_section.dart';
import 'package:kinos/screens/details_screens/components/media_meta_line.dart';
import 'package:kinos/screens/details_screens/components/movie_hero_content.dart';
import 'package:kinos/screens/shared/media_detail_scaffold.dart';
import 'package:kinos/screens/video_player/components/video_player_options_sheet.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/humanize_duration.dart';
import 'package:kinos/util/item_base_model/item_base_model_extensions.dart';
import 'package:kinos/util/item_base_model/play_item_helpers.dart';
import 'package:kinos/util/localization_helper.dart';
import 'package:kinos/util/router_extension.dart';
import 'package:kinos/widgets/shared/item_actions.dart';

class MovieDetailScreen extends ConsumerStatefulWidget {
  final ItemBaseModel item;
  const MovieDetailScreen({required this.item, super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _ItemDetailScreenState();
}

class _ItemDetailScreenState extends ConsumerState<MovieDetailScreen> {
  MovieDetailsProvider get providerInstance =>
      movieDetailsProvider(widget.item.id);

  /// Largeur de lecture confortable pour le résumé — ~80 caractères, ni un
  /// bloc étalé sur toute la largeur de l'écran, ni tronqué.

  @override
  Widget build(BuildContext context) {
    final seed = widget.item;
    final details =
        ref.watch(providerInstance) ?? (seed is MovieModel ? seed : null);
    // Le film source réserve dès la première frame le résumé et les commandes :
    // le logo Hero ne vise pas une fiche vide qui grandit pendant son trajet.
    final item = details ?? widget.item;

    final resolution =
        details?.mediaStreams.currentVersionStream?.detailedResolutionLabel;
    final metaLine = details == null
        ? ''
        : buildMediaMetaLine(
            year: details.premiereDate.year > 0
                ? details.premiereDate.year
                : null,
            extras: [details.overview.runTime?.humanize, resolution]
                .nonNulls
                .toList(),
            communityRating: details.overview.communityRating,
            genres:
                details.overview.genreItems.map((genre) => genre.name).toList(),
          );

    final version = details?.mediaStreams.currentVersionStream;
    // S'arrête après la note de la communauté : les informations techniques
    // du fichier (conteneur, codecs, taille, débit) vivent dans le menu
    // "...", pas ici.
    final info = details == null
        ? const <({String label, String value})>[]
        : <({String label, String value})>[
            if (details.overview.directors.isNotEmpty)
              (
                label: context.localized
                    .director(details.overview.directors.length),
                value: details.overview.directors.map((p) => p.name).join(', ')
              ),
            if (details.overview.writers.isNotEmpty)
              (
                label:
                    context.localized.writer(details.overview.writers.length),
                value: details.overview.writers.map((p) => p.name).join(', ')
              ),
            if (details.overview.studios.isNotEmpty)
              (
                label:
                    context.localized.studio(details.overview.studios.length),
                value: details.overview.studios.map((s) => s.name).join(', ')
              ),
            (
              label: context.localized.releaseDate,
              value:
                  DateFormat.yMMMd(Localizations.localeOf(context).toString())
                      .format(details.premiereDate)
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
            if (details.mediaStreams.currentAudioStream?.codec.isNotEmpty ??
                false)
              (
                label: 'Codec audio',
                value:
                    details.mediaStreams.currentAudioStream!.codec.toUpperCase()
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
      onRefresh: () async =>
          await ref.read(providerInstance.notifier).fetchDetails(widget.item),
      title: item.name,
      originalTitle: details?.originalTitle,
      metaLine: metaLine,
      cinematic: true,
      heroContent: details == null
          ? null
          : MovieHeroContent(
              summary: details.overview.summary,
              streams: details.mediaStreams,
              onStreamsChanged: (changed) => ref
                  .read(providerInstance.notifier)
                  .setMediaStreamHelper(changed),
              onSearchSubtitles: () => showRemoteSubtitleSearch(
                context,
                itemId: details.id,
                onDownloaded: () async {
                  await ref
                      .read(providerInstance.notifier)
                      .fetchDetails(widget.item);
                },
              ),
              footer: switch (details.overview.tmdbId) {
                final tmdbId? => LetterboxdFriendsSection(tmdbId: tmdbId),
                null => null,
              },
            ),
      onPlay: details == null
          ? null
          : () async {
              await details.play(context, ref);
              ref.read(providerInstance.notifier).fetchDetails(widget.item);
            },
      isFavourite: item.userData.isFavourite,
      onToggleFavourite: () async {
        final response = await ref.read(userProvider.notifier).setAsFavorite(
              !item.userData.isFavourite,
              item.id,
            );
        if (!mounted || response == null) return;
        ref
            .read(providerInstance.notifier)
            .updateUserData(item, response.bodyOrThrow);
      },
      isPlayed: item.userData.played,
      onTogglePlayed: () async {
        final response = await ref.read(userProvider.notifier).markAsPlayed(
              !item.userData.played,
              item.id,
            );
        if (!mounted || response == null) return;
        ref
            .read(providerInstance.notifier)
            .updateUserData(item, response.bodyOrThrow);
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
                anilistMappingAction(context, details),
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
