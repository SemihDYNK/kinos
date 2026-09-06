import 'package:flutter/material.dart';

import 'package:auto_route/auto_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  /// Affiche (jaquette Primary) posée à cheval sur le bandeau et le corps
  /// — null si aucune n'est disponible (le titre reprend alors toute la
  /// largeur du bandeau, sans décalage).
  final ImageData? poster;

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
    this.poster,
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

  /// Teinte extraite de la même image que celle affichée dans le bandeau
  /// (le backdrop, pas la jaquette) — cohérent avec le tableau de bord.
  Future<void> _updateHeroPalette() async {
    final image = widget.backDrops?.randomBackDrop ?? widget.backDrops?.primary;
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
    // Hauteur minimale, extensible (cf. le bandeau du tableau de bord) :
    // 480/560 selon densité, jusqu'à +80 si le titre (2 lignes) le demande.
    final minBannerHeight = density == AppDensity.couch ? 560.0 : 480.0;
    final maxBannerHeight = minBannerHeight + 80;
    final sideBarInset = AdaptiveLayout.of(context).sideBarWidth;
    // Même alignement que le tableau de bord : AppSpacing.screenPadding.
    // Contrairement à `dashboard_screen.dart`, le corps de cet écran (résumé,
    // casting, recommandations...) n'est PAS imbriqué dans un sliver déjà
    // décalé de sideBarInset — il lui faut donc le padding complet, pas
    // `innerPadding` (qui le retranche). L'oubli de cette distinction est
    // ce qui faisait passer tout le contenu sous la barre latérale.
    final padding = AdaptiveLayout.adaptivePadding(context,
        horizontalPadding: AppSpacing.screenPadding);
    final heroTint = context.tokens.heroTint;
    final heroTextSecondary = context.tokens.heroTextSecondary;
    final image = widget.backDrops?.randomBackDrop ?? widget.backDrops?.primary;
    final hasActions = widget.actions != null;

    // Affiche à cheval sur le bandeau et le corps : 40% de sa hauteur dans
    // le bandeau, 60% dessous. Le bloc titre se décale d'autant à droite
    // (cf. _Banner.posterInset) ; le contenu (résumé, etc.) s'aligne déjà
    // sur ce même bord gauche via `padding`, sans changement nécessaire.
    final hasPoster = widget.poster != null;
    final posterWidth = density == AppDensity.couch ? 260.0 : 200.0;
    final posterHeight = posterWidth * 3 / 2;
    // bottom: -posterBelowBanner avec une hauteur de posterHeight place le
    // haut de l'affiche à (posterHeight - posterBelowBanner) = 40% de sa
    // hauteur au-dessus du bord bas du bandeau — le reste (60%) déborde.
    final posterBelowBanner = posterHeight * 0.6;
    // Occupe l'espace du fondu au lieu d'une marge vide séparée : juste ce
    // qu'il faut pour que l'affiche ait la place de déborder, plus un peu
    // d'air avant le résumé.
    final bleedHeight = hasPoster ? posterBelowBanner + AppSpacing.lg : 120.0;
    final tintHoldFraction =
        (minBannerHeight / (minBannerHeight + bleedHeight)).clamp(0.0, 1.0);

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
                // Bandeau + résorption de la teinte : même mécanique que
                // dashboard_screen.dart — SliverPadding(start: sideBarInset)
                // pour ne jamais teindre sous la barre latérale. Le bandeau
                // fond lui-même dans la teinte à son propre bord bas (cf.
                // _Banner, calque c bis) ; le dégradé ci-dessous prend le
                // relais en pleine teinte à ce même point, puis s'étire sur
                // la marge de sortie (juste assez pour l'affiche, cf.
                // bleedHeight) avant de s'éteindre — fondu long, sans ligne
                // de coupure. tintHoldFraction est une approximation : le
                // bandeau est à hauteur minimale extensible, sa hauteur
                // réelle n'est pas connue ici : viser un peu court plutôt
                // qu'un peu long n'a pas d'incidence visible, les deux
                // calques sont alors déjà la même teinte.
                SliverPadding(
                  padding: EdgeInsetsDirectional.only(start: sideBarInset),
                  sliver: DecoratedSliver(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0, tintHoldFraction, 1],
                        colors: [heroTint, heroTint, AppColors.background],
                      ),
                    ),
                    sliver: SliverMainAxisGroup(
                      slivers: [
                        SliverToBoxAdapter(
                          // clipBehavior.none : l'affiche déborde
                          // volontairement sous le bandeau (point 2) — rien
                          // d'opaque ne la recouvre dans la marge de sortie
                          // ci-dessous, elle reste visible par-dessus.
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              _Banner(
                                minHeight: minBannerHeight,
                                maxHeight: maxBannerHeight,
                                image: image,
                                heroTint: heroTint,
                                heroTextSecondary: heroTextSecondary,
                                posterInset:
                                    hasPoster ? posterWidth + AppSpacing.lg : 0,
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
                              if (hasPoster)
                                Positioned(
                                  left: AppSpacing.screenPadding,
                                  bottom: -posterBelowBanner,
                                  width: posterWidth,
                                  height: posterHeight,
                                  child: _PosterCard(image: widget.poster),
                                ),
                            ],
                          ),
                        ),
                        SliverToBoxAdapter(
                            child: SizedBox(height: bleedHeight)),
                      ],
                    ),
                  ),
                ),
                ...widget.content(context, padding),
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

class _Banner extends StatelessWidget {
  final double minHeight;
  final double maxHeight;
  final ImageData? image;
  final Color heroTint;
  final Color heroTextSecondary;

  /// Espace réservé à gauche pour l'affiche qui déborde par-dessus (0 si
  /// aucune) — le bloc de texte s'en décale d'autant.
  final double posterInset;
  final String title;
  final String? originalTitle;
  final String metaLine;
  final VoidCallback? onPlay;
  final bool isFavourite;
  final VoidCallback? onToggleFavourite;
  final bool isPlayed;
  final VoidCallback? onTogglePlayed;
  final VoidCallback? onMore;

  const _Banner({
    required this.minHeight,
    required this.maxHeight,
    required this.image,
    required this.heroTint,
    required this.heroTextSecondary,
    required this.posterInset,
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

    return ClipRect(
      // Hauteur minimale, extensible si le titre (2 lignes max) le demande —
      // même mécanique de dimensionnement que le bandeau du tableau de bord
      // (le Column non positionné pilote la taille du Stack, les calques de
      // fond suivent en Positioned.fill).
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight, maxHeight: maxHeight),
        child: Stack(
          alignment: Alignment.bottomLeft,
          children: [
            // a. Fond teinté — visible au chargement et sur les bords.
            Positioned.fill(child: ColoredBox(color: heroTint)),
            // b. Backdrop plein cadre, cover.
            Positioned.fill(
                child: FladderImage(image: image, fit: BoxFit.cover)),
            // c. Fondu vers la teinte en bas de l'image : elle se fond
            // directement dans le fond teinté, pas de bord net entre
            // l'image et la teinte qui déborde ensuite sous le bandeau.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    stops: const [0, 0.35],
                    colors: [heroTint, heroTint.withValues(alpha: 0)],
                  ),
                ),
              ),
            ),
            // d. Dégradé horizontal — contraste pour le texte à gauche.
            Positioned.fill(
              child: DecoratedBox(
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
            ),
            // e. Dégradé vertical — contraste pour le texte en bas.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    stops: const [0, 0.45],
                    colors: [
                      AppColors.scrim.withValues(alpha: 0.75),
                      AppColors.scrim.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            // f. Bloc de texte, aligné en bas à gauche sur screenPadding
            // (+ posterInset s'il y a une affiche à côté) — seul enfant non
            // positionné : c'est lui qui pilote la hauteur du Stack entre
            // minHeight et maxHeight.
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(
                AppSpacing.screenPadding + posterInset,
                AppSpacing.screenPadding,
                AppSpacing.screenPadding,
                AppSpacing.screenPadding,
              ),
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
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                AppColors.textPrimary.withValues(alpha: 0.55)),
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
      ),
    );
  }
}

/// Affiche à cheval sur le bandeau et le corps. "Élévation par la valeur,
/// jamais par l'ombre" (cf. CLAUDE.md) : pas de BoxShadow, juste un liseré
/// pour la détacher des deux fonds très proches (teinte, puis background)
/// sur lesquels elle se pose.
class _PosterCard extends StatelessWidget {
  final ImageData? image;

  const _PosterCard({required this.image});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: AppRadii.cardBorder,
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: ClipRRect(
        borderRadius: AppRadii.cardBorder,
        child: FladderImage(image: image, fit: BoxFit.cover),
      ),
    );
  }
}
