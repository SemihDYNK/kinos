import 'package:kinos/widgets/shared/frosted_surface.dart';
import 'package:flutter/material.dart';

import 'package:auto_route/auto_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:palette_generator_master/palette_generator_master.dart';

import 'package:kinos/models/item_base_model.dart';
import 'package:kinos/models/items/images_models.dart';
import 'package:kinos/providers/sync/sync_provider_helpers.dart';
import 'package:kinos/providers/sync_provider.dart';
import 'package:kinos/providers/theme/app_theme_provider.dart';
import 'package:kinos/providers/theme/palette_service_provider.dart';
import 'package:kinos/providers/user_provider.dart';
import 'package:kinos/providers/window_title_provider.dart';
import 'package:kinos/routes/auto_router.gr.dart';
import 'package:kinos/screens/syncing/sync_button.dart';
import 'package:kinos/screens/syncing/sync_item_details.dart';
import 'package:kinos/shaders/fade_edges.dart';
import 'package:kinos/theme.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/theme/palette_service.dart';
import 'package:kinos/util/adaptive_layout/adaptive_layout.dart';
import 'package:kinos/util/kinos_image.dart';
import 'package:kinos/util/localization_helper.dart';
import 'package:kinos/util/refresh_state.dart';
import 'package:kinos/util/router_extension.dart';
import 'package:kinos/widgets/navigation_scaffold/components/settings_user_icon.dart';
import 'package:kinos/widgets/shared/item_actions.dart';
import 'package:kinos/widgets/shared/modal_bottom_sheet.dart';
import 'package:kinos/widgets/shared/pull_to_refresh.dart';

/// Utilisé par [DetailScaffold] (via [PaletteService.fromSeed] quand la
/// couleur est déjà connue) et par les écrans musique hors périmètre
/// (`ThemeOverwrite`, lecteur audio) qui l'appellent directement.
Future<Color?> getDominantColor(ImageProvider imageProvider) async {
  final paletteGenerator = await PaletteGeneratorMaster.fromImageProvider(
    imageProvider,
    size: const Size(16, 16),
    maximumColorCount: 3,
  );

  return paletteGenerator.dominantColor?.color ??
      paletteGenerator.vibrantColor?.color;
}

class DetailScaffold extends ConsumerStatefulWidget {
  final String label;
  final String? windowTitle;
  final ItemBaseModel? item;
  final List<ItemAction>? Function(BuildContext context)? actions;
  final Color? backgroundColor;
  final ImagesData? backDrops;
  final Function(BuildContext context, EdgeInsets padding) content;
  final Future<void> Function()? onRefresh;
  final bool posterFillsContent;

  /// Couleur déjà connue (ex. moyenne du blurhash, calculée en amont par
  /// l'appelant) : passe par [PaletteService.fromSeed] au lieu de relancer
  /// une extraction depuis la jaquette de [item].
  final Color? dominantColor;
  const DetailScaffold({
    required this.label,
    this.windowTitle,
    this.item,
    this.actions,
    this.backgroundColor,
    required this.content,
    this.backDrops,
    this.onRefresh,
    this.posterFillsContent = false,
    this.dominantColor,
    super.key,
  });

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _DetailScaffoldState();
}

class _DetailScaffoldState extends ConsumerState<DetailScaffold> {
  late ItemBaseModel? item = widget.item;
  List<ImageData>? lastImages;
  ImageData? backgroundImage;

  ImageData? _lastPaletteImage;

  WindowTitleNotifier? _windowTitleNotifier;

  void _pushTitle() {
    final isCurrent = ModalRoute.of(context)?.isCurrent ?? false;
    if (!isCurrent) return;

    final newTitle = widget.windowTitle ??
        widget.item?.windowTitle(context.localized) ??
        widget.label;
    if (newTitle.isNotEmpty) {
      ref.read(windowTitleProvider.notifier).updateTitle(this, newTitle);
    }
  }

  @override
  void initState() {
    super.initState();
    _updateHeroPalette();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _windowTitleNotifier = ref.read(windowTitleProvider.notifier);
    _pushTitle();
  }

  @override
  void dispose() {
    _windowTitleNotifier?.removeTitle(this);
    // Le bandeau est propre à cet écran : ne pas laisser sa teinte déteindre
    // sur ce qui s'affiche ensuite (retour au tableau de bord, par ex.).
    ref.read(heroPaletteProvider.notifier).state = HeroPalette.fallback;
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant DetailScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    _pushTitle();
    updateImage();
    _updateHeroPalette();
    if (widget.backDrops != oldWidget.backDrops) {
      lastImages = widget.backDrops?.backDrop;
      backgroundImage = widget.backDrops?.randomBackDrop;
    }
    if (widget.item != null && widget.item?.id != item?.id) {
      item = widget.item;
    }
  }

  void updateImage() {
    if (lastImages == null) {
      lastImages = widget.backDrops?.backDrop;
      backgroundImage = widget.backDrops?.randomBackDrop;
    }
  }

  /// Teinte le bandeau depuis la jaquette de l'item, via [PaletteService] —
  /// bridage de luminance/saturation et vérification de contraste déjà faits
  /// là-bas. Seul [heroPaletteProvider] change ; le reste de l'écran garde
  /// [AppColors.background].
  Future<void> _updateHeroPalette() async {
    if (widget.dominantColor != null) {
      ref.read(heroPaletteProvider.notifier).state =
          ref.read(paletteServiceProvider).fromSeed(widget.dominantColor!);
      return;
    }

    final currentItem = widget.item;
    final newImage =
        currentItem?.getPosters?.primary ?? currentItem?.getPosters?.logo;
    if (newImage == null || identical(newImage, _lastPaletteImage)) return;
    _lastPaletteImage = newImage;

    final palette = await ref.read(paletteServiceProvider).forItem(
          itemId: currentItem!.id,
          image: newImage.imageProvider,
        );

    if (!mounted || !identical(_lastPaletteImage, newImage)) return;

    ref.read(heroPaletteProvider.notifier).state = palette;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final horizontalBasePadding = size.width / 25;
    final safeArea = MediaQuery.paddingOf(context);
    final backGroundColor =
        Theme.of(context).colorScheme.surface.withValues(alpha: 0.8);
    final minHeight = 450.0.clamp(0, size.height).toDouble();
    final maxHeight = size.height - 10;
    final sideBarPadding = AdaptiveLayout.of(context).sideBarWidth;
    final topBarPadding = AdaptiveLayout.of(context).topBarHeight;
    final directionalSidePadding =
        EdgeInsetsDirectional.only(start: sideBarPadding);
    final horizontalPadding = 16.0;
    final contentPadding = EdgeInsets.only(
      left: isRtl
          ? horizontalBasePadding
          : sideBarPadding + horizontalPadding + safeArea.left,
      right: isRtl
          ? sideBarPadding + horizontalPadding + safeArea.right
          : horizontalBasePadding,
    );
    final topRowPadding = safeArea
        .add(directionalSidePadding.resolve(Directionality.of(context)))
        .add(EdgeInsets.only(top: topBarPadding))
        .add(EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 12));
    // Seul le bandeau (le dégradé sur l'image) prend la dominante du film ;
    // déjà bridée en luminance/saturation par PaletteService. Interpolée en
    // douceur par l'AnimatedTheme posé à la racine de l'app.
    final heroTint = context.tokens.heroTint;

    return PullToRefresh(
      onRefresh: () async {
        await widget.onRefresh?.call();
        if (mounted) {
          setState(() {
            if (widget.backDrops?.backDrop?.contains(backgroundImage) == true) {
              backgroundImage = widget.backDrops?.randomBackDrop;
            }
          });
        }
      },
      refreshOnStart: true,
      child: (context) => Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        extendBodyBehindAppBar: true,
        body: Stack(
          children: [
            SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Stack(
                children: [
                  SizedBox(
                    height: maxHeight,
                    width: size.width,
                    child: KinosImage(
                      image: backgroundImage,
                      blurOnly: !widget.posterFillsContent,
                    ),
                  ),
                  if (backgroundImage != null && !widget.posterFillsContent)
                    Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: EdgeInsetsDirectional.only(
                          start: sideBarPadding / 1.5,
                          top: topBarPadding / 1.5,
                        ),
                        child: RepaintBoundary(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minWidth: double.infinity,
                              minHeight: minHeight - 22,
                              maxHeight: maxHeight.clamp(minHeight, 2500) -
                                  (20 + topBarPadding),
                            ),
                            child: FadeEdges(
                              leftFade:
                                  sideBarPadding > 0 && !isRtl ? 0.05 : 0.0,
                              rightFade:
                                  sideBarPadding > 0 && isRtl ? 0.05 : 0.0,
                              topFade: topBarPadding > 0 ? 0.1 : 0.0,
                              bottomFade: 0.2,
                              child: FadeInImage(
                                placeholder: ResizeImage(
                                  backgroundImage!.imageProvider,
                                  height: maxHeight ~/ 1.5,
                                ),
                                placeholderColor: Colors.transparent,
                                fit: BoxFit.cover,
                                alignment: Alignment.topCenter,
                                placeholderFit: BoxFit.cover,
                                excludeFromSemantics: true,
                                image: ResizeImage(
                                  backgroundImage!.imageProvider,
                                  height: maxHeight ~/ 1.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  Container(
                    width: double.infinity,
                    height: maxHeight + 10,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: widget.posterFillsContent
                            ? [
                                heroTint.withValues(alpha: 0),
                                heroTint.withValues(alpha: 0.95),
                                AppColors.background,
                              ]
                            : [
                                heroTint.withValues(alpha: 0),
                                heroTint.withValues(alpha: 0.10),
                                heroTint.withValues(alpha: 0.35),
                                heroTint.withValues(alpha: 0.85),
                                AppColors.background,
                              ],
                      ),
                    ),
                  ),
                  Container(
                    height: size.height,
                    width: size.width,
                    color: widget.backgroundColor,
                  ),
                  FocusScope(
                    autofocus: true,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: size.height,
                        maxWidth: size.width,
                      ),
                      child: widget.content(
                        context,
                        contentPadding,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            //Top row buttons
            if (AdaptiveLayout.inputDeviceOf(context) != InputDevice.dPad)
              IconTheme(
                data: IconThemeData(
                    color: Theme.of(context).colorScheme.onSurface),
                child: Padding(
                  padding: topRowPadding,
                  child: Row(
                    children: [
                      IconButton.filledTonal(
                        style: IconButton.styleFrom(
                          backgroundColor: backGroundColor,
                        ),
                        onPressed: () => context.router.popBack(),
                        icon: Padding(
                          padding: EdgeInsets.all(
                              AdaptiveLayout.inputDeviceOf(context) ==
                                      InputDevice.pointer
                                  ? 0
                                  : 4),
                          child: const BackButtonIcon(),
                        ),
                      ),
                      const Spacer(),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 250),
                        child: Container(
                          decoration: BoxDecoration(
                              color: backGroundColor,
                              borderRadius:
                                  KinosTheme.defaultShape.borderRadius),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (item != null) ...[
                                ref.watch(syncedItemProvider(item)).when(
                                      error: (error, stackTrace) =>
                                          const SizedBox.shrink(),
                                      data: (syncedItem) {
                                        if (syncedItem == null &&
                                            ref.read(userProvider.select(
                                              (value) =>
                                                  value?.canDownload ?? false,
                                            )) &&
                                            item?.syncAble == true) {
                                          return IconButton(
                                            onPressed: () => ref
                                                .read(syncProvider.notifier)
                                                .addSyncItem(context, item!),
                                            icon: const Icon(
                                              IconsaxPlusLinear.arrow_down_2,
                                            ),
                                          );
                                        } else if (syncedItem != null) {
                                          return IconButton(
                                            onPressed: () =>
                                                showSyncItemDetails(
                                                    context, syncedItem, ref),
                                            icon: SyncButton(
                                                item: item!,
                                                syncedItem: syncedItem),
                                          );
                                        }
                                        return const SizedBox.shrink();
                                      },
                                      loading: () => const SizedBox.shrink(),
                                    ),
                                Builder(
                                  builder: (context) {
                                    final newActions =
                                        widget.actions?.call(context);
                                    if (AdaptiveLayout.inputDeviceOf(context) ==
                                        InputDevice.pointer) {
                                      return GlassPopupMenuButton(
                                        tooltip: context.localized.moreOptions,
                                        enabled: newActions?.isNotEmpty == true,
                                        icon: Icon(
                                          item!.type.icon,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface,
                                        ),
                                        itemBuilder: (context) =>
                                            newActions?.popupMenuItems(
                                                useIcons: true) ??
                                            [],
                                      );
                                    } else {
                                      return IconButton(
                                        onPressed: () => showBottomSheetPill(
                                          context: context,
                                          content:
                                              (context, scrollController) =>
                                                  ListView(
                                            controller: scrollController,
                                            shrinkWrap: true,
                                            children: newActions?.listTileItems(
                                                    context,
                                                    useIcons: true) ??
                                                [],
                                          ),
                                        ),
                                        icon: Icon(
                                          item!.type.icon,
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ],
                              if (AdaptiveLayout.inputDeviceOf(context) ==
                                  InputDevice.pointer)
                                Tooltip(
                                  message: context.localized.refresh,
                                  child: IconButton(
                                    onPressed: () => context.refreshData(),
                                    icon: const Icon(IconsaxPlusLinear.refresh),
                                  ),
                                ),
                              if (AdaptiveLayout.layoutModeOf(context) ==
                                      LayoutMode.single ||
                                  AdaptiveLayout.viewSizeOf(context) ==
                                      ViewSize.phone)
                                Container(
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 6),
                                  child: const SizedBox(
                                    height: 30,
                                    width: 30,
                                    child: SettingsUserIcon(),
                                  ),
                                ),
                              if (AdaptiveLayout.layoutModeOf(context) ==
                                  LayoutMode.single)
                                Tooltip(
                                    message: context.localized.home,
                                    child: IconButton(
                                      onPressed: () => context
                                          .navigateTo(const DashboardRoute()),
                                      icon: const Icon(IconsaxPlusLinear.home),
                                    )),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
