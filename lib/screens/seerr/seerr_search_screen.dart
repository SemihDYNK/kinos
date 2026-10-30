import 'package:kinos/screens/seerr/seerr_discover_screen.dart';
import 'package:flutter/material.dart';

import 'package:auto_route/auto_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import 'package:kinos/models/items/images_models.dart';
import 'package:kinos/models/seerr/seerr_dashboard_model.dart';
import 'package:kinos/providers/seerr_dashboard_provider.dart';
import 'package:kinos/providers/seerr_search_provider.dart';
import 'package:kinos/providers/settings/client_settings_provider.dart';
import 'package:kinos/screens/seerr/widgets/seerr_discover_rows.dart';
import 'package:kinos/screens/seerr/widgets/seerr_filter_chips.dart';
import 'package:kinos/screens/seerr/widgets/seerr_filter_dialogs.dart';
import 'package:kinos/screens/seerr/widgets/seerr_poster_card.dart';
import 'package:kinos/screens/seerr/widgets/seerr_request_popup.dart';
import 'package:kinos/screens/shared/nested_scaffold.dart';
import 'package:kinos/screens/shared/outlined_text_field.dart';
import 'package:kinos/seerr/seerr_models.dart';
import 'package:kinos/util/adaptive_layout/adaptive_layout.dart';
import 'package:kinos/util/debouncer.dart';
import 'package:kinos/util/localization_helper.dart';
import 'package:kinos/util/refresh_state.dart';
import 'package:kinos/util/router_extension.dart';
import 'package:kinos/util/sliver_list_padding.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/text_metrics.dart';
import 'package:kinos/widgets/shared/ensure_visible.dart';
import 'package:kinos/widgets/shared/grid_focus_traveler.dart';
import 'package:kinos/widgets/shared/item_actions.dart';
import 'package:kinos/widgets/shared/pull_to_refresh.dart';

@RoutePage()
class SeerrSearchScreen extends ConsumerStatefulWidget {
  final SeerrSearchMode? mode;
  final int? yearGte;
  const SeerrSearchScreen({
    @QueryParam("mode") this.mode,
    @QueryParam("yearGte") this.yearGte,
    super.key,
  });

  @override
  ConsumerState<SeerrSearchScreen> createState() => _SeerrSearchScreenState();
}

class _SeerrSearchScreenState extends ConsumerState<SeerrSearchScreen> {
  late final TextEditingController controller = TextEditingController();
  final GlobalKey<RefreshIndicatorState> refreshKey =
      GlobalKey<RefreshIndicatorState>();
  final ScrollController scrollController = ScrollController();
  bool _forceSubmitOnRefresh = false;

  final Debouncer debouncer = Debouncer(const Duration(milliseconds: 500));

  List<ImagesData> backgroundImages = [];

  @override
  void initState() {
    super.initState();
    if (widget.mode == null || widget.mode == SeerrSearchMode.search) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final notifier = ref.read(seerrSearchProvider.notifier);
      scrollController.addListener(_onScroll);
      await notifier.init();
      if (!mounted) return;
      if (widget.mode != null) {
        await notifier.setSearchMode(widget.mode!);
      }
      if (!mounted) return;
      if (widget.yearGte != null) {
        await notifier.setYearRange(minYear: widget.yearGte);
      } else {
        await notifier.submit();
      }
      // Rangées de découverte par défaut (mode recherche, aucune requête
      // tapée) : mêmes données que le tableau de bord "Demandes", jamais
      // un écran vide en attendant une saisie — cf. SeerrDiscoverRows.
      if (!mounted) return;
      ref.read(seerrDashboardProvider.notifier).fetchDashboard();

      _maybeTriggerLoadMore();
    });
  }

  void _onScroll() {
    if (!ref.read(seerrSearchProvider).canLoadMore) return;
    if (_isNearBottom(scrollController.position)) {
      refreshKey.currentState?.show();
    }
  }

  bool _isNearBottom(ScrollPosition position) {
    return position.pixels > position.maxScrollExtent * 0.65 ||
        position.extentAfter < position.viewportDimension * 0.2;
  }

  Future<void> _refreshSearch() async {
    final state = ref.read(seerrSearchProvider);
    final notifier = ref.read(seerrSearchProvider.notifier);

    if (_forceSubmitOnRefresh) {
      _forceSubmitOnRefresh = false;
      await notifier.submit();
      return;
    }

    if (scrollController.hasClients && state.canLoadMore) {
      final position = scrollController.position;
      final notScrollable = position.maxScrollExtent <= 0;
      if (notScrollable || _isNearBottom(position)) {
        await notifier.loadMore();
        return;
      }
    }

    await notifier.submit();
  }

  void _triggerSubmitViaRefresh({String? value}) {
    if (!mounted) return;
    final notifier = ref.read(seerrSearchProvider.notifier);
    if (value != null) {
      notifier.setQuery(value);
    }
    _forceSubmitOnRefresh = true;
    refreshKey.currentState?.show();
  }

  void _maybeTriggerLoadMore() {
    if (!mounted) return;
    final state = ref.read(seerrSearchProvider);
    if (!state.canLoadMore) return;
    if (!scrollController.hasClients) return;

    final position = scrollController.position;
    final notScrollable = position.maxScrollExtent <= 0;
    final nearBottom = _isNearBottom(position);

    if (notScrollable || nearBottom) {
      refreshKey.currentState?.show();
    }
  }

  @override
  void dispose() {
    controller.dispose();
    scrollController.dispose();
    super.dispose();
  }

  Future<void> openRequest(
      BuildContext context, SeerrDashboardPosterModel poster) async {
    await openSeerrRequestPopup(context, poster);
    _triggerSubmitViaRefresh();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mode == null || widget.mode == SeerrSearchMode.search) {
      return const SeerrDiscoverScreen();
    }
    final searchState = ref.watch(seerrSearchProvider);

    ref.listen(
      seerrSearchProvider.select((value) => value.query),
      (previous, next) {
        if (controller.text != next) {
          controller.text = next;
        }
      },
    );

    final searchResults = searchState.results;

    if (backgroundImages.isEmpty) {
      backgroundImages =
          searchResults.map((e) => e.images).nonNulls.toList(growable: false);
    }

    final additonalActions = [
      if (searchState.hasFilters)
        ItemActionButton(
          label: Text(context.localized.clear),
          icon: const Icon(IconsaxPlusLinear.filter_remove),
          action: () async {
            ref.read(seerrSearchProvider.notifier).clearFilters();
            await context.refreshData();
          },
        ),
      ItemActionButton(
        label: Text(context.localized.sortBy),
        icon: const Icon(IconsaxPlusLinear.sort),
        action: searchState.isLoading
            ? null
            : () {
                openSortDialog(context, ref.read(seerrSearchProvider.notifier),
                    searchState.filters);
              },
      ),
    ];

    return NestedScaffold(
      background: const ColoredBox(color: AppColors.background),
      body: Padding(
        padding: EdgeInsetsDirectional.only(
            start: AdaptiveLayout.of(context).sideBarWidth),
        child: Scaffold(
          extendBody: true,
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          // Pas de navigation en bas d'écran (règle anti-mobile-first,
          // CLAUDE.md) : tri/filtres vivent uniquement dans la barre
          // d'outils du haut (_SeerSearchScreenAppBar.menuActions).
          body: PullToRefresh(
            refreshOnStart: false,
            refreshKey: refreshKey,
            onRefresh: _refreshSearch,
            child: (context) => CustomScrollView(
              controller: scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                    child: _SeerSearchScreenAppBar(
                  menuActions: additonalActions,
                  searchBar: OutlinedTextField(
                    autoFocus: widget.mode == SeerrSearchMode.search,
                    controller: controller,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (value) =>
                        _triggerSubmitViaRefresh(value: value),
                    onChanged: (value) {
                      ref.read(seerrSearchProvider.notifier).setQuery(value);
                      if (searchState.searchMode == SeerrSearchMode.search) {
                        debouncer.run(() {
                          _triggerSubmitViaRefresh();
                        });
                      }
                    },
                    decoration: InputDecoration(
                      hintText: "${context.localized.search}...",
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                      prefixIcon: const Icon(IconsaxPlusLinear.search_status),
                      border: InputBorder.none,
                    ),
                  ),
                )),
                if (searchResults.isEmpty &&
                    !searchState.isLoading &&
                    searchState.searchMode == SeerrSearchMode.search &&
                    searchState.query.isEmpty &&
                    !searchState.hasFilters)
                  const SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverToBoxAdapter(
                      child: SeerrDiscoverRows(
                        contentPadding: EdgeInsets.symmetric(horizontal: 16),
                      ),
                    ),
                  )
                else if (searchResults.isEmpty && !searchState.isLoading)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Text(context.localized.noResults),
                    ),
                  )
                else ...[
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverLayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.crossAxisExtent;
                        final zoom = ref.watch(clientSettingsProvider
                            .select((value) => value.posterSize));
                        final crossAxisCount =
                            context.tokens.density.columnsFor(width / zoom);
                        final tileWidth = (width -
                                (crossAxisCount - 1) * AppSpacing.gridGap) /
                            crossAxisCount;
                        final tileHeight =
                            tileWidth / AppMedia.posterAspectRatio +
                                measuredLineHeight(context,
                                    Theme.of(context).textTheme.titleMedium) +
                                measuredLineHeight(context,
                                    Theme.of(context).textTheme.titleSmall);
                        return GridFocusTraveler(
                          itemCount: searchResults.length,
                          crossAxisCount: crossAxisCount,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: AppSpacing.gridGap,
                            mainAxisSpacing: AppSpacing.md,
                            mainAxisExtent: tileHeight,
                          ),
                          itemBuilder: (context, selectedIndex, index) {
                            final poster = searchResults[index];
                            return SeerrPosterCard(
                              key: Key(poster.id),
                              poster: poster,
                              imageAspectRatio: AppMedia.posterAspectRatio,
                              onFocusChanged: (value) {
                                if (value) {
                                  context.ensureVisible();
                                }
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
                const DefaultSliverBottomPadding(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SeerSearchScreenAppBar extends StatelessWidget {
  final List<ItemAction> menuActions;
  final Widget searchBar;
  const _SeerSearchScreenAppBar({
    required this.menuActions,
    required this.searchBar,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(
          top: MediaQuery.paddingOf(context).top +
              AppTopNavigation.contentInset +
              AppSpacing.lg,
          left: AppSpacing.screenPadding,
          right: AppSpacing.screenPadding,
          bottom: AppSpacing.lg,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            context.router.backButton() ?? const SizedBox.shrink(),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
                child: Text(context.localized.discover,
                    style: Theme.of(context).textTheme.headlineMedium)),
            ...menuActions.map((action) => action.toButton()),
          ]),
          const SizedBox(height: AppSpacing.md),
          Card(
            color: AppColors.surface,
            elevation: 0,
            shape: const RoundedRectangleBorder(
                borderRadius: AppRadii.controlBorder),
            child: searchBar,
          ),
          const SizedBox(height: AppSpacing.sm),
          const SingleChildScrollView(
              scrollDirection: Axis.horizontal, child: SeerrFilterChips()),
        ]),
      );
}
