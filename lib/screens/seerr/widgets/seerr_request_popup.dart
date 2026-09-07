import 'package:flutter/material.dart';

import 'package:auto_route/auto_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import 'package:fladder/models/seerr/seerr_dashboard_model.dart';
import 'package:fladder/providers/seerr/seerr_request_provider.dart';
import 'package:fladder/providers/user_provider.dart';
import 'package:fladder/screens/details_screens/components/media_meta_line.dart';
import 'package:fladder/screens/seerr/widgets/request_configuration_section.dart';
import 'package:fladder/screens/seerr/widgets/request_popup_widgets.dart';
import 'package:fladder/screens/seerr/widgets/seasons_section.dart';
import 'package:fladder/screens/shared/adaptive_dialog.dart';
import 'package:fladder/screens/shared/fladder_notification_overlay.dart';
import 'package:fladder/screens/shared/media/external_urls.dart';
import 'package:fladder/seerr/seerr_models.dart';
import 'package:fladder/theme/app_theme.dart';
import 'package:fladder/util/adaptive_layout/adaptive_layout.dart';
import 'package:fladder/util/fladder_image.dart';
import 'package:fladder/util/focus_provider.dart';
import 'package:fladder/util/localization_helper.dart';
import 'package:fladder/util/refresh_state.dart';
import 'package:fladder/widgets/shared/filled_button_await.dart';
import 'package:fladder/widgets/shared/pull_to_refresh.dart';

Future<void> openSeerrRequestPopup(
  BuildContext context,
  SeerrDashboardPosterModel poster,
) async {
  await showDialogAdaptive(
    context: context,
    backgroundColor: AppColors.surfaceHigh,
    shape: const RoundedRectangleBorder(borderRadius: AppRadii.sheetBorder),
    builder: (context) => SeerrRequestPopup(
      requestModel: poster,
    ),
  );
  await context.refreshData();
}

class SeerrRequestPopup extends ConsumerStatefulWidget {
  final SeerrDashboardPosterModel requestModel;
  const SeerrRequestPopup({
    required this.requestModel,
    super.key,
  });

  @override
  ConsumerState<SeerrRequestPopup> createState() => _SeerrRequestPopupState();
}

class _SeerrRequestPopupState extends ConsumerState<SeerrRequestPopup> {
  final FocusNode _closeButtonFocusNode = FocusNode();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensureCloseButtonFocus();
  }

  void _ensureCloseButtonFocus() {
    if (AdaptiveLayout.inputDeviceOf(context) != InputDevice.dPad) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _closeButtonFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _closeButtonFocusNode.dispose();
    super.dispose();
  }

  Future<void> openSeerrLink(BuildContext context, SeerrDashboardPosterModel model) async {
    final seerrUrl = ref.read(userProvider)?.seerrCredentials?.serverUrl;
    if (seerrUrl != null && seerrUrl.isNotEmpty) {
      final mediaType = model.type == SeerrMediaType.movie ? 'movie' : 'tv';
      final url = '$seerrUrl/$mediaType/${model.tmdbId}';
      launchUrl(context, url);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(seerrRequestProvider.notifier);
    final requestState = ref.watch(seerrRequestProvider);
    final model = requestState.poster ?? widget.requestModel;
    final seasons = requestState.poster?.seasons ?? const <SeerrSeason>[];
    final seasonStatuses = requestState.seasonStatuses;

    final currentUser = requestState.currentUser;
    final canShowAdvancedConfiguration = currentUser?.canManageRequests ?? false;

    // "PG · 2026 · 6.1 · Family, Fantasy, Comedy, Adventure" — texte simple,
    // jamais de badges colorés (même règle que la fiche détail Seerr).
    final metaLine = buildMediaMetaLine(
      officialRating: requestState.contentRating,
      year: DateTime.tryParse(requestState.releaseDate ?? '')?.year,
      communityRating: requestState.voteAverage,
      genres: requestState.genres.map((genre) => genre.name).nonNulls.toList(),
    );

    return PullToRefresh(
      onRefresh: () => notifier.initialize(widget.requestModel),
      child: (context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
        child: Column(
          spacing: AppSpacing.sm,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  spacing: AppSpacing.sm,
                  children: [
                    AutoApproveBanner(user: currentUser, isTv: requestState.isTv),
                    if (requestState.activeQuota != null && requestState.activeQuota?.hasRestrictions == true)
                      QuotaLimitCard(
                        quota: requestState.activeQuota!,
                        type: model.type,
                      ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: AppSpacing.md,
                      children: [
                        if (model.images.primary != null)
                          FocusButton(
                            onTap: () => openSeerrLink(context, model),
                            borderRadius: AppRadii.cardBorder,
                            child: ClipRRect(
                              borderRadius: AppRadii.cardBorder,
                              child: SizedBox(
                                width: 100,
                                height: 150,
                                child: FladderImage(
                                  image: model.images.primary,
                                  placeHolder: ColoredBox(
                                    color: AppColors.surfaceHigh,
                                    child: Icon(
                                      model.type == SeerrMediaType.movie ? Icons.movie_outlined : Icons.tv_outlined,
                                      color: AppColors.textDisabled,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            spacing: AppSpacing.xxs,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      model.title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineMedium
                                          ?.copyWith(color: AppColors.textPrimary),
                                    ),
                                  ),
                                  // Statut (disponible/en attente...) : un vrai
                                  // indicateur d'état, pas une pastille
                                  // cosmétique — laissé tel quel.
                                  if (model.hasDisplayStatus)
                                    Padding(
                                      padding: const EdgeInsets.only(left: AppSpacing.xs),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
                                        decoration: BoxDecoration(
                                          color: model.displayStatusColor.withAlpha(200),
                                          borderRadius: AppRadii.controlBorder,
                                        ),
                                        child: Text(
                                          model.displayStatusLabel(context),
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              if (metaLine.isNotEmpty)
                                Text(
                                  metaLine,
                                  style:
                                      Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                                ),
                              Padding(
                                padding: const EdgeInsets.only(top: AppSpacing.xxs),
                                child: SelectableText(
                                  model.overview.trim().isEmpty
                                      ? context.localized.noOverviewAvailable
                                      : model.overview,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary),
                                  maxLines: 4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (model.type == SeerrMediaType.tvshow && seasons.isNotEmpty) ...[
                      const Divider(color: AppColors.border),
                      SeerrSeasonsSection(
                        model: model,
                        requestState: requestState,
                        seasons: seasons,
                        seasonStatuses: seasonStatuses,
                      ),
                    ],
                    if (canShowAdvancedConfiguration) ...[
                      const Divider(color: AppColors.border),
                      RequestConfigurationSection(
                        requestState: requestState,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const Divider(color: AppColors.border),
            if (requestState.hasRequestPermission == false) ...[
              const PermissionDeniedWarning(),
            ],
            if (requestState.isAnime) ...[
              Text(
                context.localized.seerrAnimeSeriesNote,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ],
            FilledButtonAwait(
              onPressed: requestState.canSubmitRequest
                  ? () async {
                      await FladderSnack.showResponse(
                        notifier.submitRequest(),
                        successTitle: context.localized.requestedSuccessForItem(model.title),
                      );
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    }
                  : null,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: AppSpacing.xs,
                children: [
                  const Icon(IconsaxPlusBold.send_2),
                  Text(context.localized.submitRequest),
                ],
              ),
            ),
            OutlinedButton(
              autofocus: AdaptiveLayout.inputDeviceOf(context) == InputDevice.dPad,
              focusNode: _closeButtonFocusNode,
              onPressed: () => context.pop(),
              child: Text(context.localized.close),
            )
          ],
        ),
      ),
    );
  }
}
