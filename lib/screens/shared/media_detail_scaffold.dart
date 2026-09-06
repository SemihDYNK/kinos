import 'package:flutter/material.dart';

import 'package:auto_route/auto_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sliver_tools/sliver_tools.dart';

import 'package:fladder/models/item_base_model.dart';
import 'package:fladder/models/items/images_models.dart';
import 'package:fladder/providers/theme/app_theme_provider.dart';
import 'package:fladder/providers/theme/palette_service_provider.dart';
import 'package:fladder/providers/window_title_provider.dart';
import 'package:fladder/theme/app_theme.dart';
import 'package:fladder/theme/palette_service.dart';
import 'package:fladder/util/adaptive_layout/adaptive_layout.dart';
import 'package:fladder/util/fladder_image.dart';
import 'package:fladder/util/localization_helper.dart';
import 'package:fladder/util/router_extension.dart';
import 'package:fladder/util/sliver_list_padding.dart';
import 'package:fladder/widgets/shared/item_actions.dart';
import 'package:fladder/widgets/shared/modal_bottom_sheet.dart';
import 'package:fladder/widgets/shared/pull_to_refresh.dart';

/// Écran de détail film/série — même langage visuel que le tableau de bord :
/// bandeau plein cadre teinté par [PaletteService], contenu du reste de
/// l'écran sur [AppColors.background] pur.
///
/// Volontairement séparé de `DetailScaffold` (l'ancien écran générique,
/// encore utilisé par les écrans musique/Live TV/livres/photos/Seerr, hors
/// périmètre — cf. CLAUDE.md § Périmètre) : cette réécriture ne devait
/// affecter que films et séries, pas ces écrans-là.
class MediaDetailScaffold extends ConsumerStatefulWidget {
  /// Item côté données — sert uniquement à dériver la teinte du bandeau
  /// (identité du cache palette) ; tout le contenu affiché passe par les
  /// autres paramètres, explicites.
  final ItemBaseModel? item;
  final String label;
  final String? windowTitle;
  final ImagesData? backDrops;
  final Future<void> Function()? onRefresh;

  final String title;
  final String? originalTitle;
  final String metaLine;
  final VoidCallback? onPlay;
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
    this.backDrops,
    this.onRefresh,
    required this.title,
    this.originalTitle,
    required this.metaLine,
    this.onPlay,
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
    final itemId = widget.item?.id;
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
                // - _BannerBackdrop, épinglé en haut sur `backdropHeight`
                //   (positionné via SliverPositioned, ne compte donc pas
                //   dans la taille du groupe) ;
                // - le bloc titre puis tout le contenu (`widget.content`),
                //   qui déterminent la taille réelle du groupe.
                // L'image continue donc derrière le résumé, les sélecteurs
                // et le début du casting, tant que ce contenu tient dans
                // `backdropHeight` ; au-delà, plus de calque image — juste
                // le fond de la page, déjà atteint par le voile dégradé.
                SliverPadding(
                  padding: EdgeInsetsDirectional.only(start: sideBarInset),
                  sliver: SliverStack(
                    children: [
                      SliverPositioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: backdropHeight,
                        child: _BannerBackdrop(
                          image: image,
                          heroTint: heroTint,
                          minTitleHeight: minTitleHeight,
                          backdropHeight: backdropHeight,
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
                              metaLine: widget.metaLine,
                              onPlay: widget.onPlay,
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

/// Image de fond du haut d'écran — continue derrière le bloc titre et le
/// début du contenu (résumé, sélecteurs, casting), et s'efface sous son
/// propre voile dégradé plutôt que de s'arrêter net à une hauteur fixe.
/// Occupe toute la hauteur `SliverPositioned` qui l'englobe (cf. l'appelant).
class _BannerBackdrop extends StatelessWidget {
  final ImageData? image;
  final Color heroTint;
  final double minTitleHeight;
  final double backdropHeight;

  const _BannerBackdrop({
    required this.image,
    required this.heroTint,
    required this.minTitleHeight,
    required this.backdropHeight,
  });

  @override
  Widget build(BuildContext context) {
    // L'image reste nette et non voilée sur toute sa moitié haute ; le
    // voile ne commence à monter qu'à l'approche du bloc titre
    // (`minTitleHeight`), où il atteint une teinte pleinement opaque, puis
    // continue vers le fond de page peu après (marge de 120px, pour que le
    // résumé qui suit démarre déjà sur un aplat opaque, jamais sur une
    // transparence résiduelle).
    final titleFraction = (minTitleHeight / backdropHeight).clamp(0.0, 1.0);
    final backgroundFraction =
        ((minTitleHeight + 120) / backdropHeight).clamp(0.0, 1.0);

    return Stack(
      fit: StackFit.expand,
      children: [
        // a. Fond teinté — visible au chargement et sur les bords.
        ColoredBox(color: heroTint),
        // b. Backdrop plein cadre, cover, centré.
        FladderImage(image: image, fit: BoxFit.cover),
        // c. Voile dégradé vertical : transparent jusqu'à mi-hauteur (image
        // nue et lisible sur toute sa moitié haute), puis heroTint qui monte
        // rapidement à l'approche du bloc titre, puis fond de page opaque
        // peu après — l'image continue derrière le contenu et disparaît
        // sous ce voile, sans ligne de séparation.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0, 0.5, titleFraction, backgroundFraction],
              colors: [
                heroTint.withValues(alpha: 0),
                heroTint.withValues(alpha: 0),
                heroTint,
                AppColors.background,
              ],
            ),
          ),
        ),
        // d. Dégradé horizontal — contraste pour le texte à gauche (titre,
        // puis résumé sur la partie déjà voilée de l'image).
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: const [0, 0.55],
              colors: [
                AppColors.scrim.withValues(alpha: 0.9),
                AppColors.scrim.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Bloc titre/métadonnées/boutons — posé sur [_BannerBackdrop], pas de
/// calque d'image ou de dégradé propre : le fond vient entièrement de la
/// zone de _BannerBackdrop qui le recouvre (même espace de défilement, cf.
/// le SliverStack de l'appelant).
class _TitleBlock extends StatelessWidget {
  final double minHeight;
  final double maxHeight;
  final Color heroTextSecondary;
  final String title;
  final String? originalTitle;
  final String metaLine;
  final VoidCallback? onPlay;
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
    required this.metaLine,
    required this.onPlay,
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
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: Text(context.localized.playLabel),
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
