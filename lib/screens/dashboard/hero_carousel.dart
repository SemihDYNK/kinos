import 'package:kinos/screens/shared/media_navigation.dart';
import 'package:kinos/widgets/shared/animated_media_icon.dart';
import 'package:kinos/theme/app_icons.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kinos/models/item_base_model.dart';
import 'package:kinos/models/items/images_models.dart';
import 'package:kinos/providers/theme/app_theme_provider.dart';
import 'package:kinos/providers/theme/palette_service_provider.dart';
import 'package:kinos/providers/user_provider.dart';
import 'package:kinos/screens/dashboard/home_hero_backdrop.dart';
import 'package:kinos/screens/shared/media_hero_title.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/theme/palette_service.dart';
import 'package:kinos/util/humanize_duration.dart';
import 'package:kinos/util/item_base_model/play_item_helpers.dart';
import 'package:kinos/util/localization_helper.dart';
import 'package:kinos/util/refresh_state.dart';

/// Carrousel manuel : l'image et la palette suivent la même diapo.
class HeroCarousel extends ConsumerStatefulWidget {
  const HeroCarousel(
      {required this.items,
      this.onCurrentChanged,
      this.actionsBuilder,
      this.contentStart = 0,
      super.key});

  final List<ItemBaseModel> items;
  final ValueChanged<ItemBaseModel>? onCurrentChanged;
  final double contentStart;
  final Widget Function(BuildContext context, ItemBaseModel item)?
      actionsBuilder;

  static double minHeightFor(AppDensity density) => density == AppDensity.couch
      ? AppHeroLayout.couchHeight
      : AppHeroLayout.minHeight;

  @override
  ConsumerState<HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends ConsumerState<HeroCarousel>
    with SingleTickerProviderStateMixin {
  int _index = 0;
  ItemBaseModel? _paletteItem;
  late final _revealController = AnimationController(
      vsync: this, value: 1, duration: AppDurations.heroSlide);
  final Set<String> _favouriteOverrides = {};
  late final StateController<HeroPalette> _palette;

  ItemBaseModel get _current =>
      widget.items[_index.clamp(0, widget.items.length - 1)];

  @override
  void initState() {
    super.initState();
    _palette = ref.read(heroPaletteProvider.notifier);
    _schedulePalette();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_revealController.isAnimating && !AppMotion.enabled(context)) {
      _revealController.value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant HeroCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previousId = oldWidget.items.isEmpty
        ? null
        : oldWidget.items[_index.clamp(0, oldWidget.items.length - 1)].id;
    if (_index >= widget.items.length) _index = 0;
    if (previousId != null &&
        widget.items.isNotEmpty &&
        previousId != _current.id) {
      _restartReveal();
    }
    _schedulePalette();
  }

  @override
  void dispose() {
    _revealController.dispose();
    final previous = _palette.state;
    scheduleMicrotask(() {
      if (_palette.mounted && identical(_palette.state, previous)) {
        _palette.state = HeroPalette.fallback;
      }
    });
    super.dispose();
  }

  void _schedulePalette() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updatePalette();
    });
  }

  Future<void> _updatePalette() async {
    if (widget.items.isEmpty) {
      _paletteItem = null;
      _palette.state = HeroPalette.fallback;
      return;
    }
    final item = _current;
    if (identical(item, _paletteItem)) return;
    _paletteItem = item;
    final image = _imageFor(item);
    widget.onCurrentChanged?.call(item);
    _precacheNeighbourArtwork();
    if (image == null) {
      _palette.state = HeroPalette.fallback;
      return;
    }
    final palette = await ref.read(paletteServiceProvider).forItem(
          itemId: item.id,
          image: image.imageProvider,
        );
    if (!mounted || !identical(_paletteItem, item)) return;
    _palette.state = palette;
  }

  void _go(int delta) {
    if (widget.items.length < 2) return;
    setState(() => _index = (_index + delta) % widget.items.length);
    _restartReveal();
    _updatePalette();
  }

  void _precacheNeighbourArtwork() {
    if (widget.items.length < 2) return;
    for (final index in {
      (_index - 1) % widget.items.length,
      (_index + 1) % widget.items.length
    }) {
      final neighbour = widget.items[index];
      final logo = neighbour.tvPosterLogo;
      for (final image in [
        _imageFor(neighbour),
        if (logo?.key.endsWith('_logo_null') != true) logo,
      ]) {
        if (image == null || image.path.isEmpty) continue;
        unawaited(
            precacheImage(image.imageProvider, context, onError: (_, __) {}));
      }
    }
  }

  void _restartReveal() {
    if (AppMotion.enabled(context)) {
      _revealController.forward(from: 0);
    } else {
      _revealController.value = 1;
    }
  }

  Widget _reveal(Widget child, Interval interval, String role) =>
      AnimatedBuilder(
          animation: _revealController,
          child: child,
          builder: (_, child) {
            final progress = interval.transform(_revealController.value);
            return Opacity(
                key: ValueKey(role),
                opacity: progress,
                child: Transform.translate(
                    offset:
                        Offset(0, AppMotion.heroTextTravel * (1 - progress)),
                    child: child));
          });

  ImageData? _imageFor(ItemBaseModel item) =>
      item.getPosters?.backDrop?.firstOrNull ??
      item.getPosters?.primary ??
      item.getPosters?.thumb;

  bool _isFavourite(ItemBaseModel item) => _favouriteOverrides.contains(item.id)
      ? !item.userData.isFavourite
      : item.userData.isFavourite;

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

  String _metaLine(ItemBaseModel item) => [
        item.overview.yearAired?.toString(),
        item.overview.genreItems.firstOrNull?.name ??
            item.overview.genres.firstOrNull,
        item.overview.runTime?.humanize,
      ].nonNulls.join(' · ');

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    final item = _current;
    final density = context.tokens.density;
    final secondary =
        AppColors.textPrimary.withValues(alpha: AppHeroLayout.secondaryOpacity);
    return MediaNavigation(
        previewImage: _imageFor(item),
        builder: (context) => LayoutBuilder(builder: (context, constraints) {
              final contentWidth = constraints.maxWidth - widget.contentStart;
              final textWidth = contentWidth *
                  (contentWidth < AppHeroLayout.narrowWidth
                      ? AppHeroLayout.narrowTextWidthFraction
                      : AppHeroLayout.textWidthFraction);
              return ConstrainedBox(
                constraints: BoxConstraints(
                    minHeight: (MediaQuery.sizeOf(context).height *
                            AppHeroLayout.viewportHeightFraction)
                        .clamp(HeroCarousel.minHeightFor(density),
                            double.infinity)),
                child: Stack(alignment: Alignment.bottomLeft, children: [
                  Positioned.fill(
                      child: MediaArtwork(
                          child: HomeHeroBackdrop(image: _imageFor(item)))),
                  Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(
                        widget.contentStart + AppSpacing.screenPadding,
                        AppSpacing.xxl,
                        AppSpacing.screenPadding,
                        AppHeroLayout.titleBottomSpace),
                    child: SizedBox(
                        width: textWidth,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _reveal(
                                MediaArtwork(
                                    title: true,
                                    child: MediaHeroTitle(
                                        title: item.title,
                                        logo: item.tvPosterLogo,
                                        availableWidth: contentWidth)),
                                AppMotion.heroTitleReveal,
                                'hero-title-reveal'),
                            const SizedBox(height: AppSpacing.md),
                            _reveal(
                                Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(_metaLine(item),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(color: secondary)),
                                      if (item.overview.summary.isNotEmpty) ...[
                                        const SizedBox(height: AppSpacing.sm),
                                        ConstrainedBox(
                                            constraints: const BoxConstraints(
                                                maxWidth: AppHeroLayout
                                                    .synopsisWidth),
                                            child: Text(item.overview.summary,
                                                maxLines: 3,
                                                overflow: TextOverflow.ellipsis,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.copyWith(
                                                        color: AppColors
                                                            .textPrimary))),
                                      ],
                                    ]),
                                AppMotion.heroSynopsisReveal,
                                'hero-synopsis-reveal'),
                            const SizedBox(height: AppSpacing.lg),
                            widget.actionsBuilder?.call(context, item) ??
                                Wrap(
                                    spacing: AppSpacing.sm,
                                    runSpacing: AppSpacing.xs,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      FocusRing(
                                          borderRadius: AppRadii.controlBorder,
                                          onActivate: () =>
                                              item.play(context, ref),
                                          child: ExcludeFocus(
                                              child: FilledButton.icon(
                                                  onPressed: () =>
                                                      item.play(context, ref),
                                                  icon:
                                                      const Icon(AppIcons.play),
                                                  label: Text(context
                                                      .localized.playLabel)))),
                                      FocusRing(
                                          focusNode:
                                              MediaNavigationScope.focusOf(
                                                  context),
                                          borderRadius: AppRadii.controlBorder,
                                          onActivate: () =>
                                              openMediaDetails(context, item),
                                          child: ExcludeFocus(
                                              child: OutlinedButton.icon(
                                                  onPressed: () =>
                                                      openMediaDetails(
                                                          context, item),
                                                  icon: const Icon(
                                                      Icons.info_outline),
                                                  label: Text(context.localized
                                                      .showDetails)))),
                                      FocusRing(
                                          borderRadius: AppRadii.controlBorder,
                                          onActivate: () =>
                                              _toggleFavourite(item),
                                          child: ExcludeFocus(
                                              child: IconButton.outlined(
                                                  tooltip: context
                                                      .localized.favorite,
                                                  onPressed: () =>
                                                      _toggleFavourite(item),
                                                  icon: AnimatedFavouriteIcon(
                                                      selected: _isFavourite(
                                                          item))))),
                                    ]),
                          ],
                        )),
                  ),
                  if (widget.items.length > 1)
                    PositionedDirectional(
                        end: AppSpacing.screenPadding,
                        bottom: AppSpacing.md,
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          _arrow(
                              context,
                              Icons.chevron_left_rounded,
                              -1,
                              MaterialLocalizations.of(context)
                                  .previousPageTooltip),
                          Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm),
                              child: Text(
                                  '${_index + 1} / ${widget.items.length}',
                                  style: AppTypography.meta
                                      .copyWith(color: AppColors.textPrimary))),
                          _arrow(
                              context,
                              Icons.chevron_right_rounded,
                              1,
                              MaterialLocalizations.of(context)
                                  .nextPageTooltip),
                        ])),
                ]),
              );
            }));
  }

  Widget _arrow(BuildContext context, IconData icon, int delta, String label) =>
      FocusRing(
          borderRadius: AppRadii.controlBorder,
          onActivate: () => _go(delta),
          child: ExcludeFocus(
              child: IconButton(
                  tooltip: label,
                  onPressed: () => _go(delta),
                  icon: Icon(icon))));
}
