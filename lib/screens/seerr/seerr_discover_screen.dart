import 'package:kinos/screens/dashboard/hero_carousel.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinos/models/item_base_model.dart';
import 'package:kinos/models/items/item_shared_models.dart';
import 'package:kinos/models/items/overview_model.dart';
import 'package:kinos/models/seerr/seerr_dashboard_model.dart';
import 'package:kinos/providers/seerr_dashboard_provider.dart';
import 'package:kinos/routes/auto_router.gr.dart';
import 'package:kinos/screens/dashboard/home_hero_section.dart';
import 'package:kinos/screens/seerr/widgets/seerr_poster_row.dart';
import 'package:kinos/screens/shared/chips/filter_button.dart';
import 'package:kinos/screens/shared/media_navigation.dart';
import 'package:kinos/seerr/seerr_models.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/adaptive_layout/adaptive_layout.dart';
import 'package:kinos/util/localization_helper.dart';
import 'package:kinos/widgets/shared/frosted_surface.dart';

final discoverTypeProvider =
    StateProvider.autoDispose<SeerrMediaType?>((ref) => null);

/// Display-only adapter: playback and navigation always use the original poster.
ItemBaseModel discoveryHeroItem(SeerrDashboardPosterModel poster) =>
    ItemBaseModel(
      name: poster.title,
      id: 'discover-${poster.type.name}-${poster.tmdbId}',
      overview: OverviewModel(
          summary: poster.overview,
          yearAired: int.tryParse(poster.releaseYear ?? '')),
      images: poster.images,
      parentId: null,
      playlistId: null,
      childCount: null,
      primaryRatio: null,
      userData: const UserData(),
      canDownload: false,
      canDelete: false,
      jellyType: null,
    );

class SeerrDiscoverScreen extends ConsumerStatefulWidget {
  const SeerrDiscoverScreen({super.key});
  @override
  ConsumerState<SeerrDiscoverScreen> createState() =>
      _SeerrDiscoverScreenState();
}

class _SeerrDiscoverScreenState extends ConsumerState<SeerrDiscoverScreen> {
  bool _loading = true;
  bool _failed = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      await ref.read(seerrDashboardProvider.notifier).fetchDashboard();
    } catch (_) {
      if (mounted) _failed = true;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(seerrDashboardProvider);
    final type = ref.watch(discoverTypeProvider);
    List<SeerrDashboardPosterModel> selected(
            List<SeerrDashboardPosterModel> posters) =>
        posters.where((p) => type == null || p.type == type).toList();
    final candidates = selected(
        [...data.trending, ...data.popularMovies, ...data.popularSeries]);
    final seen = <String>{};
    final posters = candidates
        .where((p) =>
            p.images.backDrop?.isNotEmpty == true &&
            seen.add('${p.type.name}-${p.tmdbId}'))
        .take(8)
        .toList();
    final hero = posters.map(discoveryHeroItem).toList();
    final padding = EdgeInsets.only(
      left: AdaptiveLayout.of(context).sideBarWidth + AppSpacing.screenPadding,
      right: AppSpacing.screenPadding,
    );
    final sections =
        <(String, List<SeerrDashboardPosterModel>, SeerrSearchMode, int?)>[
      (
        context.localized.trending,
        selected(data.trending),
        SeerrSearchMode.trending,
        null
      ),
      if (type != SeerrMediaType.tvshow)
        (
          context.localized.popularMovies,
          data.popularMovies,
          SeerrSearchMode.discoverMovies,
          null
        ),
      if (type != SeerrMediaType.movie)
        (
          context.localized.popularSeries,
          data.popularSeries,
          SeerrSearchMode.discoverTv,
          null
        ),
      if (type != SeerrMediaType.tvshow)
        (
          context.localized.expectedMovies,
          data.expectedMovies,
          SeerrSearchMode.discoverMovies,
          DateTime.now().year
        ),
      if (type != SeerrMediaType.movie)
        (
          context.localized.expectedSeries,
          data.expectedSeries,
          SeerrSearchMode.discoverTv,
          DateTime.now().year
        ),
    ];
    void browse(SeerrSearchMode mode, [int? year]) =>
        context.router.push(SeerrSearchRoute(mode: mode, yearGte: year));
    final toolbar = SliverPadding(
      padding: padding.copyWith(top: AppSpacing.lg, bottom: AppSpacing.lg),
      sliver: SliverToBoxAdapter(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(
          spacing: AppSpacing.lg,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(context.localized.discover,
                style: Theme.of(context).textTheme.headlineMedium),
            FrostedSurface(
              borderRadius: AppRadii.controlBorder,
              child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xxs),
                  child: Wrap(
                    spacing: AppSpacing.xxs,
                    children: [
                      for (final entry in <(String, SeerrMediaType?)>[
                        (context.localized.all, null),
                        (
                          context.localized.mediaTypeMovie(2),
                          SeerrMediaType.movie
                        ),
                        (
                          context.localized.mediaTypeSeries(2),
                          SeerrMediaType.tvshow
                        ),
                      ])
                        FilterButton(
                          isSelected: type == entry.$2,
                          label: Text(entry.$1),
                          onPressed: () => ref
                              .read(discoverTypeProvider.notifier)
                              .state = entry.$2,
                        ),
                    ],
                  )),
            ),
            FilterButton(
              isSelected: false,
              icon: Icons.tune,
              label: Text(context.localized.filter(2)),
              onPressed: () => showDialog<void>(
                  context: context,
                  builder: (context) => GlassDialog(
                        constraints: const BoxConstraints(
                            maxWidth: AppLibraryLayout.searchWidth),
                        child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(context.localized.filter(2),
                                    style:
                                        Theme.of(context).textTheme.titleLarge),
                                const SizedBox(height: AppSpacing.md),
                                for (final entry in [
                                  (
                                    context.localized.mediaTypeMovie(2),
                                    SeerrSearchMode.discoverMovies
                                  ),
                                  (
                                    context.localized.mediaTypeSeries(2),
                                    SeerrSearchMode.discoverTv
                                  )
                                ])
                                  FilterButton(
                                      isSelected: false,
                                      label: Text(entry.$1),
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                        browse(entry.$2);
                                      }),
                              ],
                            )),
                      )),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(context.localized.discoveryShortcuts, style: AppTypography.meta),
      ])),
    );
    return ColoredBox(
      color: AppColors.background,
      child: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          key: const PageStorageKey('discover'),
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (hero.isNotEmpty)
              HomeHeroSection(
                heroItems: hero,
                resumeItems: const [],
                contentPadding: padding,
                footerSliver: toolbar,
                actionsBuilder: (context, item) {
                  final poster =
                      posters[hero.indexWhere((e) => e.id == item.id)];
                  void open() {
                    final libraryItem = poster.itemBaseModel;
                    if (libraryItem != null) {
                      openMediaDetails(context, libraryItem);
                    } else {
                      pushMediaRoute(
                          context,
                          SeerrDetailsRoute(
                            mediaType: poster.type == SeerrMediaType.tvshow
                                ? 'tvshow'
                                : 'movie',
                            tmdbId: poster.tmdbId,
                            poster: poster,
                            tag: MediaNavigationScope.tagOf(context),
                          ));
                    }
                  }

                  return FocusRing(
                    focusNode: MediaNavigationScope.focusOf(context),
                    onActivate: open,
                    borderRadius: AppRadii.controlBorder,
                    child: ExcludeFocus(
                        child: FilledButton.icon(
                      onPressed: open,
                      icon: const Icon(Icons.info_outline),
                      label: Text(context.localized.showDetails),
                    )),
                  );
                },
              )
            else if (_loading)
              SliverToBoxAdapter(
                  child: SizedBox(
                height: (MediaQuery.sizeOf(context).height *
                        AppHeroLayout.viewportHeightFraction)
                    .clamp(HeroCarousel.minHeightFor(context.tokens.density),
                        double.infinity),
                child: const Center(child: CircularProgressIndicator()),
              ))
            else
              const SliverToBoxAdapter(
                  child: SizedBox(height: AppTopNavigation.contentInset)),
            if (hero.isEmpty) toolbar,
            for (final section in sections)
              if (section.$2.isNotEmpty)
                SliverToBoxAdapter(
                    child: SeerrPosterRow(
                  label: section.$1,
                  posters: section.$2,
                  contentPadding: padding,
                  showStatus: true,
                  onLabelClick: () => browse(section.$3, section.$4),
                )),
            if (sections.every((s) => s.$2.isEmpty))
              SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: _loading
                        ? const CircularProgressIndicator()
                        : TextButton(
                            onPressed: _load,
                            child: Text(
                                '${_failed ? context.localized.error : context.localized.noResults} · ${context.localized.refresh}')),
                  )),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
          ],
        ),
      ),
    );
  }
}
