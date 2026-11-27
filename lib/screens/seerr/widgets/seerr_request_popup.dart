import 'package:flutter/material.dart';

import 'package:auto_route/auto_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import 'package:kinos/models/items/images_models.dart';
import 'package:kinos/models/seerr/seerr_dashboard_model.dart';
import 'package:kinos/providers/seerr/seerr_request_provider.dart';
import 'package:kinos/providers/user_provider.dart';
import 'package:kinos/screens/details_screens/components/media_meta_line.dart';
import 'package:kinos/screens/seerr/widgets/request_popup_widgets.dart';
import 'package:kinos/screens/seerr/widgets/seerr_config_selector.dart';
import 'package:kinos/screens/seerr/widgets/seerr_user_label.dart';
import 'package:kinos/screens/shared/adaptive_dialog.dart';
import 'package:kinos/screens/shared/kinos_notification_overlay.dart';
import 'package:kinos/screens/shared/media/external_urls.dart';
import 'package:kinos/seerr/seerr_models.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/kinos_image.dart';
import 'package:kinos/util/localization_helper.dart';
import 'package:kinos/util/refresh_state.dart';
import 'package:kinos/widgets/shared/item_actions.dart';
import 'package:kinos/widgets/shared/pull_to_refresh.dart';

Future<void> openSeerrRequestPopup(
  BuildContext context,
  SeerrDashboardPosterModel poster,
) async {
  await showDialogAdaptive(
    context: context,
    backgroundColor: AppColors.surfaceHigh,
    shape: const RoundedRectangleBorder(borderRadius: AppRadii.sheetBorder),
    builder: (context) => SeerrRequestPopup(requestModel: poster),
  );
  await context.refreshData();
}

/// La demande d'un titre à Seerr, en « fenêtre cinéma » : l'affiche, le
/// titre, les saisons en vignettes à cocher, les réglages en pastilles
/// (qualité, langue, dossier…), et une action qui dit ce qu'elle demande.
/// Entrée demande (le bouton a le focus), Échap ferme.
class SeerrRequestPopup extends ConsumerStatefulWidget {
  final SeerrDashboardPosterModel requestModel;
  const SeerrRequestPopup({required this.requestModel, super.key});

  @override
  ConsumerState<SeerrRequestPopup> createState() => _SeerrRequestPopupState();
}

class _SeerrRequestPopupState extends ConsumerState<SeerrRequestPopup> {
  bool _sending = false;

  void _openInSeerr(SeerrDashboardPosterModel model) {
    final seerrUrl = ref.read(userProvider)?.seerrCredentials?.serverUrl;
    if (seerrUrl == null || seerrUrl.isEmpty) return;
    final type = model.type == SeerrMediaType.movie ? 'movie' : 'tv';
    launchUrl(context, '$seerrUrl/$type/${model.tmdbId}');
  }

  Future<void> _submit(SeerrDashboardPosterModel model) async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      await KinosSnack.showResponse(
        ref.read(seerrRequestProvider.notifier).submitRequest(),
        successTitle: context.localized.requestedSuccessForItem(model.title),
      );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// « Demander », « Demander la saison 2 », « Demander 3 saisons » ; et
  /// quand il n'y a rien à demander, pourquoi.
  String _actionLabel(SeerrRequestModel state, List<SeerrSeason> seasons,
      SeerrDashboardPosterModel model) {
    final available = model.mediaStatus == SeerrMediaStatus.available;
    if (!state.isTv) {
      if (available) return 'Déjà disponible';
      if (!state.canSubmitRequest && state.hasExistingRequest) {
        return 'Déjà demandé';
      }
      return 'Demander';
    }
    final open =
        seasons.where((s) => !state.isRequestedAlready(s.seasonNumber!));
    if (seasons.isNotEmpty && open.isEmpty) {
      return seasons.every((s) =>
              state.seasonStatuses[s.seasonNumber] ==
              SeerrMediaStatus.available)
          ? 'Déjà disponible'
          : 'Déjà demandée';
    }
    final chosen = state.selectedSeasonNumbers ?? const <int>[];
    if (chosen.length == 1) return 'Demander la saison ${chosen.single}';
    if (chosen.isEmpty) return 'Choisissez une saison';
    return 'Demander ${chosen.length} saisons';
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(seerrRequestProvider.notifier);
    final state = ref.watch(seerrRequestProvider);
    final model = state.poster ?? widget.requestModel;
    final seasons = (state.poster?.seasons ?? const <SeerrSeason>[])
        .where((s) => s.seasonNumber != null && s.seasonNumber! > 0)
        .toList();
    final text = Theme.of(context).textTheme;
    final metaLine = buildMediaMetaLine(
      officialRating: state.contentRating,
      year: DateTime.tryParse(state.releaseDate ?? '')?.year,
      communityRating: state.voteAverage,
      genres: state.genres.map((genre) => genre.name).nonNulls.toList(),
    );

    return PullToRefresh(
      onRefresh: () => notifier.initialize(widget.requestModel),
      // La fenêtre grandit en douceur quand saisons et réglages arrivent.
      child: (context) => AnimatedSize(
        duration:
            AppMotion.enabled(context) ? AppDurations.unroll : Duration.zero,
        curve: AppMotion.easeOut,
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSeerrRequest.maxWidth),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Flexible(
                  child: SingleChildScrollView(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Poster(
                            model: model, onOpen: () => _openInSeerr(model)),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _Overline(model: model, state: state),
                              const SizedBox(height: AppSpacing.xxs),
                              Text(model.title,
                                  style: AppTypography.displaySmall),
                              if (metaLine.isNotEmpty) ...[
                                const SizedBox(height: AppSpacing.xxs),
                                Text(metaLine,
                                    style: text.bodySmall?.copyWith(
                                        color: AppColors.textSecondary)),
                              ],
                              if (model.overview.trim().isNotEmpty) ...[
                                const SizedBox(height: AppSpacing.sm),
                                Text(model.overview,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: text.bodyMedium?.copyWith(
                                        color: AppColors.textSecondary)),
                              ],
                              if (state.isTv && seasons.isNotEmpty) ...[
                                const SizedBox(height: AppSpacing.lg),
                                _Seasons(
                                    model: model,
                                    state: state,
                                    seasons: seasons),
                              ],
                              if (state.currentUser?.canManageRequests ==
                                  true) ...[
                                const SizedBox(height: AppSpacing.lg),
                                _Options(state: state),
                              ],
                              if (state.activeQuota?.hasRestrictions ==
                                  true) ...[
                                const SizedBox(height: AppSpacing.md),
                                QuotaLimitCard(
                                    quota: state.activeQuota!,
                                    type: model.type),
                              ],
                              if (state.hasRequestPermission == false) ...[
                                const SizedBox(height: AppSpacing.md),
                                const PermissionDeniedWarning(),
                              ],
                              if (state.isAnime) ...[
                                const SizedBox(height: AppSpacing.sm),
                                Text(context.localized.seerrAnimeSeriesNote,
                                    style: text.bodySmall?.copyWith(
                                        color: AppColors.textSecondary)),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(child: _AutoApprove(state: state)),
                    TextButton(
                      onPressed: () => context.pop(),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const _KeyCap('Échap'),
                        const SizedBox(width: AppSpacing.xs),
                        Text(context.localized.close),
                      ]),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    FilledButton(
                      autofocus: true,
                      // Désactivé, il doit le paraître : rien à demander.
                      style: FilledButton.styleFrom(
                        disabledBackgroundColor: AppColors.surface,
                        disabledForegroundColor: AppColors.textDisabled,
                      ),
                      onPressed: state.canSubmitRequest && !_sending
                          ? () => _submit(model)
                          : null,
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        if (_sending)
                          const SizedBox.square(
                              dimension: AppSpacing.md,
                              child: CircularProgressIndicator(strokeWidth: 2))
                        else
                          const Icon(IconsaxPlusBold.send_2,
                              size: AppSpacing.md),
                        const SizedBox(width: AppSpacing.xs),
                        Text(_actionLabel(state, seasons, model)),
                      ]),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Poster extends StatelessWidget {
  const _Poster({required this.model, required this.onOpen});
  final SeerrDashboardPosterModel model;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => FocusRing(
        borderRadius: AppRadii.cardBorder,
        onActivate: onOpen,
        child: Tooltip(
          message: 'Ouvrir dans Seerr',
          child: InkWell(
            onTap: onOpen,
            borderRadius: AppRadii.cardBorder,
            child: ClipRRect(
              borderRadius: AppRadii.cardBorder,
              child: SizedBox(
                width: AppSeerrRequest.posterWidth,
                child: AspectRatio(
                  aspectRatio: AppMedia.posterAspectRatio,
                  child: KinosImage(
                    image: model.images.primary,
                    placeHolder: ColoredBox(
                      color: AppColors.surface,
                      child: Icon(
                          model.type == SeerrMediaType.movie
                              ? Icons.movie_outlined
                              : Icons.tv_outlined,
                          color: AppColors.textDisabled),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

/// « 2026 · SÉRIE · DISPONIBLE » : le statut en texte, dans sa couleur.
class _Overline extends StatelessWidget {
  const _Overline({required this.model, required this.state});
  final SeerrDashboardPosterModel model;
  final SeerrRequestModel state;

  @override
  Widget build(BuildContext context) {
    final year = DateTime.tryParse(state.releaseDate ?? '')?.year;
    final style =
        AppTypography.overline.copyWith(color: AppColors.textSecondary);
    return Text.rich(TextSpan(style: style, children: [
      TextSpan(
          text: [
        if (year != null) '$year',
        model.type == SeerrMediaType.movie ? 'FILM' : 'SÉRIE',
      ].join(' · ')),
      if (model.hasDisplayStatus) ...[
        const TextSpan(text: ' · '),
        TextSpan(
            text: model.displayStatusLabel(context).toUpperCase(),
            style: style.copyWith(color: model.displayStatusColor)),
      ],
    ]));
  }
}

/// Les saisons en vignettes : cliquer coche ou décoche. Celles déjà
/// disponibles ou demandées sont estompées, avec leur statut.
class _Seasons extends ConsumerWidget {
  const _Seasons(
      {required this.model, required this.state, required this.seasons});
  final SeerrDashboardPosterModel model;
  final SeerrRequestModel state;
  final List<SeerrSeason> seasons;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(seerrRequestProvider.notifier);
    final open =
        seasons.where((s) => !state.isRequestedAlready(s.seasonNumber!)).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text(context.localized.season(seasons.length).toUpperCase(),
              style: AppTypography.overline
                  .copyWith(color: AppColors.textSecondary)),
          const Spacer(),
          if (open > 1)
            TextButton(
                onPressed: notifier.selectAllSeasons,
                child: Text(context.localized.requestAll)),
        ]),
        const SizedBox(height: AppSpacing.xs),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final season in seasons) ...[
                _SeasonTile(
                  model: model,
                  season: season,
                  status: state.seasonStatuses[season.seasonNumber],
                  locked: state.isRequestedAlready(season.seasonNumber!),
                  selected: state.selectedSeasons[season.seasonNumber] ?? false,
                  onToggle: (value) =>
                      notifier.toggleSeason(season.seasonNumber!, value),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SeasonTile extends StatelessWidget {
  const _SeasonTile({
    required this.model,
    required this.season,
    required this.status,
    required this.locked,
    required this.selected,
    required this.onToggle,
  });
  final SeerrDashboardPosterModel model;
  final SeerrSeason season;
  final SeerrMediaStatus? status;
  final bool locked, selected;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final number = season.seasonNumber!;
    final known = status != null && status != SeerrMediaStatus.unknown;
    final poster = season.posterUrl == null
        ? model.images.primary
        : ImageData(
            path: season.posterUrl!, key: 'id${season.id}_season$number');
    final toggle = locked ? null : () => onToggle(!selected);
    return SizedBox(
      width: AppSeerrRequest.seasonWidth,
      child: FocusRing(
        borderRadius: AppRadii.cardBorder,
        onActivate: toggle,
        child: InkWell(
          onTap: toggle,
          borderRadius: AppRadii.cardBorder,
          child: Opacity(
            opacity: locked ? AppSeerrRequest.lockedOpacity : 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: AppDurations.hover,
                  decoration: BoxDecoration(
                    borderRadius: AppRadii.cardBorder,
                    border: Border.all(
                        width: AppSeerrRequest.selectedOutline,
                        color: selected && !locked
                            ? AppColors.textPrimary
                            : AppColors.border),
                  ),
                  child: ClipRRect(
                    borderRadius: AppRadii.cardBorder,
                    child: AspectRatio(
                      aspectRatio: AppMedia.posterAspectRatio,
                      child: Stack(fit: StackFit.expand, children: [
                        KinosImage(image: poster, fit: BoxFit.cover),
                        if (selected && !locked)
                          const Align(
                            alignment: Alignment.topRight,
                            child: Padding(
                              padding: EdgeInsets.all(AppSpacing.xxs),
                              child: Icon(Icons.check_circle,
                                  size: AppSpacing.lg,
                                  color: AppColors.textPrimary),
                            ),
                          ),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text('${context.localized.season(1)} $number',
                    style: text.bodyMedium),
                Text(
                  known
                      ? status!.label(context)
                      : season.episodeCount == null
                          ? ''
                          : '${season.episodeCount} ${context.localized.episode(season.episodeCount!).toLowerCase()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(
                      color: known ? status!.color : AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Les réglages en pastilles, avec leurs valeurs par défaut : on ne les
/// ouvre que pour les changer.
class _Options extends ConsumerWidget {
  const _Options({required this.state});
  final SeerrRequestModel state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(seerrRequestProvider.notifier);
    final languages = ref.watch(seerrLanguageProfilesProvider);
    final language = ref.watch(seerrSelectedLanguageProfileProvider);
    final l = context.localized;
    String folderLabel(String folder) =>
        folder.split('/').where((p) => p.isNotEmpty).lastOrNull ?? folder;
    final user = state.selectedUser ?? state.currentUser;
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        if (state.availableServers.length > 1)
          SeerrOptionPill(
            label: l.server,
            value: state.serverLabel(state.activeServer),
            itemBuilder: (_) => [
              for (final server in state.availableServers)
                ItemActionButton(
                  label: Text(state.serverLabel(server)),
                  selected: server == state.activeServer,
                  action: () => notifier.selectServer(server),
                ),
            ],
          ),
        if (state.availableProfiles.isNotEmpty)
          SeerrOptionPill(
            label: 'Qualité',
            value: state.selectedProfile?.name ?? l.selectProfile,
            itemBuilder: (_) => [
              for (final profile in state.availableProfiles)
                ItemActionButton(
                  label: Text(profile.name ?? l.unknown),
                  selected: profile.id == state.selectedProfile?.id,
                  action: () => notifier.selectProfile(profile),
                ),
            ],
          ),
        if (state.isTv && languages.isNotEmpty)
          SeerrOptionPill(
            label: 'Langue',
            value: language?.name ?? l.unknown,
            itemBuilder: (_) => [
              for (final profile in languages)
                ItemActionButton(
                  label: Text(profile.name ?? l.unknown),
                  selected: profile.id == language?.id,
                  action: () => notifier.selectLanguageProfile(profile),
                ),
            ],
          ),
        if (state.availableRootFolders.isNotEmpty)
          SeerrOptionPill(
            label: 'Dossier',
            value: state.selectedRootFolder == null
                ? l.selectFolder
                : folderLabel(state.selectedRootFolder!),
            itemBuilder: (_) => [
              for (final folder in state.availableRootFolders)
                ItemActionButton(
                  label: Text(folder == state.defaultRootFolder
                      ? l.rootFolderDefaultLabel(folder)
                      : folder),
                  selected: folder == state.selectedRootFolder,
                  action: () => notifier.selectRootFolder(folder),
                ),
            ],
          ),
        if (state.availableTags.isNotEmpty)
          SeerrOptionPill(
            label: l.tags,
            value: state.selectedTags.isEmpty
                ? l.noTags
                : state.selectedTags.map((t) => t.label).join(', '),
            itemBuilder: (_) => [
              ItemActionButton(
                label: Text(l.noTags),
                action: () => notifier.selectTags([]),
              ),
              for (final tag in state.availableTags)
                ItemActionButton(
                  label: Text(tag.label ?? l.unknown),
                  selected: state.selectedTags.any((t) => t.id == tag.id),
                  action: () {
                    final current =
                        List<SeerrServiceTag>.from(state.selectedTags);
                    if (!current.any((t) => t.id == tag.id)) {
                      current.add(tag);
                    } else {
                      current.removeWhere((t) => t.id == tag.id);
                    }
                    notifier.selectTags(current);
                  },
                ),
            ],
          ),
        if (state.currentUser?.canManageUsers == true)
          SeerrOptionPill(
            label: 'Pour',
            value: user?.label ?? l.unknown,
            valueWidget: SeerrUserLabel(user: user),
            itemBuilder: (_) {
              final base = state.currentUser!;
              return [
                ItemActionButton(
                  label: SeerrUserLabel(user: base),
                  action: () => notifier.selectUser(base),
                ),
                for (final other
                    in state.availableUsers.where((u) => u.id != base.id))
                  ItemActionButton(
                    label: SeerrUserLabel(user: other),
                    action: () => notifier.selectUser(other),
                  ),
              ];
            },
          ),
      ],
    );
  }
}

/// « Approuvée automatiquement » : une ligne discrète au pied de la
/// fenêtre, plus un bandeau.
class _AutoApprove extends StatelessWidget {
  const _AutoApprove({required this.state});
  final SeerrRequestModel state;

  @override
  Widget build(BuildContext context) {
    final user = state.currentUser;
    final auto = (user?.hasPermission(SeerrPermission.autoApprove) ?? false) ||
        (user?.hasPermission(state.isTv
                ? SeerrPermission.autoApproveTv
                : SeerrPermission.autoApproveMovie) ??
            false);
    if (!auto) return const SizedBox.shrink();
    return Row(children: [
      const Icon(IconsaxPlusLinear.tick_circle,
          size: AppSpacing.md, color: AppColors.textSecondary),
      const SizedBox(width: AppSpacing.xs),
      Flexible(
        child: Text(context.localized.seerrAutoApproveNotice,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textSecondary)),
      ),
    ]);
  }
}

class _KeyCap extends StatelessWidget {
  const _KeyCap(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: AppRadii.controlBorder,
          border: Border.all(color: AppColors.borderStrong),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs, vertical: AppSpacing.xxs / 2),
          child: Text(label,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: AppColors.textSecondary)),
        ),
      );
}
