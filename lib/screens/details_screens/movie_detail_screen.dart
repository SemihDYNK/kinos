import 'package:flutter/material.dart';

import 'package:auto_route/auto_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:intl/intl.dart';

import 'package:fladder/models/item_base_model.dart';
import 'package:fladder/providers/items/movies_details_provider.dart';
import 'package:fladder/providers/user_provider.dart';
import 'package:fladder/screens/dashboard/single_row_section.dart';
import 'package:fladder/screens/details_screens/components/media_info_formatters.dart';
import 'package:fladder/screens/details_screens/components/media_info_section.dart';
import 'package:fladder/screens/details_screens/components/media_meta_line.dart';
import 'package:fladder/screens/details_screens/components/media_stream_selectors.dart';
import 'package:fladder/screens/shared/media_detail_scaffold.dart';
import 'package:fladder/theme/app_theme.dart';
import 'package:fladder/util/item_base_model/item_base_model_extensions.dart';
import 'package:fladder/util/item_base_model/play_item_helpers.dart';
import 'package:fladder/util/localization_helper.dart';
import 'package:fladder/util/router_extension.dart';
import 'package:fladder/widgets/shared/item_actions.dart';

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
  static const _readingWidth = 640.0;

  @override
  Widget build(BuildContext context) {
    final details = ref.watch(providerInstance);
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

    final resolution =
        details?.mediaStreams.currentVersionStream?.detailedResolutionLabel;
    final metaLine = details == null
        ? ''
        : buildMediaMetaLine(
            year: details.premiereDate.year,
            runTime: details.overview.runTime,
            resolution: resolution,
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
      onPlay: details == null
          ? null
          : () async {
              await details.play(context, ref);
              ref.read(providerInstance.notifier).fetchDetails(widget.item);
            },
      isFavourite: item.userData.isFavourite,
      onToggleFavourite: () => ref.read(userProvider.notifier).setAsFavorite(
            !item.userData.isFavourite,
            item.id,
          ),
      isPlayed: item.userData.played,
      onTogglePlayed: () => ref.read(userProvider.notifier).markAsPlayed(
            !item.userData.played,
            item.id,
          ),
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
              if (details.overview.summary.isNotEmpty)
                SliverPadding(
                  padding: padding,
                  sliver: SliverToBoxAdapter(
                    child: ConstrainedBox(
                      constraints:
                          const BoxConstraints(maxWidth: _readingWidth),
                      child: Text(
                        details.overview.summary,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ),
                ),
              if (details.mediaStreams.audioStreams.isNotEmpty ||
                  details.mediaStreams.subStreams.isNotEmpty)
                SliverPadding(
                  padding: padding.copyWith(top: AppSpacing.lg),
                  sliver: SliverToBoxAdapter(
                    child: MediaStreamSelectors(
                      mediaStream: details.mediaStreams,
                      onChanged: (changed) => ref
                          .read(providerInstance.notifier)
                          .setMediaStreamHelper(changed),
                    ),
                  ),
                ),
              if (details.overview.people.isNotEmpty || info.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.only(top: AppSpacing.xl),
                  sliver: SliverToBoxAdapter(
                    child: MediaInfoSection(
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
