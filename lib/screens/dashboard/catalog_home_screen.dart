import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinos/jellyfin/jellyfin_open_api.enums.swagger.dart';
import 'package:kinos/models/item_base_model.dart';
import 'package:kinos/models/settings/home_row_model.dart';
import 'package:kinos/providers/dashboard/catalog_navigation_provider.dart';
import 'package:kinos/providers/views_provider.dart';
import 'package:kinos/providers/settings/home_rows_provider.dart';
import 'package:kinos/routes/auto_router.gr.dart';
import 'package:kinos/screens/dashboard/home_hero_section.dart';
import 'package:kinos/screens/dashboard/single_row_section.dart';
import 'package:kinos/screens/dashboard/catalog_inventory_section.dart';
import 'package:kinos/screens/dashboard/genre_browse_section.dart';
import 'package:kinos/screens/dashboard/seerr_discovery_section.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/adaptive_layout/adaptive_layout.dart';

class CatalogHomeScreen extends ConsumerWidget {
  const CatalogHomeScreen({required this.scope, super.key});
  final CatalogScope scope;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(catalogHomeProvider(scope));
    final rows =
        ref.watch(homeRowsProvider).where((row) => row.enabled).toList();
    final enabledTypes = rows.map((row) => row.type).toSet();
    final discoveryRow =
        rows.where((row) => row.type == HomeRowType.seerrDiscovery).firstOrNull;
    final mediaType = scope.kind == BaseItemKind.movie
        ? KinosItemType.movie
        : KinosItemType.series;
    final padding = AdaptiveLayout.adaptivePadding(context,
        horizontalPadding: AppSpacing.screenPadding);
    final views = ref
        .watch(viewsProvider)
        .views
        .where((view) => scope.libraryId != null
            ? view.id == scope.libraryId
            : view.collectionType ==
                (scope.kind == BaseItemKind.movie
                    ? CollectionType.movies
                    : CollectionType.tvshows))
        .toList();
    void browse() => context.router.push(LibrarySearchRoute(
        parentId: scope.libraryId == null ? null : [scope.libraryId!],
        recursive: true,
        types: scope.kind == null
            ? null
            : {
                scope.kind == BaseItemKind.movie
                    ? KinosItemType.movie
                    : KinosItemType.series: true
              }));
    return data.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(
          child: TextButton(
              onPressed: () => ref.invalidate(catalogHomeProvider(scope)),
              child: const Text('Catalogue indisponible · Réessayer'))),
      data: (home) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(catalogHomeProvider(scope));
            await ref.read(catalogHomeProvider(scope).future);
          },
          child: CustomScrollView(
              key: PageStorageKey(scope),
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                if (home.hero.isEmpty)
                  const SliverToBoxAdapter(
                      child: SizedBox(height: AppTopNavigation.contentInset)),
                HomeHeroSection(
                    heroItems: home.hero,
                    resumeItems: home.resume,
                    contentPadding: padding),
                // Les genres juste sous le bandeau : accès direct, sans défiler.
                if (scope.libraryId == null &&
                    enabledTypes.contains(HomeRowType.catalogNarrowGenres))
                  GenreBrowseSection(scope: scope, contentPadding: padding),
                SliverPadding(
                    padding: const EdgeInsets.only(top: AppSpacing.xl),
                    sliver: SingleRowSection(
                        title: 'Ajouts récents',
                        items: home.recent,
                        contentPadding: padding,
                        onSeeAll: browse)),
                if (scope.libraryId == null) ...[
                  CatalogInventorySection(
                    contentPadding: padding,
                    mediaType: mediaType,
                    showWellRated:
                        enabledTypes.contains(HomeRowType.catalogWellRated),
                    showNarrowGenres: false,
                    showDecades:
                        enabledTypes.contains(HomeRowType.catalogDecades),
                    showLongFilms: false,
                  ),
                  if (discoveryRow != null)
                    SeerrDiscoverySection(
                      row: discoveryRow,
                      contentPadding: padding,
                      mediaType:
                          mediaType == KinosItemType.movie ? 'movie' : 'tv',
                    ),
                ],
                for (final view in views)
                  SliverPadding(
                      padding: const EdgeInsets.only(top: AppSpacing.xl),
                      sliver: SingleRowSection(
                          title: view.name,
                          items: view.recentlyAdded,
                          contentPadding: padding,
                          onSeeAll: () => view.navigateToView(context))),
                if (home.recent.isEmpty)
                  const SliverToBoxAdapter(
                      child: Padding(
                          padding: EdgeInsets.all(AppSpacing.xxl),
                          child: Center(
                              child: Text(
                                  'Aucun titre dans cette bibliothèque')))),
                SliverToBoxAdapter(
                    child: Padding(
                        padding: padding.copyWith(
                            top: AppSpacing.lg, bottom: AppSpacing.xxl),
                        child: Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                                onPressed: browse,
                                child: const Text(
                                    'Parcourir tout le catalogue'))))),
              ])),
    );
  }
}
