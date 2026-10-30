import 'package:kinos/widgets/shared/frosted_surface.dart';
import 'package:kinos/widgets/shared/poster_size_slider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kinos/theme/app_theme.dart';

import 'package:auto_route/auto_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import 'package:kinos/jellyfin/jellyfin_open_api.enums.swagger.dart';
import 'package:kinos/models/boxset_model.dart';
import 'package:kinos/models/item_base_model.dart';
import 'package:kinos/models/items/item_shared_models.dart';
import 'package:kinos/models/items/playlist_model.dart';
import 'package:kinos/models/library_filter_model.dart';
import 'package:kinos/models/library_search/library_search_model.dart';
import 'package:kinos/models/library_search/library_search_options.dart';
import 'package:kinos/providers/library_search_provider.dart';
import 'package:kinos/providers/settings/client_settings_provider.dart';
import 'package:kinos/routes/auto_router.gr.dart';
import 'package:kinos/screens/collections/add_to_collection.dart';
import 'package:kinos/screens/library_search/widgets/library_filter_chips.dart';
import 'package:kinos/screens/library_search/widgets/library_play_options_.dart';
import 'package:kinos/screens/library_search/widgets/library_saved_filters.dart';
import 'package:kinos/screens/library_search/widgets/library_sort_dialogue.dart';
import 'package:kinos/screens/library_search/widgets/library_views.dart';
import 'package:kinos/screens/library_search/widgets/suggestion_search_bar.dart';
import 'package:kinos/screens/playlists/add_to_playlists.dart';
import 'package:kinos/screens/shared/nested_scaffold.dart';
import 'package:kinos/util/adaptive_layout/adaptive_layout.dart';
import 'package:kinos/util/debouncer.dart';
import 'package:kinos/util/item_base_model/item_base_model_extensions.dart';
import 'package:kinos/util/list_padding.dart';
import 'package:kinos/util/localization_helper.dart';
import 'package:kinos/util/map_bool_helper.dart';
import 'package:kinos/util/refresh_state.dart';
import 'package:kinos/widgets/shared/kinos_scrollbar.dart';
import 'package:kinos/widgets/shared/item_actions.dart';
import 'package:kinos/widgets/shared/pinch_poster_zoom.dart';
import 'package:kinos/widgets/shared/pull_to_refresh.dart';

@RoutePage()
class LibrarySearchScreen extends ConsumerStatefulWidget {
  final String? query;
  final List<String>? parentId;
  final bool? favourites;
  final SortingOrder? sortOrder;
  final SortingOptions? sortingOptions;
  final Map<KinosItemType, bool>? types;
  final Map<String, bool>? genres;
  final Map<Studio, bool>? studios;
  final Map<ItemFilter, bool>? itemFilters;
  final Map<String, bool>? tags;
  final Map<int, bool>? years;
  final bool? recursive;
  final bool? isDefault;
  const LibrarySearchScreen({
    @QueryParam("query") this.query,
    @QueryParam("parentId") this.parentId,
    @QueryParam("favourites") this.favourites,
    @QueryParam("sortOrder") this.sortOrder,
    @QueryParam("sortOptions") this.sortingOptions,
    @QueryParam("itemTypes") this.types,
    @QueryParam("genres") this.genres,
    @QueryParam("studios") this.studios,
    @QueryParam("itemFilters") this.itemFilters,
    @QueryParam("tags") this.tags,
    @QueryParam("years") this.years,
    @QueryParam("recursive") this.recursive,
    @QueryParam("isDefault") this.isDefault,
    super.key,
  });

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _LibrarySearchScreenState();
}

class _LibrarySearchScreenState extends ConsumerState<LibrarySearchScreen> {
  final Debouncer debouncer = Debouncer(const Duration(seconds: 1));
  final GlobalKey<RefreshIndicatorState> refreshKey =
      GlobalKey<RefreshIndicatorState>();
  final ScrollController scrollController = ScrollController();
  late double lastScale = 0;

  bool loadOnStart = false;

  /// Identifie la DESTINATION de cette recherche (dossier/vue parcouru,
  /// ou filtres de départ posés par l'appelant — ex. "Films" pousse
  /// `types: {movie: true}`, "Séries" pousse `types: {series: true}`),
  /// pas son état vivant : `LibrarySearchRoute` sert aussi bien à
  /// "Recherche", "Films" et "Séries" (barre latérale) qu'à "Favoris" ou
  /// à une ligne de genre du tableau de bord — toutes vers la même
  /// route, seuls les paramètres de requête diffèrent. Sans eux dans la
  /// clé, ces destinations partagent le même [librarySearchProvider] et
  /// donc le même état de filtres (cocher "Série" dans l'une le coche
  /// dans les trois). Ne PAS y inclure les champs que l'écran modifie
  /// lui-même après coup (tri, recherche texte en direct...) : eux
  /// doivent rester dans l'état vivant du provider, pas re-fragmenter
  /// l'instance à chaque frappe.
  Key get uniqueKey {
    String mapSignature<K>(Map<K, bool>? map, String Function(K) keyToString) {
      if (map == null) return '';
      final activeKeys = map.entries
          .where((e) => e.value)
          .map((e) => keyToString(e.key))
          .toList()
        ..sort();
      return activeKeys.join(',');
    }

    final signature = [
      widget.parentId?.join(','),
      widget.favourites?.toString(),
      mapSignature(widget.types, (type) => type.name),
      mapSignature(widget.genres, (genre) => genre),
      mapSignature(widget.studios, (studio) => studio.id),
      mapSignature(widget.itemFilters, (filter) => filter.name),
      mapSignature(widget.tags, (tag) => tag),
      mapSignature(widget.years, (year) => year.toString()),
    ].where((part) => part != null && part.isNotEmpty).join('|');

    return Key(signature.isEmpty ? "EmptySearch" : signature);
  }

  StateNotifierProvider<LibrarySearchNotifier, LibrarySearchModel>
      get providerKey => librarySearchProvider(uniqueKey);
  LibrarySearchNotifier get libraryProvider =>
      ref.read(librarySearchProvider(uniqueKey).notifier);

  @override
  void didUpdateWidget(covariant LibrarySearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (kIsWeb && ref.read(librarySearchProvider(uniqueKey)).posters.isEmpty) {
      initLibrary();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((value) {
      initLibrary();
    });
  }

  Future<void> initLibrary() async {
    await refreshKey.currentState?.show();
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: [],
    );
    scrollController.addListener(() {
      scrollPosition();
    });
  }

  void scrollPosition() {
    if (scrollController.position.pixels >
        scrollController.position.maxScrollExtent * 0.65) {
      libraryProvider.loadMore();
    }
  }

  Future<void> refreshSearch() async {
    await refreshKey.currentState?.show();
    scrollController.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final isEmptySearchScreen = widget.parentId == null &&
        widget.favourites == null &&
        !(widget.types?.values.any((selected) => selected) ?? false);
    final librarySearchResults = ref.watch(providerKey);
    final postersList = librarySearchResults.posters
        .hideEmptyChildren(librarySearchResults.filters.hideEmptyShows);
    final libraryViewType = ref.watch(libraryViewTypeProvider);

    final toolbarHeight = AppPageLayout.toolbarHeight;

    ref.listen(
      providerKey,
      (previous, next) {
        if (previous?.shouldRefresh(next) == true) {
          refreshSearch();
        }
      },
    );

    final adaptiveLayout = AdaptiveLayout.of(context);

    final mediaQuery = MediaQuery.of(context);

    List<ItemAction>? itemActions = librarySearchResults
        .folderOverwrite.included.firstOrNull
        ?.generateActions(
      context,
      ref,
      exclude: {
        ItemActions.details,
        ItemActions.markPlayed,
        ItemActions.markUnplayed,
      },
      onItemUpdated: (item) {
        libraryProvider.updateParentItem(item);
      },
      onUserDataChanged: (userData) {
        libraryProvider.updateUserDataMain(userData);
      },
    );

    List<ItemAction> menuActions = [
      ItemActionButton(
        label: Text(
            context.localized.itemCount(librarySearchResults.totalItemCount)),
        icon: const Icon(IconsaxPlusBold.document_1),
      ),
      ItemActionButton(
        label: Text(context.localized.forceRefresh),
        action: () => refreshKey.currentState?.show(),
        icon: const Icon(IconsaxPlusLinear.refresh),
      ),
      ItemActionButton(
        label: Text(context.localized.filter(2)),
        action: () => showSavedFilters(context, uniqueKey),
        icon: const Icon(IconsaxPlusLinear.filter_edit),
      ),
      ItemActionButton(
        label: Text(context.localized.selectViewType),
        icon: Icon(libraryViewType.icon),
        action: () {
          showAdaptiveDialog(
            context: context,
            barrierDismissible: true,
            builder: (context) => GlassAlertDialog(
              content: Consumer(
                builder: (context, ref, child) {
                  final currentType = ref.watch(libraryViewTypeProvider);
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(context.localized.selectViewType,
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),
                      ...LibraryViewTypes.values
                          .map(
                            (e) => FilledButton.tonal(
                              style:
                                  FilledButtonTheme.of(context).style?.copyWith(
                                        padding: const WidgetStatePropertyAll(
                                            EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 24)),
                                        backgroundColor:
                                            WidgetStateProperty.resolveWith(
                                          (states) {
                                            if (e != currentType) {
                                              return Colors.transparent;
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                              onPressed: () {
                                ref
                                    .read(libraryViewTypeProvider.notifier)
                                    .state = e;
                              },
                              child: Row(
                                children: [
                                  Icon(e.icon),
                                  const SizedBox(width: 12),
                                  Text(
                                    e.label(context),
                                  )
                                ],
                              ),
                            ),
                          )
                          .toList()
                          .addInBetween(const SizedBox(height: 12)),
                    ],
                  );
                },
              ),
            ),
          );
        },
      ),
      if (itemActions?.isNotEmpty == true) ItemActionDivider(),
      ...?itemActions,
    ];

    Future<void> playLibrary(bool shuffle) async {
      if (librarySearchResults.showGalleryButtons &&
          !librarySearchResults.showPlayButtons &&
          !librarySearchResults.showMusicButtons) {
        libraryProvider.viewGallery(context, ref, shuffle: shuffle);
        return;
      } else if (!librarySearchResults.showGalleryButtons &&
          librarySearchResults.showPlayButtons &&
          !librarySearchResults.showMusicButtons) {
        libraryProvider.playLibraryItems(context, ref, shuffle: shuffle);
        return;
      } else if (!librarySearchResults.showGalleryButtons &&
          !librarySearchResults.showPlayButtons &&
          librarySearchResults.showMusicButtons) {
        libraryProvider.playMusicItems(context, ref, shuffle: shuffle);
        return;
      }

      await showLibraryPlayOptions(
        context,
        context.localized.libraryShuffleAndPlayItems,
        playVideos: librarySearchResults.showPlayButtons
            ? () =>
                libraryProvider.playLibraryItems(context, ref, shuffle: shuffle)
            : null,
        playMusic: librarySearchResults.showMusicButtons
            ? () =>
                libraryProvider.playMusicItems(context, ref, shuffle: shuffle)
            : null,
        viewGallery: librarySearchResults.showGalleryButtons
            ? () => libraryProvider.viewGallery(context, ref, shuffle: shuffle)
            : null,
      );
    }

    List<ItemAction> generateQuickActions(
      bool inlinedPlayButtons,
    ) {
      final isSelectMode = librarySearchResults.selecteMode;
      final selectedCount = librarySearchResults.selectedPosters.length;
      void disableFilters(LibrarySearchModel librarySearchResults,
          LibrarySearchNotifier libraryProvider) {
        libraryProvider.clearAllFilters();
        refreshKey.currentState?.show();
      }

      final playButton = ItemActionButton(
        action: () => playLibrary(false),
        label: Text(context.localized.libraryPlayItems),
        icon: const Icon(IconsaxPlusBold.play),
      );
      final shuffleButton = ItemActionButton(
        action: () => playLibrary(true),
        label: Text(context.localized.libraryShuffleAndPlayItems),
        icon: const Icon(IconsaxPlusBold.shuffle),
      );

      final hasSelection = librarySearchResults.selectedPosters.isNotEmpty;

      final selectedPostersId =
          librarySearchResults.selectedPosters.map((e) => e.id).toList();

      if (isSelectMode) {
        return [
          if (inlinedPlayButtons) playButton,
          shuffleButton,
          if (librarySearchResults.showOpenMultiple)
            ItemActionButton(
              action: () {
                LibrarySearchRoute(
                  parentId: selectedPostersId,
                  key: Key(selectedPostersId.join(',')),
                ).push(context);
              },
              label: Text(context.localized.openSelected),
              icon: const Icon(IconsaxPlusLinear.folder_open),
            ),
          ItemActionDivider(),
          ItemActionButton(
            action: () {
              libraryProvider.toggleSelectMode();
            },
            label: Text(context.localized.stopSelection(selectedCount)),
            icon: selectedCount != 0
                ? Badge(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    label: Text(
                      selectedCount.toString(),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimary),
                    ),
                    child: const Icon(IconsaxPlusLinear.category_2),
                  )
                : const Icon(IconsaxPlusLinear.category_2),
          ),
          ItemActionDivider(),
          ItemActionButton(
            action: () => libraryProvider.selectAll(true),
            label: Text(context.localized.selectAll),
            icon: const Icon(IconsaxPlusLinear.tick_square),
          ),
          ItemActionButton(
            action: () => libraryProvider.selectAll(false),
            label: Text(context.localized.clearSelection),
            icon: const Icon(IconsaxPlusLinear.minus_square),
          ),
          ItemActionDivider(),
          ItemActionButton(
            action: hasSelection
                ? () async {
                    await libraryProvider.setSelectedAsFavorite(true);
                    if (context.mounted) context.refreshData();
                  }
                : null,
            label: Text(context.localized.addAsFavorite),
            icon: const Icon(IconsaxPlusLinear.heart_add),
          ),
          ItemActionButton(
            action: hasSelection
                ? () async {
                    await libraryProvider.setSelectedAsFavorite(false);
                    if (context.mounted) context.refreshData();
                  }
                : null,
            label: Text(context.localized.removeAsFavorite),
            icon: const Icon(IconsaxPlusLinear.heart_remove),
          ),
          ItemActionButton(
            action: hasSelection
                ? () async {
                    await libraryProvider.setSelectedAsWatched(true);
                    if (context.mounted) context.refreshData();
                  }
                : null,
            label: Text(context.localized.markAsWatched),
            icon: const Icon(IconsaxPlusLinear.eye),
          ),
          ItemActionButton(
            action: hasSelection
                ? () async {
                    await libraryProvider.setSelectedAsWatched(false);
                    if (context.mounted) context.refreshData();
                  }
                : null,
            label: Text(context.localized.markAsUnwatched),
            icon: const Icon(IconsaxPlusLinear.eye_slash),
          ),
          if (librarySearchResults.folderOverwrite.included.firstOrNull
              is BoxSetModel)
            ItemActionButton(
                action: hasSelection
                    ? () async {
                        await libraryProvider.removeSelectedFromCollection();
                        if (context.mounted) context.refreshData();
                      }
                    : null,
                label: Text(context.localized.removeFromCollection),
                icon: Container(
                  decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.onPrimary,
                      borderRadius: BorderRadius.circular(6)),
                  child: const Padding(
                    padding: EdgeInsets.all(3.0),
                    child: Icon(IconsaxPlusLinear.save_remove, size: 20),
                  ),
                )),
          if (librarySearchResults.folderOverwrite.included.firstOrNull
              is PlaylistModel)
            ItemActionButton(
              action: hasSelection
                  ? () async {
                      await libraryProvider.removeSelectedFromPlaylist();
                      if (context.mounted) context.refreshData();
                    }
                  : null,
              label: Text(context.localized.removeFromPlaylist),
              icon: const Icon(IconsaxPlusLinear.save_remove),
            ),
          ItemActionButton(
            action: hasSelection
                ? () async {
                    await addItemToCollection(
                        context, librarySearchResults.selectedPosters);
                    if (context.mounted) context.refreshData();
                  }
                : null,
            label: Text(context.localized.addToCollection),
            icon: const Icon(
              IconsaxPlusLinear.save_add,
              size: 20,
            ),
          ),
          ItemActionButton(
            action: hasSelection
                ? () async {
                    await addItemToPlaylist(
                        context, librarySearchResults.selectedPosters);
                    if (context.mounted) context.refreshData();
                  }
                : null,
            label: Text(context.localized.addToPlaylist),
            icon: const Icon(IconsaxPlusLinear.save_add),
          ),
        ];
      } else {
        return [
          if (inlinedPlayButtons) playButton,
          shuffleButton,
          ItemActionDivider(),
          ItemActionButton(
            action: () {
              libraryProvider.toggleSelectMode();
            },
            label: Text(context.localized.select),
            icon: const Icon(IconsaxPlusLinear.category_2),
          ),
          ItemActionDivider(),
          ItemActionButton(
            action: () async {
              final newOptions = await openSortByDialogue(
                context,
                libraryProvider: libraryProvider,
                uniqueKey: uniqueKey,
                options: (
                  librarySearchResults.filters.sortingOption,
                  librarySearchResults.filters.sortOrder
                ),
              );
              if (newOptions != null) {
                if (newOptions.$1 != null) {
                  libraryProvider.setSortBy(newOptions.$1!);
                }
                if (newOptions.$2 != null) {
                  libraryProvider.setSortOrder(newOptions.$2!);
                }
              }
            },
            label: Text(context.localized.sortBy),
            icon: const Icon(IconsaxPlusLinear.sort),
          ),
          if (librarySearchResults.hasActiveFilters) ...{
            ItemActionButton(
              action: () {
                disableFilters(librarySearchResults, libraryProvider);
              },
              label: Text(context.localized.disableFilters),
              icon: const Icon(IconsaxPlusLinear.filter_remove),
            ),
          },
          if (librarySearchResults.activePosters.isNotEmpty)
            ItemActionButton(
              action: () {
                return libraryProvider.openRandom(context);
              },
              label: Text(context.localized.selectRandom),
              icon: const Icon(
                IconsaxPlusBold.slider_vertical,
              ),
            ),
        ];
      }
    }

    LibraryFilterModel? incomingFilter() {
      if (widget.favourites != null ||
          widget.sortOrder != null ||
          widget.sortingOptions != null ||
          widget.types != null ||
          widget.genres != null ||
          widget.itemFilters != null ||
          widget.studios != null ||
          widget.years != null ||
          widget.tags != null ||
          widget.recursive != null ||
          widget.query != null) {
        final defaultFilter = const LibraryFilterModel();

        return defaultFilter.copyWith(
          searchQuery: widget.query ?? "",
          favourites: widget.favourites,
          sortOrder: widget.sortOrder ?? defaultFilter.sortOrder,
          sortingOption: widget.sortingOptions ?? defaultFilter.sortingOption,
          types: widget.types ?? {},
          genres: widget.genres ?? {},
          itemFilters: widget.itemFilters ?? {},
          studios: widget.studios ?? {},
          years: widget.years ?? {},
          tags: widget.tags ?? {},
          recursive: widget.recursive,
          isDefault: widget.isDefault ?? false,
        );
      } else {
        return null;
      }
    }

    return MediaQuery(
      data: mediaQuery.copyWith(
        padding: mediaQuery.padding.copyWith(
            top: mediaQuery.padding.top + adaptiveLayout.topBarHeight),
        viewPadding: mediaQuery.viewPadding.copyWith(
            top: mediaQuery.viewPadding.top + adaptiveLayout.topBarHeight),
      ),
      child: PopScope(
        key: uniqueKey,
        canPop: !librarySearchResults.selecteMode,
        onPopInvokedWithResult: (didPop, result) {
          if (librarySearchResults.selecteMode) {
            libraryProvider.toggleSelectMode();
          }
        },
        child: NestedScaffold(
          background: const ColoredBox(color: AppColors.background),
          body: Scaffold(
            extendBody: true,
            backgroundColor: Colors.transparent,
            extendBodyBehindAppBar: true,
            // Pas de navigation en bas d'écran ni de bouton flottant (règle
            // anti-mobile-first, CLAUDE.md) : lire/mélanger/sélectionner
            // vivent uniquement dans la barre d'outils du haut
            // (LibraryAppBar.quickActions), plus jamais dupliqués ici.
            body: PinchPosterZoom(
              scaleDifference: (difference) => ref
                  .read(clientSettingsProvider.notifier)
                  .addPosterSize(difference),
              child: KinosScrollbar(
                visible: AdaptiveLayout.inputDeviceOf(context) !=
                    InputDevice.pointer,
                controller: scrollController,
                child: PullToRefresh(
                  refreshKey: refreshKey,
                  autoFocus: false,
                  contextRefresh: false,
                  onRefresh: () async {
                    final filter = incomingFilter();
                    if (libraryProvider.mounted) {
                      return libraryProvider.initRefresh(
                        parentIds: widget.parentId ?? [],
                        filters: filter,
                      );
                    }
                  },
                  refreshOnStart: false,
                  child: (context) {
                    return CustomScrollView(
                      controller: scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(
                          child: LibraryAppBar(
                            toolbarHeight: toolbarHeight,
                            menuActions: menuActions,
                            librarySearchResults: librarySearchResults,
                            quickActions: generateQuickActions(true),
                            isEmptySearchScreen: isEmptySearchScreen,
                            refreshKey: refreshKey,
                            uniqueKey: uniqueKey,
                            libraryProvider: libraryProvider,
                            scrollController: scrollController,
                          ),
                        ),
                        if (postersList.isNotEmpty)
                          SliverPadding(
                            padding: AdaptiveLayout.adaptivePadding(context,
                                horizontalPadding:
                                    AppSpacing.screenPadding - AppSpacing.xxs),
                            sliver: LibraryViews(
                              key: uniqueKey,
                              items: postersList,
                              groupByType: librarySearchResults.filters.groupBy,
                            ),
                          )
                        else
                          SliverFillRemaining(
                            child: Center(
                              child: Text(context.localized.noItemsToShow),
                            ),
                          ),
                        SliverPadding(
                            padding: EdgeInsets.only(
                                bottom:
                                    MediaQuery.sizeOf(context).height * 0.20))
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LibraryAppBar extends ConsumerWidget {
  final double toolbarHeight;
  final List<ItemAction> menuActions;
  final LibrarySearchModel librarySearchResults;
  final List<ItemAction> quickActions;
  final bool isEmptySearchScreen;
  final GlobalKey<RefreshIndicatorState> refreshKey;
  final Key uniqueKey;
  final LibrarySearchNotifier libraryProvider;
  final ScrollController scrollController;

  const LibraryAppBar({
    required this.toolbarHeight,
    required this.menuActions,
    required this.librarySearchResults,
    this.quickActions = const [],
    required this.isEmptySearchScreen,
    required this.refreshKey,
    required this.uniqueKey,
    required this.libraryProvider,
    required this.scrollController,
    super.key,
  });

  String _heading(BuildContext context) {
    final folders = librarySearchResults.folderOverwrite.included;
    if (folders.length == 1) return folders.first.name;
    final views = librarySearchResults.views.included;
    if (views.length == 1) return views.first.name;
    final types = librarySearchResults.filters.types.included;
    if (types.length == 1) {
      if (types.first == KinosItemType.movie) {
        return context.localized.mediaTypeMovie(2);
      }
      if (types.first == KinosItemType.series) {
        return context.localized.mediaTypeSeries(2);
      }
      return types.first.label(context.localized);
    }
    return isEmptySearchScreen
        ? context.localized.search
        : context.localized.library(2);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> sort() async {
      final options = await openSortByDialogue(context,
          libraryProvider: libraryProvider,
          uniqueKey: uniqueKey,
          options: (
            librarySearchResults.filters.sortingOption,
            librarySearchResults.filters.sortOrder
          ));
      if (options?.$1 != null) libraryProvider.setSortBy(options!.$1!);
      if (options?.$2 != null) libraryProvider.setSortOrder(options!.$2!);
    }

    void filters() => showDialog<void>(
        context: context,
        builder: (dialogContext) => AdaptiveLayout(
            data: AdaptiveLayout.of(context),
            child: GlassDialog(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(
                      maxWidth: AppLibraryLayout.filterPanelWidth),
                  child: SingleChildScrollView(
                    child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(children: [
                                Expanded(
                                    child: Text('Filtres',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge)),
                                IconButton(
                                    tooltip: 'Fermer',
                                    onPressed: () =>
                                        Navigator.of(dialogContext).pop(),
                                    icon: const Icon(Icons.close))
                              ]),
                              const SizedBox(height: AppSpacing.md),
                              LibraryFilterChips(key: uniqueKey, wrap: true),
                              if (ref.watch(clientSettingsProvider.select(
                                  (value) => value.pinchPosterZoom))) ...[
                                const SizedBox(height: AppSpacing.md),
                                const Text('Taille des affiches'),
                                const Align(
                                    alignment: Alignment.centerLeft,
                                    child: PosterSizeWidget()),
                              ],
                            ])),
                  )),
            )));
    final allActions = [
      ...quickActions,
      if (quickActions.isNotEmpty && menuActions.isNotEmpty)
        ItemActionDivider(),
      ...menuActions
    ];
    final search = SizedBox(
        width: AppLibraryLayout.searchWidth,
        child: ClipRRect(
            borderRadius: AppRadii.controlBorder,
            child: SuggestionSearchBar(
              key: uniqueKey,
              autoFocus: isEmptySearchScreen,
              title: isEmptySearchScreen
                  ? 'Rechercher dans vos films et séries…'
                  : 'Rechercher dans ${_heading(context)}…',
              onItem: (item) async {
                await item.navigateTo(context);
                refreshKey.currentState?.show();
              },
              onSubmited: (value) {
                if (librarySearchResults.filters.searchQuery != value) {
                  libraryProvider.setSearch(value);
                  refreshKey.currentState?.show();
                }
              },
            )));
    final controls = LibraryFilterChips(key: uniqueKey, quickOnly: true);
    final trailing = Row(mainAxisSize: MainAxisSize.min, children: [
      TextButton(
          onPressed: sort,
          child: Text(
              'Trier : ${librarySearchResults.filters.sortingOption.label(context)}')),
      const SizedBox(width: AppSpacing.xs),
      TextButton.icon(
          onPressed: filters,
          icon: const Icon(Icons.tune),
          label: const Text('Filtres')),
      if (allActions.isNotEmpty)
        GlassPopupMenuButton(
          tooltip: 'Actions',
          borderRadius: AppNavigation.border,
          itemBuilder: (_) => allActions.popupMenuItems(useIcons: true),
          child: const Padding(
              padding: EdgeInsets.all(AppSpacing.sm),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text('Actions'),
                SizedBox(width: AppSpacing.xxs),
                Icon(Icons.keyboard_arrow_down)
              ])),
        ),
    ]);
    final padding = AdaptiveLayout.adaptivePadding(context,
        horizontalPadding: AppSpacing.screenPadding);
    return Padding(
      padding: padding.copyWith(
          top: MediaQuery.paddingOf(context).top + AppSpacing.lg,
          bottom: AppSpacing.lg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(
            spacing: AppSpacing.md,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (context.router.canPop())
                IconButton(
                    tooltip:
                        MaterialLocalizations.of(context).backButtonTooltip,
                    onPressed: () => context.router.maybePop(),
                    icon: const Icon(Icons.arrow_back)),
              Text(_heading(context),
                  style: Theme.of(context).textTheme.headlineLarge),
              Text(
                  context.localized
                      .itemCount(librarySearchResults.totalItemCount),
                  style: Theme.of(context).textTheme.bodySmall),
              if (librarySearchResults.selecteMode)
                Text(context.localized.stopSelection(
                    librarySearchResults.selectedPosters.length)),
            ]),
        const SizedBox(height: AppSpacing.md),
        LayoutBuilder(builder: (context, constraints) {
          final quick = SingleChildScrollView(
              scrollDirection: Axis.horizontal, child: controls);
          if (constraints.maxWidth >= AppLibraryLayout.inlineWidth &&
              MediaQuery.textScalerOf(context).scale(1) <= 1) {
            return Row(children: [
              search,
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: quick),
              const SizedBox(width: AppSpacing.sm),
              trailing
            ]);
          }
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                search,
                const SizedBox(height: AppSpacing.xs),
                quick,
                const SizedBox(height: AppSpacing.xs),
                Align(
                    alignment: AlignmentDirectional.centerEnd, child: trailing),
              ]);
        }),
        LibraryActiveFilters(providerKey: uniqueKey),
      ]),
    );
  }
}
