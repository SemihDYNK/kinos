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
import 'package:kinos/widgets/shared/fading_hero_backdrop.dart';
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

  /// Lien contextuel sous le titre — ex. la série parente d'un épisode.
  /// Absent (défaut) pour un film ou une série, qui n'en ont pas.
  final ({String label, VoidCallback onTap})? parentLink;

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
    this.parentLink,
    required this.metaLine,
    this.onPlay,
    this.playIcon = Icons.play_arrow_rounded,
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
    // sur ce qui s'affiche ensuite.
    ref.read(heroPaletteProvider.notifier).state = HeroPalette.fallback;
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
      ? widget.backDrops!.randomBackDrop
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
    ref.read(heroPaletteProvider.notifier).state = palette;
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
    final density = context.tokens.density;
    // Hauteur du bloc titre/métadonnées/boutons — 680/760 selon densité,
    // jusqu'à +80 si le titre (2 lignes) le demande. Ce bloc reste posé sur
    // l'image, à la même position qu'avant ; c'est la hauteur de l'image de
    // fond (ci-dessous) qui change.
    final minTitleHeight = density == AppDensity.couch ? 760.0 : 680.0;
    final maxTitleHeight = minTitleHeight + 80;
    // Hauteur de l'image de fond — nettement plus haute que le bloc titre :
    // elle continue derrière le résumé, les sélecteurs et le début du
    // casting, et s'efface sous le voile dégradé de _BannerBackdrop plutôt
    // que de s'arrêter net à la hauteur du titre. Plus de zone de
    // transition, donc plus de ligne de coupure visible.
    final backdropHeight = density == AppDensity.couch ? 1300.0 : 1200.0;
    final sideBarInset = AdaptiveLayout.of(context).sideBarWidth;
    // `padding` inclut déjà la largeur de la barre latérale (cf.
    // AdaptiveLayout.adaptivePadding) : la barre latérale n'est pas une
    // colonne séparée, c'est un calque semi-transparent posé par-dessus un
    // contenu plein cadre (SideNavigationRail). Le SliverPadding ci-dessous
    // applique déjà `sideBarInset` une fois pour tout le bandeau ET le
    // contenu (imbriqués ensemble dans le même SliverStack, cf. plus bas) :
    // leur passer `padding` tel quel le décalerait une seconde fois, d'où
    // `innerPadding` (sans lui) — même mécanique que dashboard_screen.dart.
    // Le bloc titre, lui, n'a jamais eu ce problème : son padding est fixe
    // (`AppSpacing.screenPadding`, dans _TitleBlock), pas dérivé de
    // `adaptivePadding`.
    final padding = AdaptiveLayout.adaptivePadding(context,
        horizontalPadding: AppSpacing.screenPadding);
    final innerPadding = padding.copyWith(left: padding.left - sideBarInset);
    final heroTint = context.tokens.heroTint;
    final heroTextSecondary = context.tokens.heroTextSecondary;
    final image = _bannerImage();
    final hasActions = widget.actions != null;

    return PullToRefresh(
      onRefresh: () async => await widget.onRefresh?.call(),
      refreshOnStart: true,
      child: (context) => Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                const DefaultSliverTopBadding(),
                // SliverPadding(start: sideBarInset) : la barre latérale
                // reste sur AppColors.background pur, jamais teintée — même
                // mécanique que dashboard_screen.dart.
                //
                // SliverStack (sliver_tools) superpose deux slivers dans le
                // même espace de défilement, au lieu de les enchaîner :
                // - FadingHeroBackdrop, épinglé en haut sur `backdropHeight`
                //   (positionné via SliverPositioned, ne compte donc pas
                //   dans la taille du groupe) ;
                // - le bloc titre puis tout le contenu (`widget.content`),
                //   qui déterminent la taille réelle du groupe.
                // L'image reste pleinement nette sur toute la hauteur du
                // bloc titre (`holdUntil: minTitleHeight`, posé par-dessus
                // elle) ; le voile ne commence qu'après, et se dissout
                // entièrement (jamais un aplat de substitution — une seule
                // surface peinte au final, celle du Scaffold) pendant que
                // l'image continue derrière le résumé, les sélecteurs et le
                // début du casting — cf. FadingHeroBackdrop.
                SliverPadding(
                  padding: EdgeInsetsDirectional.only(start: sideBarInset),
                  sliver: SliverStack(
                    children: [
                      SliverPositioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: backdropHeight,
                        child: FadingHeroBackdrop(
                          image: image,
                          heroTint: heroTint,
                          holdUntil: minTitleHeight,
                        ),
                      ),
                      SliverMainAxisGroup(
                        slivers: [
                          SliverToBoxAdapter(
                            child: _TitleBlock(
                              minHeight: minTitleHeight,
                              maxHeight: maxTitleHeight,
                              heroTextSecondary: heroTextSecondary,
                              title: widget.title,
                              originalTitle: widget.originalTitle,
                              parentLink: widget.parentLink,
                              metaLine: widget.metaLine,
                              onPlay: widget.onPlay,
                              playIcon: widget.playIcon,
                              playLabel: widget.playLabel,
                              isFavourite: widget.isFavourite,
                              onToggleFavourite: widget.onToggleFavourite,
                              isPlayed: widget.isPlayed,
                              onTogglePlayed: widget.onTogglePlayed,
                              onMore: hasActions
                                  ? () => _showActions(context)
                                  : null,
                            ),
                          ),
                          ...widget.content(context, innerPadding),
                        ],
                      ),
                    ],
                  ),
                ),
                const DefaultSliverBottomPadding(),
              ],
            ),
            PositionedDirectional(
              top: MediaQuery.paddingOf(context).top + AppSpacing.sm,
              start: sideBarInset + AppSpacing.sm,
              child: FocusRing(
                borderRadius: AppRadii.controlBorder,
                onActivate: () => context.router.popBack(),
                child: ExcludeFocus(
                  child: IconButton.filledTonal(
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.scrim.withValues(alpha: 0.4),
                      foregroundColor: AppColors.textPrimary,
                    ),
                    onPressed: () => context.router.popBack(),
                    icon: const BackButtonIcon(),
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

/// Bloc titre/métadonnées/boutons — posé sur [FadingHeroBackdrop], pas de
/// calque d'image ou de dégradé propre : le fond vient entièrement de la
/// zone de FadingHeroBackdrop qui le recouvre (même espace de défilement,
/// cf. le SliverStack de l'appelant).
class _TitleBlock extends StatelessWidget {
  final double minHeight;
  final double maxHeight;
  final Color heroTextSecondary;
  final String title;
  final String? originalTitle;
  final ({String label, VoidCallback onTap})? parentLink;
  final String metaLine;
  final VoidCallback? onPlay;
  final IconData playIcon;
  final String? playLabel;
  final bool isFavourite;
  final VoidCallback? onToggleFavourite;
  final bool isPlayed;
  final VoidCallback? onTogglePlayed;
  final VoidCallback? onMore;

  const _TitleBlock({
    required this.minHeight,
    required this.maxHeight,
    required this.heroTextSecondary,
    required this.title,
    required this.originalTitle,
    required this.parentLink,
    required this.metaLine,
    required this.onPlay,
    required this.playIcon,
    required this.playLabel,
    required this.isFavourite,
    required this.onToggleFavourite,
    required this.isPlayed,
    required this.onTogglePlayed,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    final showOriginalTitle = originalTitle != null &&
        originalTitle!.toLowerCase() != title.toLowerCase();
    final secondaryButtonStyle = IconButton.styleFrom(
      side: BorderSide(color: heroTextSecondary),
      foregroundColor: heroTextSecondary,
      overlayColor: heroTextSecondary,
    );

    // Hauteur minimale, extensible si le titre (2 lignes max) le demande —
    // même mécanique de dimensionnement que le bandeau du tableau de bord
    // (le Column non positionné pilote la taille du Stack).
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight, maxHeight: maxHeight),
      child: Stack(
        alignment: Alignment.bottomLeft,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .displayLarge
                      ?.copyWith(color: AppColors.textPrimary),
                ),
                if (parentLink != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xxs),
                    child: FocusRing(
                      borderRadius: AppRadii.controlBorder,
                      onActivate: parentLink!.onTap,
                      child: ExcludeFocus(
                        child: InkWell(
                          borderRadius: AppRadii.controlBorder,
                          onTap: parentLink!.onTap,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.subdirectory_arrow_right_rounded,
                                  size: 16, color: heroTextSecondary),
                              const SizedBox(width: AppSpacing.xxs),
                              Text(
                                parentLink!.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(color: heroTextSecondary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                if (showOriginalTitle)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xxs),
                    child: Text(
                      originalTitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      // 75%, pas moins : sur une image, même voilée, le texte
                      // secondaire suit AppColors.textPrimary à 75% d'opacité
                      // (règle du bandeau teinté, CLAUDE.md) — même valeur que
                      // metaLine ci-dessous. À 55% (l'ancienne valeur), le
                      // contraste n'était plus garanti.
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textPrimary.withValues(alpha: 0.75)),
                    ),
                  ),
                if (metaLine.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    metaLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textPrimary.withValues(alpha: 0.75)),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (onPlay != null)
                      FocusRing(
                        autofocus: AdaptiveLayout.inputDeviceOf(context) ==
                            InputDevice.dPad,
                        onActivate: onPlay,
                        child: ExcludeFocus(
                          child: FilledButton.icon(
                            onPressed: onPlay,
                            icon: Icon(playIcon),
                            label:
                                Text(playLabel ?? context.localized.playLabel),
                          ),
                        ),
                      ),
                    const SizedBox(width: AppSpacing.sm),
                    if (onToggleFavourite != null)
                      FocusRing(
                        borderRadius: AppRadii.controlBorder,
                        onActivate: onToggleFavourite,
                        child: ExcludeFocus(
                          child: IconButton.outlined(
                            style: secondaryButtonStyle,
                            onPressed: onToggleFavourite,
                            icon: Icon(
                              isFavourite
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(width: AppSpacing.xxs),
                    if (onTogglePlayed != null)
                      FocusRing(
                        borderRadius: AppRadii.controlBorder,
                        onActivate: onTogglePlayed,
                        child: ExcludeFocus(
                          child: IconButton.outlined(
                            style: secondaryButtonStyle,
                            onPressed: onTogglePlayed,
                            icon: Icon(
                              isPlayed
                                  ? Icons.check_circle_rounded
                                  : Icons.check_circle_outline_rounded,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(width: AppSpacing.xxs),
                    if (onMore != null)
                      FocusRing(
                        borderRadius: AppRadii.controlBorder,
                        onActivate: onMore,
                        child: ExcludeFocus(
                          child: IconButton.outlined(
                            style: secondaryButtonStyle,
                            onPressed: onMore,
                            icon: const Icon(Icons.more_horiz_rounded),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
