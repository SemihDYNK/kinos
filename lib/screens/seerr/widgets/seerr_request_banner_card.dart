import 'package:flutter/services.dart';
import 'package:kinos/screens/shared/media_navigation.dart';
import 'package:kinos/widgets/shared/frosted_surface.dart';
import 'package:flutter/material.dart';

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import 'package:kinos/models/items/images_models.dart';
import 'package:kinos/models/seerr/seerr_dashboard_model.dart';
import 'package:kinos/providers/seerr_user_provider.dart';
import 'package:kinos/routes/auto_router.gr.dart';
import 'package:kinos/screens/seerr/widgets/download_status_label.dart';
import 'package:kinos/screens/seerr/widgets/seerr_request_popup.dart';
import 'package:kinos/screens/seerr/widgets/seerr_user_label.dart';
import 'package:kinos/seerr/seerr_models.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/kinos_image.dart';
import 'package:kinos/util/focus_provider.dart';
import 'package:kinos/util/localization_helper.dart';
import 'package:kinos/widgets/shared/item_actions.dart';
import 'package:kinos/widgets/shared/modal_bottom_sheet.dart';

class SeerrRequestBannerCard extends ConsumerWidget {
  final SeerrDashboardPosterModel poster;
  final bool compact;
  final void Function(SeerrDashboardPosterModel poster)? onTap;

  const SeerrRequestBannerCard({
    required this.poster,
    this.compact = false,
    this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) => MediaNavigation(
        previewImage:
            poster.images.primary ?? poster.images.backDrop?.firstOrNull,
        builder: (context) => _buildCard(context, ref),
      );

  Widget _buildCard(BuildContext context, WidgetRef ref) {
    final radius = AppRadii.controlBorder;

    ImageData? posterImage = poster.images.primary;
    posterImage ??= poster.images.backDrop?.lastOrNull;

    final user = ref.watch(seerrUserProvider);
    final canRequest =
        user?.canRequestMedia(isTv: poster.type == SeerrMediaType.tvshow) ??
            true;
    final baseItemModel = poster.itemBaseModel;

    void openRequestDetails() {
      pushMediaRoute(
        context,
        SeerrDetailsRoute(
          tag: MediaNavigationScope.tagOf(context),
          mediaType: poster.type == SeerrMediaType.tvshow ? 'tvshow' : 'movie',
          tmdbId: poster.tmdbId,
          poster: poster,
        ),
      );
    }

    void handleTapAction() {
      if (compact) {
        openRequestDetails();
      } else if (baseItemModel != null) {
        openMediaDetails(context, baseItemModel);
      } else {
        openRequestDetails();
      }
    }

    final List<ItemAction> itemActions = [
      if (poster.hasDisplayStatus || poster.id.isNotEmpty)
        ItemActionButton(
          icon: const Icon(IconsaxPlusBold.folder_open),
          label: Text(context.localized.manageRequest),
          action: () => openRequestDetails(),
        ),
      if (canRequest)
        ItemActionButton(
          icon: const Icon(IconsaxPlusBold.add),
          label: Text(context.localized.request),
          action: () => openSeerrRequestPopup(context, poster),
        ),
      if (baseItemModel != null)
        ItemActionButton(
          icon: Icon(baseItemModel.type.icon),
          label: Text(context.localized.showDetails),
          action: () => openMediaDetails(context, baseItemModel),
        ),
    ];

    final requestedByUser = poster.requestedBy is SeerrUserModel
        ? poster.requestedBy as SeerrUserModel
        : null;
    final seasonsList = poster.requestedSeasons ?? [];

    if (compact) {
      void menu() {
        final box = context.findRenderObject() as RenderBox;
        _showContextMenu(
            context, itemActions, ref, box.localToGlobal(Offset.zero));
      }

      final thumbnail = SizedBox(
          width: AppManagementLayout.requestPosterWidth,
          child: AspectRatio(
              aspectRatio: AppMedia.posterAspectRatio,
              child: ClipRRect(
                  borderRadius: AppRadii.cardBorder,
                  child: MediaArtwork(
                      child:
                          KinosImage(image: posterImage, disableBlur: true)))));
      final title = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(poster.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.cardTitle),
            const SizedBox(height: AppSpacing.xxs),
            Text(
                [
                  if (poster.releaseYear?.isNotEmpty == true)
                    poster.releaseYear!,
                  if (seasonsList.isNotEmpty)
                    '${context.localized.season(seasonsList.length)} : ${seasonsList.join(', ')}',
                ].join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.meta),
          ]);
      final status = DownloadStatusLabel(
          poster: poster,
          filterSeasons: seasonsList.isEmpty ? null : seasonsList);
      final requester = requestedByUser == null
          ? Text(context.localized.unknown, style: AppTypography.meta)
          : SeerrUserLabel(user: requestedByUser);
      return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.f10, shift: true): menu,
            const SingleActivator(LogicalKeyboardKey.contextMenu): menu,
          },
          child: GestureDetector(
            onSecondaryTapDown: (event) => _showContextMenu(
                context, itemActions, ref, event.globalPosition),
            child: FocusRing(
              onActivate:
                  onTap == null ? handleTapAction : () => onTap!(poster),
              focusNode: MediaNavigationScope.focusOf(context),
              borderRadius: AppRadii.controlBorder,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs, vertical: AppSpacing.xs),
                child: LayoutBuilder(
                    builder: (context, constraints) => Row(children: [
                          thumbnail,
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                              child: constraints.maxWidth >=
                                      AppManagementLayout.requestWideWidth
                                  ? title
                                  : Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                          title,
                                          const SizedBox(height: AppSpacing.xs),
                                          status
                                        ])),
                          const SizedBox(width: AppSpacing.md),
                          if (constraints.maxWidth >=
                              AppManagementLayout.requestWideWidth) ...[
                            SizedBox(
                                width: AppManagementLayout.requesterWidth,
                                child: requester),
                            SizedBox(
                                width: AppManagementLayout.requestStatusWidth,
                                child: status),
                          ],
                          FocusRing(
                              onActivate: menu,
                              borderRadius: AppRadii.controlBorder,
                              child: ExcludeFocus(
                                  child: IconButton(
                                      tooltip:
                                          '${context.localized.moreOptions} · Maj+F10',
                                      onPressed: menu,
                                      icon: const Icon(Icons.more_horiz,
                                          color: AppColors.textSecondary)))),
                        ])),
              ),
            ),
          ));
    }

    return FocusButton(
      borderRadius: radius,
      darkOverlay: false,
      onTap: onTap != null ? () => onTap?.call(poster) : handleTapAction,
      onLongPress: () => _showBottomSheet(context, itemActions, ref),
      onSecondaryTapDown: (tap) =>
          _showContextMenu(context, itemActions, ref, tap.globalPosition),
      child: DecoratedBox(
          decoration:
              BoxDecoration(color: AppColors.surface, borderRadius: radius),
          child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Row(children: [
                SizedBox(
                    width: AppPageLayout.requestPosterWidth,
                    child: AspectRatio(
                        aspectRatio: AppMedia.posterAspectRatio,
                        child: ClipRRect(
                            borderRadius: AppRadii.cardBorder,
                            child: KinosImage(
                                image: posterImage, disableBlur: true)))),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(poster.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.cardTitle),
                      if (poster.releaseYear?.isNotEmpty == true)
                        Text(poster.releaseYear!, style: AppTypography.meta),
                      if (poster.type == SeerrMediaType.tvshow &&
                          seasonsList.isNotEmpty)
                        Text(
                            '${context.localized.season(seasonsList.length)}: ${seasonsList.join(', ')}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.meta),
                      const SizedBox(height: AppSpacing.xs),
                      Wrap(
                          spacing: AppSpacing.lg,
                          runSpacing: AppSpacing.xs,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (requestedByUser != null)
                              SeerrUserLabel(user: requestedByUser),
                            if (poster.hasDisplayStatus)
                              DownloadStatusLabel(
                                  poster: poster,
                                  filterSeasons:
                                      poster.type == SeerrMediaType.tvshow &&
                                              seasonsList.isNotEmpty
                                          ? seasonsList
                                          : null),
                          ]),
                    ])),
                const SizedBox(width: AppSpacing.sm),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textSecondary),
              ]))),
    );
  }

  void _showBottomSheet(
      BuildContext context, List<ItemAction> itemActions, WidgetRef ref) {
    showBottomSheetPill(
      context: context,
      content: (scrollContext, scrollController) => ListView(
        shrinkWrap: true,
        controller: scrollController,
        children: itemActions.listTileItems(scrollContext, useIcons: true),
      ),
    );
  }

  Future<void> _showContextMenu(BuildContext context,
      List<ItemAction> itemActions, WidgetRef ref, Offset globalPos) async {
    final position = RelativeRect.fromLTRB(
        globalPos.dx, globalPos.dy, globalPos.dx, globalPos.dy);
    await showGlassMenu(
      context: context,
      position: position,
      items: itemActions.popupMenuItems(
        useIcons: true,
      ),
    );
  }
}
