import 'package:flutter/services.dart';
import 'package:kinos/theme/app_icons.dart';
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
import 'package:kinos/screens/seerr/widgets/seerr_request_popup.dart';
import 'package:kinos/seerr/seerr_models.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/adaptive_layout/adaptive_layout.dart';
import 'package:kinos/util/kinos_image.dart';
import 'package:kinos/util/focus_provider.dart';
import 'package:kinos/util/localization_helper.dart';
import 'package:kinos/widgets/shared/clickable_text.dart';
import 'package:kinos/widgets/shared/item_actions.dart';
import 'package:kinos/widgets/shared/modal_bottom_sheet.dart';

class SeerrPosterCard extends ConsumerWidget {
  final SeerrDashboardPosterModel poster;
  final double? aspectRatio;
  final bool showStatus;
  final double? imageAspectRatio;
  final Function(bool value)? onFocusChanged;

  const SeerrPosterCard({
    required this.poster,
    this.showStatus = false,
    this.aspectRatio,
    this.imageAspectRatio,
    this.onFocusChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) => MediaNavigation(
      previewImage: poster.images.primary ?? poster.images.backDrop?.lastOrNull,
      builder: (context) => _buildCard(context, ref));

  Widget _buildCard(BuildContext context, WidgetRef ref) {
    final radius = AppRadii.cardBorder;

    ImageData? image = poster.images.primary;
    image ??= poster.images.backDrop?.lastOrNull;

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
      if (baseItemModel != null) {
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
          action: openRequestDetails,
        ),
      if (!poster.hasDisplayStatus && canRequest)
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

    final posterImage = FocusButton(
      posterMotion: true,
      focusableOverlays: true,
      focusNode: MediaNavigationScope.focusOf(context),
      onTap: handleTapAction,
      onFocusChanged: onFocusChanged,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: radius,
          color: Theme.of(context).colorScheme.surfaceContainer,
        ),
        foregroundDecoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(width: 1, color: Colors.white.withAlpha(45)),
        ),
        clipBehavior: Clip.hardEdge,
        child: MediaArtwork(
            child: KinosImage(
          image: image,
          placeHolder: _SeerrPosterFallback(poster: poster),
        )),
      ),
      onSecondaryTapDown: (details) =>
          _showContextMenu(context, itemActions, ref, details.globalPosition),
      onLongPress: () => _showBottomSheet(context, itemActions, ref),
      focusedOverlays: [
        // Sobre au survol : cadre fin sur voile sombre, jamais une
        // pastille pleine colorée (règle du projet, cf. FilterButton).
        if (!poster.hasDisplayStatus &&
            canRequest &&
            AdaptiveLayout.inputDeviceOf(context) == InputDevice.pointer)
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xs),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.scrim.withValues(alpha: 0.55),
                  borderRadius: AppRadii.controlBorder,
                  border: Border.all(
                      color: AppColors.textPrimary.withValues(alpha: 0.4)),
                ),
                child: InkWell(
                  borderRadius: AppRadii.controlBorder,
                  onTap: () => openSeerrRequestPopup(context, poster),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(IconsaxPlusLinear.add_square,
                            color: AppColors.textPrimary, size: 18),
                        const SizedBox(width: AppSpacing.xxs),
                        Text(
                          context.localized.request,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
      overlays: [
        if (poster.hasDisplayStatus && !showStatus)
          Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.all(6.0),
              child: Container(
                decoration: BoxDecoration(
                  color: poster.displayStatusColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(3.0),
                  child: Icon(
                    switch (poster.mediaStatus) {
                      SeerrMediaStatus.available => IconsaxPlusLinear.import_3,
                      _ => Icons.remove_rounded,
                    },
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
        // Discret plutôt que supprimé : une icône seule, sans fond
        // coloré plein — jamais une pastille "Film"/"Série" (règle du
        // projet). Un léger voile derrière l'icône garantit sa
        // lisibilité, quelle que soit la jaquette en dessous.
        Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxs),
            child: Icon(
              poster.type == SeerrMediaType.movie
                  ? AppIcons.films
                  : AppIcons.series,
              size: 16,
              color: AppColors.textPrimary,
              shadows: const [Shadow(color: AppColors.scrim, blurRadius: 4)],
            ),
          ),
        )
      ],
    );
    Widget content = Column(
      mainAxisSize: MainAxisSize.max,
      children: [
        if (imageAspectRatio != null)
          AspectRatio(aspectRatio: imageAspectRatio!, child: posterImage)
        else
          Expanded(child: posterImage),
        ExcludeFocus(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                poster.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: showStatus
                    ? AppTypography.cardTitle
                    : Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
              ),
              ClickableText(
                opacity: 0.65,
                text: showStatus
                    ? (baseItemModel != null
                        ? context.localized.seerrMediaStatusAvailable
                        : poster.hasDisplayStatus
                            ? poster.displayStatusLabel(context)
                            : context.localized.discoveryToRequest)
                    : poster.releaseYear?.toString() ?? "",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: showStatus
                    ? AppTypography.meta
                    : Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (imageAspectRatio == null)
                const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ],
    );

    if (aspectRatio != null) {
      content = AspectRatio(aspectRatio: aspectRatio!, child: content);
    }

    if (showStatus) {
      void menu() {
        final box = context.findRenderObject() as RenderBox;
        _showContextMenu(
            context, itemActions, ref, box.localToGlobal(Offset.zero));
      }

      return CallbackShortcuts(bindings: {
        const SingleActivator(LogicalKeyboardKey.f10, shift: true): menu,
        const SingleActivator(LogicalKeyboardKey.contextMenu): menu,
      }, child: content);
    }
    return content;
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

/// Repli visuel d'une jaquette manquante — jamais un simple rectangle vide
/// avec le titre dessus : une icône de type discrète (mêmes proportions
/// que [PosterPlaceholder], le repli des jaquettes Jellyfin) sur un fond
/// de surface, avec le titre centré en dessous.
class _SeerrPosterFallback extends StatelessWidget {
  final SeerrDashboardPosterModel poster;
  const _SeerrPosterFallback({required this.poster});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surfaceHigh,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              poster.type == SeerrMediaType.movie
                  ? AppIcons.films
                  : AppIcons.series,
              size: 32,
              color: AppColors.textDisabled,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              poster.title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
