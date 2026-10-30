import 'package:kinos/screens/shared/media_navigation.dart';
import 'package:kinos/widgets/shared/animated_media_icon.dart';
import 'package:kinos/theme/app_icons.dart';
import 'dart:async';
import 'package:flutter/material.dart';

import 'package:auto_route/auto_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sliver_tools/sliver_tools.dart';

import 'package:kinos/models/item_base_model.dart';
import 'package:kinos/models/items/images_models.dart';
import 'package:kinos/providers/theme/app_theme_provider.dart';
import 'package:kinos/providers/theme/palette_service_provider.dart';
import 'package:kinos/providers/window_title_provider.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/theme/palette_service.dart';
import 'package:kinos/util/adaptive_layout/adaptive_layout.dart';
import 'package:kinos/util/localization_helper.dart';
import 'package:kinos/util/router_extension.dart';
import 'package:kinos/util/sliver_list_padding.dart';
import 'package:kinos/screens/dashboard/home_hero_backdrop.dart';
import 'package:kinos/screens/shared/media_hero_title.dart';
import 'package:kinos/widgets/shared/item_actions.dart';
import 'package:kinos/widgets/shared/modal_bottom_sheet.dart';
import 'package:kinos/widgets/shared/pull_to_refresh.dart';

/// Écran de détail film/série (et fiche Seerr, cf. `SeerrDetailsScreen`) —
/// même langage visuel que le tableau de bord : bandeau plein cadre teinté
/// par [PaletteService], contenu du reste de l'écran sur
/// [AppColors.background] pur.
///
/// Volontairement séparé de `DetailScaffold` (l'ancien écran générique,
/// encore utilisé par les écrans musique/Live TV/livres/photos, hors
/// périmètre — cf. CLAUDE.md § Périmètre) : cette réécriture ne devait
/// affecter que films, séries et Seerr, pas ces écrans-là.
class MediaDetailScaffold extends ConsumerStatefulWidget {
  /// Item côté données — sert uniquement à dériver la teinte du bandeau
  /// (identité du cache palette) ; tout le contenu affiché passe par les
  /// autres paramètres, explicites.
  final ItemBaseModel? item;

  /// Identité de repli pour le cache de teinte quand il n'y a pas
  /// d'[ItemBaseModel] Jellyfin (ex. fiche Seerr d'un titre pas encore
  /// présent dans la bibliothèque) — sans elle, [item] étant `null`, le
  /// bandeau resterait sur la couleur de repli plutôt que la teinte de
  /// l'image. Ignorée si [item] est fourni.
  final String? paletteId;
  final String label;
  final String? windowTitle;
  final ImagesData? backDrops;
  final Future<void> Function()? onRefresh;

  final String title;
  final String? originalTitle;
  final bool useTitleLogo;

  /// Lien contextuel sous le titre — ex. la série parente d'un épisode.
  /// Absent (défaut) pour un film ou une série, qui n'en ont pas.
  final ({String label, VoidCallback onTap})? parentLink;

  /// Optional movie-specific reading block directly below hero actions.
  final Widget? heroContent;
  final bool cinematic;
  final bool seriesLayout;
  final String metaLine;
  final VoidCallback? onPlay;

  /// Icône du bouton principal — celle d'une lecture par défaut ; une
  /// fiche Seerr (bouton "Demander", pas de lecture) passe autre chose.
  final IconData playIcon;

  /// Libellé du bouton principal — "Lire" (`context.localized.playLabel`)
  /// si absent. Un épisode identifié (série, épisode ouvert directement)
  /// passe un libellé contextuel : "Lire S1 E1" / "Reprendre S1 E3" (cf.
  /// `ItemBaseModel.playButtonLabel`).
  final String? playLabel;

  final bool isFavourite;
  final VoidCallback? onToggleFavourite;
  final bool isPlayed;
  final VoidCallback? onTogglePlayed;

  /// Menu "..." — null si rien à proposer (masque le bouton).
  final List<ItemAction>? Function(BuildContext context)? actions;

  /// Slivers du corps, sous le bandeau — chacun gère son propre espacement
  /// (même convention que `dashboard_screen.dart`), peut inclure
  /// [SingleRowSection] directement.
  final List<Widget> Function(BuildContext context, EdgeInsets padding) content;

  const MediaDetailScaffold({
    required this.label,
    this.windowTitle,
    this.item,
    this.paletteId,
    this.backDrops,
    this.onRefresh,
    required this.title,
    this.originalTitle,
    this.useTitleLogo = true,
    this.parentLink,
    required this.metaLine,
    this.heroContent,
    this.cinematic = false,
    this.seriesLayout = false,
    this.onPlay,
    this.playIcon = AppIcons.play,
    this.playLabel,
    this.isFavourite = false,
    this.onToggleFavourite,
    this.isPlayed = false,
    this.onTogglePlayed,
    this.actions,
    required this.content,
    super.key,
  });

  @override
  ConsumerState<MediaDetailScaffold> createState() =>
      _MediaDetailScaffoldState();
}

class _MediaDetailScaffoldState extends ConsumerState<MediaDetailScaffold> {
  ImageData? _lastPaletteImage;
  StateController<HeroPalette>? _palette;
  late final HeroPalette _previousPalette;
  WindowTitleNotifier? _windowTitleNotifier;

  void _pushTitle() {
    final isCurrent = ModalRoute.of(context)?.isCurrent ?? false;
    if (!isCurrent) return;
    final newTitle = widget.windowTitle ?? widget.label;
    if (newTitle.isNotEmpty) {
      ref.read(windowTitleProvider.notifier).updateTitle(this, newTitle);
    }
  }

  @override
  void initState() {
    super.initState();
    _palette = ref.read(heroPaletteProvider.notifier);
    _previousPalette = _palette!.state;
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
    // Un retour restaure aussi la teinte de la page conservée sous cette fiche.
    final palette = _palette;
    if (palette != null) {
      final previous = palette.mounted ? palette.state : null;
      scheduleMicrotask(() {
        if (palette.mounted && identical(palette.state, previous)) {
          palette.state = _previousPalette;
        }
      });
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MediaDetailScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    _pushTitle();
    _updateHeroPalette();
  }

  /// Source d'image pour le bandeau — préfère un Backdrop (généralement
  /// large, pensé pour ce format) à un Thumb, lui-même préféré à la
  /// jaquette Primary (portrait, dernier recours).
  ImageData? _bannerImage() => widget.backDrops?.backDrop?.isNotEmpty == true
      ? widget.backDrops!.backDrop!.first
      : widget.backDrops?.thumb ?? widget.backDrops?.primary;

  /// Teinte extraite de la même image que celle affichée dans le bandeau
  /// (le backdrop, pas la jaquette) — cohérent avec le tableau de bord.
  Future<void> _updateHeroPalette() async {
    final image = _bannerImage();
    final itemId = widget.item?.id ?? widget.paletteId;
    if (image == null ||
        itemId == null ||
        identical(image, _lastPaletteImage)) {
      return;
    }
    _lastPaletteImage = image;

    final palette = await ref.read(paletteServiceProvider).forItem(
          itemId: itemId,
          image: image.imageProvider,
        );

    if (!mounted || !identical(_lastPaletteImage, image)) return;
    _palette?.state = palette;
  }

  void _showActions(BuildContext context) {
    final actions = widget.actions?.call(context) ?? const [];
    showBottomSheetPill(
      context: context,
      content: (context, scrollController) => ListView(
        controller: scrollController,
        shrinkWrap: true,
        children: actions.listTileItems(context, useIcons: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _palette ??= ref.read(heroPaletteProvider.notifier);
    final sidebar = AdaptiveLayout.of(context).sideBarWidth;
    final padding = AdaptiveLayout.adaptivePadding(context,
        horizontalPadding: AppSpacing.screenPadding);
    final image = _bannerImage();
    return PullToRefresh(
      onRefresh: widget.onRefresh,
      refreshOnStart: true,
      child: (context) => Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(children: [
          CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverStack(children: [
                  SliverPositioned.fill(
                      child: AnimatedContainer(
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : AppDurations.heroTint,
                    decoration: BoxDecoration(
                        gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: widget.cinematic
                                ? const [0, AppDetailLayout.tintFadeStart, 1]
                                : null,
                            colors: widget.cinematic
                                ? [
                                    context.tokens.heroTint,
                                    context.tokens.heroTint,
                                    AppColors.background
                                  ]
                                : [
                                    context.tokens.heroTint,
                                    AppColors.background
                                  ])),
                  )),
                  SliverMainAxisGroup(slivers: [
                    SliverToBoxAdapter(
                        child: LayoutBuilder(builder: (context, constraints) {
                      final available = constraints.maxWidth - sidebar;
                      return ConstrainedBox(
                          constraints: BoxConstraints(
                              minHeight: (MediaQuery.sizeOf(context).height *
                                      (widget.seriesLayout
                                          ? AppDetailLayout
                                              .seriesViewportFraction
                                          : widget.cinematic
                                              ? AppDetailLayout
                                                  .movieViewportFraction
                                              : AppDetailLayout
                                                  .viewportHeightFraction))
                                  .clamp(
                                      widget.seriesLayout
                                          ? AppDetailLayout.seriesMinHeight *
                                              context.tokens.density.scale
                                          : widget.cinematic
                                              ? AppDetailLayout.movieMinHeight *
                                                  context.tokens.density.scale
                                              : AppDetailLayout.minHeightFor(
                                                  context.tokens.density),
                                      double.infinity)),
                          child:
                              Stack(alignment: Alignment.bottomLeft, children: [
                            Positioned.fill(
                                child: MediaArtwork(
                                    child: HomeHeroBackdrop(
                                        image: image,
                                        fallback: switch (
                                            MediaNavigationScope.tagOf(
                                                context)) {
                                          MediaNavigationOrigin origin =>
                                            origin.image,
                                          _ => null,
                                        },
                                        cinematic: widget.cinematic))),
                            Padding(
                                padding: EdgeInsetsDirectional.fromSTEB(
                                    sidebar + AppSpacing.screenPadding,
                                    AppDetailLayout.topPadding,
                                    AppSpacing.screenPadding,
                                    widget.cinematic
                                        ? AppDetailLayout.movieBottomPadding
                                        : AppHeroLayout.titleBottomSpace),
                                child: SizedBox(
                                    width: available *
                                        (available < AppHeroLayout.narrowWidth
                                            ? AppHeroLayout
                                                .narrowTextWidthFraction
                                            : AppHeroLayout.textWidthFraction),
                                    child: _TitleBlock(
                                        widget: widget,
                                        availableWidth: available,
                                        onMore: widget.actions == null
                                            ? null
                                            : () => _showActions(context)))),
                          ]));
                    })),
                    if (widget.cinematic)
                      SliverToBoxAdapter(
                          child: SizedBox(
                              key: const ValueKey('detail-tint-fade'),
                              height: widget.seriesLayout
                                  ? AppDetailLayout.seriesTintTailHeight
                                  : AppDetailLayout.tintTailHeight)),
                  ]),
                ]),
                ...widget.content(context, padding),
                const DefaultSliverBottomPadding(),
              ]),
          PositionedDirectional(
              top: MediaQuery.paddingOf(context).top + AppSpacing.sm,
              start: sidebar + AppSpacing.sm,
              child: FocusRing(
                  borderRadius: AppRadii.controlBorder,
                  onActivate: () => context.router.popBack(),
                  child: ExcludeFocus(
                      child: IconButton.filledTonal(
                          tooltip: MaterialLocalizations.of(context)
                              .backButtonTooltip,
                          style: IconButton.styleFrom(
                              backgroundColor: AppPlayerStyle.controlSurface,
                              foregroundColor: AppColors.textPrimary),
                          onPressed: () => context.router.popBack(),
                          icon: const BackButtonIcon())))),
        ]),
      ),
    );
  }
}

class _TitleBlock extends StatelessWidget {
  const _TitleBlock(
      {required this.widget,
      required this.availableWidth,
      required this.onMore});
  final MediaDetailScaffold widget;
  final double availableWidth;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final secondary =
        AppColors.textPrimary.withValues(alpha: AppHeroLayout.secondaryOpacity);
    final iconStyle = IconButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        backgroundColor: AppPlayerStyle.controlSurface,
        side: const BorderSide(color: AppColors.borderStrong),
        shape:
            const RoundedRectangleBorder(borderRadius: AppRadii.controlBorder));
    Widget action(Widget icon, String tooltip, VoidCallback callback) =>
        FocusRing(
            borderRadius: AppRadii.controlBorder,
            onActivate: callback,
            child: ExcludeFocus(
                child: IconButton.outlined(
                    style: iconStyle,
                    tooltip: tooltip,
                    onPressed: callback,
                    icon: icon)));
    final parent = widget.parentLink;
    return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MediaArtwork(
              title: true,
              child: MediaHeroTitle(
                  title: widget.title,
                  logo: widget.useTitleLogo && widget.parentLink == null
                      ? widget.backDrops?.logo ?? widget.item?.tvPosterLogo
                      : null,
                  availableWidth: availableWidth)),
          if (parent != null)
            Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: FocusRing(
                    borderRadius: AppRadii.controlBorder,
                    onActivate: parent.onTap,
                    child: ExcludeFocus(
                        child: TextButton.icon(
                            onPressed: parent.onTap,
                            icon: const Icon(
                                Icons.subdirectory_arrow_right_rounded),
                            label: Text(parent.label,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis))))),
          if (widget.originalTitle?.trim().isNotEmpty == true &&
              widget.originalTitle!.toLowerCase() != widget.title.toLowerCase())
            Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(widget.originalTitle!,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: secondary))),
          if (widget.metaLine.isNotEmpty)
            Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: Text(widget.metaLine,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: secondary))),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (widget.onPlay != null)
                  FocusRing(
                      borderRadius: AppRadii.controlBorder,
                      autofocus: AdaptiveLayout.inputDeviceOf(context) ==
                          InputDevice.dPad,
                      onActivate: widget.onPlay,
                      child: ExcludeFocus(
                          child: FilledButton.icon(
                              onPressed: widget.onPlay,
                              icon: Icon(widget.playIcon),
                              label: Text(widget.playLabel ??
                                  context.localized.playLabel)))),
                if (widget.onToggleFavourite != null)
                  action(AnimatedFavouriteIcon(selected: widget.isFavourite),
                      context.localized.favorite, widget.onToggleFavourite!),
                if (widget.onTogglePlayed != null)
                  action(
                      AnimatedWatchedIcon(selected: widget.isPlayed),
                      widget.isPlayed
                          ? context.localized.markAsUnwatched
                          : context.localized.markAsWatched,
                      widget.onTogglePlayed!),
                if (onMore != null)
                  action(const Icon(AppIcons.more),
                      context.localized.moreOptions, onMore!),
              ]),
          if (widget.heroContent != null) ...[
            const SizedBox(height: AppSpacing.md),
            widget.heroContent!,
          ],
        ]);
  }
}
