import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fladder/models/item_base_model.dart';
import 'package:fladder/providers/theme/app_theme_provider.dart';
import 'package:fladder/providers/theme/palette_service_provider.dart';
import 'package:fladder/providers/user_provider.dart';
import 'package:fladder/theme/app_theme.dart';
import 'package:fladder/theme/palette_service.dart';
import 'package:fladder/util/adaptive_layout/adaptive_layout.dart';
import 'package:fladder/util/humanize_duration.dart';
import 'package:fladder/util/item_base_model/play_item_helpers.dart';
import 'package:fladder/util/refresh_state.dart';

/// Bandeau carrousel du tableau de bord.
///
/// Un seul item affiché à la fois (fondu croisé entre les diapos), fond
/// [AppColors] teinté par [heroPaletteProvider] via [context.tokens].
/// Défilement manuel uniquement — aucune rotation automatique.
class HeroCarousel extends ConsumerStatefulWidget {
  /// Films et séries non vus, déjà filtrés et limités par l'appelant.
  final List<ItemBaseModel> items;

  /// Appelé à chaque changement de diapo (y compris la première, au
  /// montage) — permet à l'appelant de poser un fond ([FadingHeroBackdrop])
  /// qui suit la même image, sans dupliquer l'état de rotation ici et là.
  final ValueChanged<ItemBaseModel>? onCurrentChanged;

  const HeroCarousel({required this.items, this.onCurrentChanged, super.key});

  /// Hauteur minimale, extensible (cf. [_HeroCarouselState.build]) — publiée
  /// pour que l'appelant (dashboard_screen.dart) puisse dimensionner son
  /// propre fond ([FadingHeroBackdrop]) sur la même base, sans dupliquer
  /// ces valeurs.
  ///
  /// 560/640 (desk/couch) — même raisonnement que le bandeau film/série
  /// (480 -> 680) : sur une largeur de contenu large (~1880px), un cadre
  /// bas donne un ratio très éloigné du 16:9 des images sources, que
  /// BoxFit.cover doit combler en agrandissant (et donc en rognant)
  /// massivement l'image. Un cadre plus haut rapproche ce ratio du 16:9,
  /// pour un recadrage bien moins agressif — indépendant de la hauteur de
  /// la zone de fondu ([FadingHeroBackdrop], dimensionnée séparément par
  /// l'appelant).
  static double minHeightFor(AppDensity density) =>
      density == AppDensity.couch ? 640.0 : 560.0;
  static double maxHeightFor(AppDensity density) =>
      density == AppDensity.couch ? 720.0 : 640.0;

  @override
  ConsumerState<HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends ConsumerState<HeroCarousel> {
  int _index = 0;
  bool _hovering = false;

  ItemBaseModel? _lastPaletteItem;
  final Set<String> _favouriteOverrides = {};

  ItemBaseModel get _current =>
      widget.items[_index.clamp(0, widget.items.length - 1)];

  bool _isFavourite(ItemBaseModel item) => _favouriteOverrides.contains(item.id)
      ? !item.userData.isFavourite
      : item.userData.isFavourite;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateHeroPalette());
  }

  @override
  void didUpdateWidget(covariant HeroCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.items.isEmpty) return;
    if (_index >= widget.items.length) _index = 0;
    _updateHeroPalette();
  }

  @override
  void dispose() {
    // Le bandeau est propre à cet écran : ne pas laisser sa teinte
    // déteindre sur ce qui s'affiche ensuite.
    ref.read(heroPaletteProvider.notifier).state = HeroPalette.fallback;
    super.dispose();
  }

  Future<void> _updateHeroPalette() async {
    if (widget.items.isEmpty) return;
    final item = _current;
    if (identical(item, _lastPaletteItem)) return;
    _lastPaletteItem = item;
    // Synchrone, avant le calcul de palette (asynchrone) : le fond doit
    // amorcer son fondu vers la nouvelle image immédiatement, pas attendre
    // que sa teinte soit connue.
    widget.onCurrentChanged?.call(item);

    final image = item.getPosters?.randomBackDrop ?? item.getPosters?.primary;
    if (image == null) return;

    final palette = await ref.read(paletteServiceProvider).forItem(
          itemId: item.id,
          image: image.imageProvider,
        );

    if (!mounted || !identical(_lastPaletteItem, item)) return;
    ref.read(heroPaletteProvider.notifier).state = palette;
  }

  void _go(int delta) {
    if (widget.items.length < 2) return;
    setState(() {
      _index = (_index + delta) % widget.items.length;
      if (_index < 0) _index += widget.items.length;
    });
    _updateHeroPalette();
  }

  Future<void> _toggleFavourite(ItemBaseModel item) async {
    setState(() => _favouriteOverrides.contains(item.id)
        ? _favouriteOverrides.remove(item.id)
        : _favouriteOverrides.add(item.id));
    try {
      await ref
          .read(userProvider.notifier)
          .setAsFavorite(_isFavourite(item), item.id);
    } finally {
      if (mounted) context.refreshData();
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowLeft:
        _go(-1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowRight:
        _go(1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        Actions.maybeInvoke<DirectionalFocusIntent>(
            context, const DirectionalFocusIntent(TraversalDirection.up));
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowDown:
        Actions.maybeInvoke<DirectionalFocusIntent>(
            context, const DirectionalFocusIntent(TraversalDirection.down));
        return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  String _metaLine(ItemBaseModel item) {
    final parts = [
      item.overview.productionYear?.toString(),
      item.overview.runTime?.humanize,
      item.streamModel?.resolution?.value,
      item.overview.genreItems.firstOrNull?.name,
    ].nonNulls.toList();
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    final density = context.tokens.density;
    final minHeight = HeroCarousel.minHeightFor(density);
    final maxHeight = HeroCarousel.maxHeightFor(density);
    final item = _current;
    final isDpad = AdaptiveLayout.inputDeviceOf(context) == InputDevice.dPad;
    final heroTextSecondary = context.tokens.heroTextSecondary;

    return Focus(
      // Observateur pur : n'est jamais lui-même une étape de tabulation,
      // il intercepte juste les flèches quand le focus est sur un enfant.
      canRequestFocus: false,
      onKeyEvent: _handleKeyEvent,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: ClipRRect(
          // Bandeau plein cadre, jusqu'aux bords de la zone de contenu :
          // pas de coins arrondis, contrairement aux cartes de jaquettes.
          borderRadius: BorderRadius.zero,
          child: ConstrainedBox(
            // Hauteur minimale, extensible si le titre (2 lignes max) le
            // demande — jamais de débordement : le contenu pilote la
            // hauteur du Stack (enfant non positionné), les calques de
            // fond suivent en Positioned.fill.
            constraints:
                BoxConstraints(minHeight: minHeight, maxHeight: maxHeight),
            child: Stack(
              alignment: Alignment.bottomLeft,
              children: [
                // Fond (image, teinte, dégradés de lisibilité horizontal ET
                // vertical) : plus ici — posé par [FadingHeroBackdrop],
                // derrière ce carrousel ET "Continuer à regarder", dans le
                // même espace de défilement (cf. dashboard_screen.dart),
                // avec `holdUntil` réglé sur la hauteur de ce carrousel :
                // l'image (et ses dégradés) reste pleinement nette et
                // visible sur toute cette hauteur, exactement comme si elle
                // était peinte ici. Ce Stack ne porte donc plus que le
                // texte et les contrôles, sur fond transparent.
                //
                // Flou local derrière le texte : abandonné. Sans moyen de
                // vérifier visuellement le rendu ici (pas d'affichage dans
                // cet environnement), le risque d'un bord de flou visible
                // est trop élevé — les dégradés de FadingHeroBackdrop
                // suffisent au contraste. Cf. consigne : mieux vaut
                // l'absence de flou qu'un rectangle net.
                //
                // Bloc de texte.
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.screenPadding),
                  child: FractionallySizedBox(
                    widthFactor: 0.48,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // letterSpacing positif (AppTypography.overline,
                        // 0.96) : Flutter le distribue de part et d'autre de
                        // chaque glyphe, y compris avant le premier — sans
                        // compensation, son bord gauche mord sur le cadre du
                        // texte et se fait rogner par le ClipRRect du
                        // bandeau. Aucun souci sur le titre juste en dessous
                        // (displayLarge, letterSpacing négatif). Un padding
                        // de gauche à moitié de la valeur restitue le glyphe
                        // en entier sans décaler visiblement le sur-titre.
                        Padding(
                          padding: EdgeInsetsDirectional.only(
                            start:
                                (AppTypography.overline.letterSpacing ?? 0) / 2,
                          ),
                          child: Text(
                            'à voir',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: heroTextSecondary),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .displayLarge
                              ?.copyWith(color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          _metaLine(item),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: heroTextSecondary),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FocusRing(
                              autofocus: isDpad,
                              onActivate: () => item.play(context, ref),
                              child: ExcludeFocus(
                                child: FilledButton.icon(
                                  onPressed: () => item.play(context, ref),
                                  icon: const Icon(Icons.play_arrow_rounded),
                                  label: const Text('Lire'),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            FocusRing(
                              borderRadius: AppRadii.controlBorder,
                              onActivate: () => item.navigateTo(context),
                              child: ExcludeFocus(
                                child: IconButton.outlined(
                                  onPressed: () => item.navigateTo(context),
                                  icon: const Icon(Icons.info_outline),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xxs),
                            FocusRing(
                              borderRadius: AppRadii.controlBorder,
                              onActivate: () => _toggleFavourite(item),
                              child: ExcludeFocus(
                                child: IconButton.outlined(
                                  onPressed: () => _toggleFavourite(item),
                                  icon: Icon(
                                    _isFavourite(item)
                                        ? Icons.favorite_rounded
                                        : Icons.favorite_border_rounded,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (widget.items.length > 1) ...[
                  _HoverArrow(
                    alignment: Alignment.centerLeft,
                    visible: _hovering,
                    icon: Icons.chevron_left_rounded,
                    onTap: () => _go(-1),
                  ),
                  _HoverArrow(
                    alignment: Alignment.centerRight,
                    visible: _hovering,
                    icon: Icons.chevron_right_rounded,
                    onTap: () => _go(1),
                  ),
                  Positioned(
                    right: AppSpacing.md,
                    bottom: AppSpacing.sm,
                    child: _PaginationDots(
                      count: widget.items.length,
                      index: _index,
                      onSelect: (i) {
                        setState(() => _index = i);
                        _updateHeroPalette();
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HoverArrow extends StatelessWidget {
  final Alignment alignment;
  final bool visible;
  final IconData icon;
  final VoidCallback onTap;

  const _HoverArrow({
    required this.alignment,
    required this.visible,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        child: AnimatedOpacity(
          duration: AppDurations.hover,
          opacity: visible ? 1 : 0,
          child: IgnorePointer(
            ignoring: !visible,
            child: MaybeExcludeFocus(
              excluding: !visible,
              child: FocusRing(
                borderRadius: AppRadii.controlBorder,
                onActivate: onTap,
                child: ExcludeFocus(
                  child: IconButton.filledTonal(
                    onPressed: onTap,
                    icon: Icon(icon),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// [ExcludeFocus] dont l'exclusion est conditionnelle — les flèches ne
/// doivent pas être une étape de tabulation tant qu'elles sont masquées.
class MaybeExcludeFocus extends StatelessWidget {
  final bool excluding;
  final Widget child;

  const MaybeExcludeFocus(
      {required this.excluding, required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return ExcludeFocus(excluding: excluding, child: child);
  }
}

class _PaginationDots extends StatelessWidget {
  final int count;
  final int index;
  final ValueChanged<int> onSelect;

  const _PaginationDots(
      {required this.count, required this.index, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) {
        final selected = i == index;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: FocusRing(
            borderRadius: BorderRadius.circular(99),
            onActivate: () => onSelect(i),
            child: AnimatedContainer(
              duration: AppDurations.hover,
              width: selected ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: AppColors.textPrimary
                    .withValues(alpha: selected ? 0.9 : 0.4),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        );
      }),
    );
  }
}
