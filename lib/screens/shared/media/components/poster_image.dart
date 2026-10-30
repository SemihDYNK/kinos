import 'package:kinos/screens/shared/media_navigation.dart';
import 'package:kinos/theme/app_icons.dart';
import 'package:kinos/widgets/shared/frosted_surface.dart';
import 'package:kinos/models/items/images_models.dart';
import 'package:kinos/jellyfin/jellyfin_open_api.enums.swagger.dart' as jelly;
import 'package:flutter/material.dart';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kinos/models/item_base_model.dart';
import 'package:kinos/models/items/item_shared_models.dart';
import 'package:kinos/providers/settings/client_settings_provider.dart';
import 'package:kinos/providers/sync/sync_provider_helpers.dart';
import 'package:kinos/screens/shared/media/components/poster_overlays.dart';
import 'package:kinos/screens/shared/media/components/poster_placeholder.dart';
import 'package:kinos/screens/syncing/sync_button.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/adaptive_layout/adaptive_layout.dart';
import 'package:kinos/util/color_extensions.dart';
import 'package:kinos/util/kinos_image.dart';
import 'package:kinos/util/focus_provider.dart';
import 'package:kinos/util/item_base_model/item_base_model_extensions.dart';
import 'package:kinos/util/localization_helper.dart';
import 'package:kinos/util/refresh_state.dart';
import 'package:kinos/util/string_extensions.dart';
import 'package:kinos/widgets/shared/item_actions.dart';
import 'package:kinos/widgets/shared/modal_bottom_sheet.dart';
import 'package:kinos/widgets/shared/status_card.dart';

class PosterImage extends ConsumerWidget {
  final ItemBaseModel poster;
  final bool? selected;
  final ValueChanged<bool>? playVideo;
  final bool inlineTitle;
  final Set<ItemActions> excludeActions;
  final List<ItemAction> otherActions;
  final Function(UserData? newData)? onUserDataChanged;
  final Function(ItemBaseModel newItem)? onItemUpdated;
  final Function(ItemBaseModel oldItem)? onItemRemoved;
  final Function(Function() action, ItemBaseModel item)? onPressed;
  final List<jelly.ImageType>? imagePriority;
  final Function(bool focus)? onFocusChanged;
  final bool showSyncStatus;

  const PosterImage({
    required this.poster,
    this.selected,
    this.playVideo,
    this.inlineTitle = false,
    this.onItemUpdated,
    this.onItemRemoved,
    this.excludeActions = const {},
    this.otherActions = const [],
    this.onPressed,
    this.onUserDataChanged,
    this.imagePriority,
    this.onFocusChanged,
    this.showSyncStatus = false,
    super.key,
  });

  ImageData? _resolveImage() {
    final source = poster.getPosters;
    final fallback = poster.images;

    final effectivePriority = imagePriority ??
        const [
          jelly.ImageType.primary,
          jelly.ImageType.thumb,
          jelly.ImageType.backdrop
        ];

    for (final type in effectivePriority) {
      final image = switch (type) {
        jelly.ImageType.primary => source?.primary ?? fallback?.primary,
        jelly.ImageType.thumb =>
          source?.thumb ?? fallback?.thumb ?? fallback?.primary,
        jelly.ImageType.backdrop =>
          source?.backDrop?.lastOrNull ?? fallback?.backDrop?.lastOrNull,
        _ => null,
      };

      if (image != null) return image;
    }

    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final radius = AppRadii.cardBorder;
    final padding = const EdgeInsets.all(5);

    final derivePosterColor = ref.watch(
        clientSettingsProvider.select((value) => value.dynamicPosterColors));
    final cinema = poster.type == KinosItemType.movie ||
        poster.type == KinosItemType.series;
    final backgroundColor = cinema
        ? AppColors.surface
        : derivePosterColor
            ? poster.title.toColor
                .harmonizeWith(Theme.of(context).colorScheme.surface)
            : Theme.of(context).colorScheme.surface;

    return MediaNavigation(
        previewImage: _resolveImage(),
        key: ValueKey(poster.id),
        builder: (context) => FocusButton(
              focusableOverlays: true,
              focusNode: MediaNavigationScope.focusOf(context),
              posterMotion: true,
              onTap: () async {
                if (onPressed != null) {
                  onPressed?.call(() async {
                    await openMediaDetails(context, poster);
                    if (context.mounted) context.refreshData();
                  }, poster);
                } else {
                  await openMediaDetails(context, poster);
                  if (!context.mounted) return;
                  if (context.mounted) context.refreshData();
                }
              },
              onFocusChanged: onFocusChanged,
              onLongPress: () => _showBottomSheet(context, ref),
              onSecondaryTapDown: (details) =>
                  _showContextMenu(context, ref, details.globalPosition),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  color: backgroundColor,
                ),
                foregroundDecoration: BoxDecoration(
                  borderRadius: radius,
                  border:
                      Border.all(width: 1, color: Colors.white.withAlpha(45)),
                ),
                child: MediaArtwork(
                    child: KinosImage(
                  image: _resolveImage(),
                  placeHolder: PosterPlaceholder(item: poster),
                )),
              ),
              overlays: [
                if (showSyncStatus)
                  Align(
                    alignment: Alignment.topRight,
                    child: ref.watch(syncedItemProvider(poster)).when(
                          error: (error, stackTrace) => const SizedBox.shrink(),
                          data: (syncedItem) {
                            if (syncedItem == null) {
                              return const SizedBox.shrink();
                            }
                            return StatusCard(
                              child: SyncButton(
                                  item: poster, syncedItem: syncedItem),
                            );
                          },
                          loading: () => const SizedBox.shrink(),
                        ),
                  ),
                if (selected == true)
                  IgnorePointer(
                    child: SelectedPosterOverlay(
                      poster: poster,
                      radius: radius,
                    ),
                  ),
                BottomOverlaysContainer(
                  showFavourite: poster.userData.isFavourite,
                  showProgress: true,
                  progress: poster.progress,
                  itemType: poster.type,
                  progressPadding: padding,
                ),
                if (inlineTitle)
                  InlineTitleOverlay(
                    title: poster.title.maxLength(limitTo: 25),
                  ),
                UnplayedWatchedOverlay(
                  poster: poster,
                ),
                VideoDurationOverlay(
                  poster: poster,
                  padding: padding,
                ),
              ],
              focusedOverlays: [
                if (AdaptiveLayout.inputDeviceOf(context) ==
                    InputDevice.pointer) ...[
                  //  Play Button
                  if (poster.playAble)
                    Align(
                      alignment: Alignment.center,
                      child: FrostedSurface(
                        borderRadius: AppMediaIcons.circle,
                        color: AppMediaIcons.surface,
                        child: IconButton(
                          tooltip: context.localized.playLabel,
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: AppColors.textPrimary,
                            fixedSize: Size.square(AppMediaIcons.playTargetSize
                                .clamp(context.tokens.density.minTarget,
                                    double.infinity)),
                            shape: const CircleBorder(),
                          ).copyWith(
                            side: WidgetStateProperty.resolveWith((states) =>
                                BorderSide(
                                    color: states.contains(WidgetState.focused)
                                        ? AppColors.focus
                                        : Colors.transparent,
                                    width: context.tokens.density.focusWidth)),
                          ),
                          onPressed: () => playVideo?.call(false),
                          icon: const Icon(AppIcons.play,
                              size: AppMediaIcons.playIconSize),
                        ),
                      ),
                    ),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GlassPopupMenuButton(
                          tooltip: context.localized.options,
                          icon: const Icon(
                            AppIcons.more,
                            color: Colors.white,
                          ),
                          itemBuilder: (context) => poster
                              .generateActions(
                                context,
                                ref,
                                exclude: excludeActions,
                                otherActions: otherActions,
                                onUserDataChanged: onUserDataChanged,
                                onDeleteSuccesFully: onItemRemoved,
                                onItemUpdated: onItemUpdated,
                              )
                              .popupMenuItems(useIcons: true),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ));
  }

  void _showBottomSheet(BuildContext context, WidgetRef ref) {
    showBottomSheetPill(
      context: context,
      item: poster,
      content: (scrollContext, scrollController) => ListView(
        shrinkWrap: true,
        controller: scrollController,
        children: poster
            .generateActions(
              context,
              ref,
              exclude: excludeActions,
              otherActions: otherActions,
              onUserDataChanged: onUserDataChanged,
              onDeleteSuccesFully: onItemRemoved,
              onItemUpdated: onItemUpdated,
            )
            .listTileItems(scrollContext, useIcons: true),
      ),
    );
  }

  Future<void> _showContextMenu(
      BuildContext context, WidgetRef ref, Offset globalPos) async {
    final position = RelativeRect.fromLTRB(
        globalPos.dx, globalPos.dy, globalPos.dx, globalPos.dy);
    await showGlassMenu(
      context: context,
      position: position,
      items: poster
          .generateActions(
            context,
            ref,
            exclude: excludeActions,
            otherActions: otherActions,
            onUserDataChanged: onUserDataChanged,
            onDeleteSuccesFully: onItemRemoved,
            onItemUpdated: onItemUpdated,
          )
          .popupMenuItems(useIcons: true),
    );
  }
}
