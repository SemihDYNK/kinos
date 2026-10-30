import 'package:kinos/screens/shared/media_navigation.dart';
import 'package:flutter/material.dart';

import 'package:auto_route/auto_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import 'package:kinos/models/items/images_models.dart';
import 'package:kinos/models/seerr/seerr_dashboard_model.dart';
import 'package:kinos/providers/seerr/seerr_details_provider.dart';
import 'package:kinos/screens/details_screens/components/media_meta_line.dart';
import 'package:kinos/screens/seerr/seerr_media_management.dart';
import 'package:kinos/screens/seerr/widgets/download_status_label.dart';
import 'package:kinos/screens/seerr/widgets/season_download_progress_widget.dart';
import 'package:kinos/screens/seerr/widgets/seerr_poster_row.dart';
import 'package:kinos/screens/seerr/widgets/seerr_request_popup.dart';
import 'package:kinos/screens/seerr/widgets/seerr_requests_sheet.dart';
import 'package:kinos/screens/shared/media/external_urls.dart';
import 'package:kinos/screens/shared/media/people_row.dart';
import 'package:kinos/screens/shared/media_detail_scaffold.dart';
import 'package:kinos/seerr/seerr_models.dart';
import 'package:kinos/theme.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/widgets/shared/app_page_header.dart';
import 'package:kinos/util/adaptive_layout/adaptive_layout.dart';
import 'package:kinos/util/kinos_image.dart';
import 'package:kinos/util/focus_provider.dart';
import 'package:kinos/util/localization_helper.dart';
import 'package:kinos/util/refresh_state.dart';
import 'package:kinos/widgets/shared/ensure_visible.dart';
import 'package:kinos/widgets/shared/item_actions.dart';

@RoutePage()
class SeerrDetailsScreen extends ConsumerWidget {
  final Object? tag;
  final String mediaType;
  final int tmdbId;
  final SeerrDashboardPosterModel? poster;

  const SeerrDetailsScreen({
    @PathParam('mediaType') required this.mediaType,
    @PathParam('tmdbId') required this.tmdbId,
    this.poster,
    this.tag,
    super.key,
  });

  /// Largeur de lecture confortable pour le résumé — même valeur que les
  /// fiches film/série Jellyfin ([MovieDetailScreen]/[SeriesDetailScreen]).

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = seerrDetailsProvider(
      tmdbId: tmdbId,
      mediaType: SeerrMediaType.fromString(mediaType),
      poster: poster,
    );
    final state = ref.watch(provider);
    final notifier = ref.read(provider.notifier);

    final currentPoster = state.poster;
    final itemBaseModel = currentPoster?.itemBaseModel;

    final externalUrls = state.buildExternalUrls();
    final officialTrailerUrl = state.officialTrailerUrl;

    final hasKnownStatus = currentPoster?.hasDisplayStatus ?? false;
    final requests = state.poster?.mediaInfo?.requests ?? [];
    final pendingRequests = requests
        .where((request) => request.requestStatus == SeerrRequestStatus.pending)
        .toList();

    final rottenTomatoes = state.ratings?.rt;

    final canManageRequest = state.currentUser?.canManageRequests ?? false;
    final hasUsersRequests = requests
        .any((request) => request.requestedBy?.id == state.currentUser?.id);
    final hasVisibleRequests =
        (canManageRequest || hasUsersRequests) && requests.isNotEmpty;

    final canRequestMore = hasKnownStatus
        ? switch (currentPoster?.type) {
            SeerrMediaType.movie => false,
            SeerrMediaType.tvshow => true,
            _ => false,
          }
        : true;

    final mainButtonLabel = currentPoster?.type == SeerrMediaType.movie
        ? context.localized.request
        : (canRequestMore
            ? context.localized.requestMore
            : context.localized.request);

    // "PG · 2026 · 6.1 · Family, Fantasy, Comedy, Adventure" — texte simple,
    // jamais de badges, même règle que les fiches film/série Jellyfin (cf.
    // buildMediaMetaLine). La classification vient de TMDB via Seerr : les
    // fiches Jellyfin ne la branchent pas encore, mais le paramètre est
    // commun aux deux.
    final metaLine = currentPoster == null
        ? ''
        : buildMediaMetaLine(
            officialRating: state.contentRating,
            year: int.tryParse(currentPoster.releaseYear ?? ''),
            communityRating: state.voteAverage,
            genres: state.genres.map((genre) => genre.name).nonNulls.toList(),
          );

    return MediaNavigationScope(
        tag: tag,
        child: MediaDetailScaffold(
          label: currentPoster?.title ?? context.localized.request,
          item: itemBaseModel,
          // Repli d'identité de teinte quand le titre n'est pas (encore) dans
          // la bibliothèque Jellyfin — cf. la doc de [MediaDetailScaffold.paletteId].
          paletteId: itemBaseModel == null && currentPoster != null
              ? 'seerr-tmdb-${currentPoster.tmdbId}'
              : null,
          backDrops: currentPoster?.images,
          onRefresh: notifier.fetch,
          title: currentPoster?.title ?? context.localized.request,
          metaLine: metaLine,
          // Pas de lecture ici (contenu pas nécessairement téléchargé) : le
          // bouton principal envoie une demande Seerr, d'où l'icône dédiée.
          onPlay: currentPoster != null && canRequestMore
              ? () => openSeerrRequestPopup(context, currentPoster)
              : null,
          playIcon: Icons.add_rounded,
          playLabel: mainButtonLabel,
          actions: currentPoster == null
              ? null
              : (context) => [
                    if (hasVisibleRequests)
                      ItemActionButton(
                        icon: const Icon(IconsaxPlusBold.folder_open),
                        label: Text(
                          pendingRequests.isNotEmpty
                              ? '${context.localized.manageRequest} (${pendingRequests.length})'
                              : context.localized.manageRequest,
                        ),
                        action: () => showSeerrRequestsSheet(
                          context: context,
                          poster: currentPoster,
                          requests: requests,
                          onApprove: notifier.approveRequest,
                          onDecline: notifier.declineRequest,
                        ),
                      ),
                    if (state.hasTrailerAction)
                      ItemActionButton(
                        icon: const Icon(IconsaxPlusLinear.video_play),
                        label: Text(context.localized.viewTrailer),
                        action: () async {
                          if (officialTrailerUrl == null) return;
                          await launchUrl(context, officialTrailerUrl);
                        },
                      ),
                    if (hasVisibleRequests && currentPoster.mediaInfo != null)
                      ItemActionButton(
                        icon: const Icon(IconsaxPlusLinear.setting_4),
                        label: const Text('Gérer le média'),
                        action: () => showMediaManagementSheet(
                          context: context,
                          mediaInfo: currentPoster,
                          onActionComplete: () => context.refreshData(),
                        ),
                      ),
                  ],
          content: (context, padding) => currentPoster == null
              ? []
              : [
                  if (hasKnownStatus ||
                      rottenTomatoes?.criticsScore != null ||
                      rottenTomatoes?.audienceScore != null)
                    SliverPadding(
                      padding: padding,
                      sliver: SliverToBoxAdapter(
                        child: _SeerrStatusLine(
                          poster: currentPoster,
                          hasKnownStatus: hasKnownStatus,
                          criticsScore: rottenTomatoes?.criticsScore,
                          audienceScore: rottenTomatoes?.audienceScore,
                        ),
                      ),
                    ),
                  SliverPadding(
                    padding: padding.copyWith(top: AppSpacing.sm),
                    sliver: SliverToBoxAdapter(
                      child: MediaSynopsis(currentPoster.overview.trim().isEmpty
                          ? context.localized.noOverviewAvailable
                          : currentPoster.overview),
                    ),
                  ),
                  if (currentPoster.type == SeerrMediaType.tvshow &&
                      (currentPoster.seasons?.isNotEmpty ?? false))
                    SliverPadding(
                      padding: padding.copyWith(top: AppSpacing.xl),
                      sliver: SliverToBoxAdapter(
                        child: _SeerrSeasonsSection(
                          state: state,
                          notifier: notifier,
                          seasons: currentPoster.seasons ?? const [],
                          seasonStatuses: state.seasonStatuses,
                        ),
                      ),
                    ),
                  if (state.people.isNotEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.only(top: AppSpacing.xl),
                      sliver: SliverToBoxAdapter(
                        child: PeopleRow(
                          people: state.people,
                          contentPadding: padding,
                          onTap: () {},
                        ),
                      ),
                    ),
                  if (state.recommended.isNotEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.only(top: AppSpacing.xl),
                      sliver: SliverToBoxAdapter(
                        child: SeerrPosterRow(
                          posters: state.recommended,
                          label:
                              "${context.localized.discover} ${context.localized.recommended.toLowerCase()}",
                          contentPadding: padding,
                        ),
                      ),
                    ),
                  if (state.similar.isNotEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.only(top: AppSpacing.xl),
                      sliver: SliverToBoxAdapter(
                        child: SeerrPosterRow(
                          posters: state.similar,
                          label:
                              "${context.localized.discover} ${context.localized.related.toLowerCase()}",
                          contentPadding: padding,
                        ),
                      ),
                    ),
                  if (externalUrls.isNotEmpty)
                    SliverPadding(
                      padding: padding.copyWith(
                          top: AppSpacing.xl, bottom: AppSpacing.xl),
                      sliver: SliverToBoxAdapter(
                        child: ExternalUrlsRow(urls: externalUrls),
                      ),
                    ),
                ],
        ));
  }
}

/// Statut de disponibilité/téléchargement (badge fonctionnel — état, pas
/// une métadonnée cosmétique, laissé tel quel, cf. [DownloadStatusLabel])
/// puis scores Rotten Tomatoes en texte discret : jamais de pilule
/// colorée, juste le libellé et le pourcentage.
class _SeerrStatusLine extends StatelessWidget {
  final SeerrDashboardPosterModel poster;
  final bool hasKnownStatus;
  final int? criticsScore;
  final int? audienceScore;

  const _SeerrStatusLine({
    required this.poster,
    required this.hasKnownStatus,
    required this.criticsScore,
    required this.audienceScore,
  });

  @override
  Widget build(BuildContext context) {
    final rtParts = <String>[
      if (criticsScore != null) '$criticsScore % critiques',
      if (audienceScore != null) '$audienceScore % public',
    ];

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xxs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (hasKnownStatus) DownloadStatusLabel(poster: poster),
        if (rtParts.isNotEmpty)
          Text(
            'Rotten Tomatoes : ${rtParts.join(' · ')}',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
      ],
    );
  }
}

class _SeerrSeasonsSection extends StatelessWidget {
  final SeerrDetailsModel state;
  final SeerrDetails notifier;
  final List<SeerrSeason> seasons;
  final Map<int, SeerrMediaStatus> seasonStatuses;

  const _SeerrSeasonsSection({
    required this.state,
    required this.notifier,
    required this.seasons,
    required this.seasonStatuses,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        Text(
          context.localized.season(seasons.length),
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        ...seasons.map((season) {
          final seasonNumber = season.seasonNumber;
          if (seasonNumber == null) return const SizedBox.shrink();
          final status = seasonStatuses[seasonNumber];
          final isExpanded = state.expandedSeasons[seasonNumber] ?? false;
          final episodes = state.episodesCache[seasonNumber] ?? [];

          return _SeasonCard(
            season: season,
            seasonNumber: seasonNumber,
            status: status,
            isExpanded: isExpanded,
            episodes: episodes,
            onToggle: () => notifier.toggleSeasonExpanded(seasonNumber),
            poster: state.poster,
          );
        }),
      ],
    );
  }
}

class _SeasonCard extends StatelessWidget {
  final SeerrSeason season;
  final int seasonNumber;
  final SeerrMediaStatus? status;
  final bool isExpanded;
  final List<SeerrEpisode> episodes;
  final VoidCallback onToggle;
  final SeerrDashboardPosterModel? poster;

  const _SeasonCard({
    required this.season,
    required this.seasonNumber,
    required this.status,
    required this.isExpanded,
    required this.episodes,
    required this.onToggle,
    this.poster,
  });

  @override
  Widget build(BuildContext context) {
    final standardDownloads = poster?.mediaInfo?.downloadStatus
            ?.where((d) => d.episode?.seasonNumber == seasonNumber)
            .toList() ??
        [];
    final fourKDownloads = poster?.mediaInfo?.downloadStatus4k
            ?.where((d) => d.episode?.seasonNumber == seasonNumber)
            .toList() ??
        [];
    final seasonDownloads = <SeerrDownloadStatus>[
      ...standardDownloads,
      ...fourKDownloads
    ];

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: KinosTheme.smallShape.borderRadius,
      ),
      child: Column(
        children: [
          FocusButton(
            onTap: onToggle,
            onFocusChanged: (focus) {
              if (focus) {
                context.ensureVisible();
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (status != null &&
                            status != SeerrMediaStatus.unknown)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: status!.color.withAlpha(200),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                status!.label(context),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                          ),
                        Text(
                          "${context.localized.season(1)} $seasonNumber",
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        if (season.episodeCount != null)
                          Text(
                            '${season.episodeCount} ${context.localized.episode(season.episodeCount ?? 0)}',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant
                                      .withValues(alpha: 0.7),
                                ),
                          ),
                        if (seasonDownloads.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          SeasonDownloadProgressWidget(
                              downloads: seasonDownloads),
                        ],
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      IconsaxPlusLinear.arrow_down,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: isExpanded
                ? Column(
                    children: episodes.map((episode) {
                      return _EpisodeCard(episode: episode);
                    }).toList(),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _EpisodeCard extends StatelessWidget {
  final SeerrEpisode episode;

  const _EpisodeCard({required this.episode});

  @override
  Widget build(BuildContext context) {
    final posterUrl = episode.stillUrl;
    final posterImage = posterUrl == null
        ? null
        : ImageData(
            path: posterUrl,
            key: 'seerr_episode_${episode.id ?? episode.episodeNumber}');

    return FocusButton(
      onTap: AdaptiveLayout.inputDeviceOf(context) == InputDevice.dPad
          ? () {}
          : null,
      onFocusChanged: (focus) {
        if (focus) {
          context.ensureVisible();
        }
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.surfaceContainer,
              width: 1,
            ),
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 4,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'E${episode.episodeNumber}',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimaryContainer,
                                  ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          episode.name ?? 'Episode ${episode.episodeNumber}',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (episode.overview != null && episode.overview!.isNotEmpty)
                    Text(
                      episode.overview!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant
                                .withValues(alpha: 0.8),
                          ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (episode.airDate != null && episode.airDate!.isNotEmpty)
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      child: Text(
                        episode.airDate!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ),
                ],
              ),
            ),
            if (posterImage != null)
              Container(
                decoration: BoxDecoration(
                  borderRadius: KinosTheme.defaultPosterDecoration.borderRadius,
                ),
                foregroundDecoration: KinosTheme.defaultPosterDecoration,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: 175,
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: KinosImage(
                      image: posterImage,
                      fit: BoxFit.cover,
                      placeHolder: Container(
                        color: Theme.of(context).colorScheme.surfaceContainer,
                        child: Center(
                          child: Icon(
                            IconsaxPlusLinear.video,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
