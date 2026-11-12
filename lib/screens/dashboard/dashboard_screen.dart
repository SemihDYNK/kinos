import 'package:kinos/letterboxd/home/letterboxd_home_sections.dart';
import 'package:kinos/screens/dashboard/genre_browse_section.dart';
import 'package:kinos/widgets/shared/page_motion.dart';
import 'dart:async';
import 'package:kinos/providers/dashboard/catalog_navigation_provider.dart';
import 'package:kinos/screens/dashboard/catalog_home_screen.dart';

import 'package:flutter/material.dart';

import 'package:auto_route/auto_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kinos/jellyfin/jellyfin_open_api.enums.swagger.dart';
import 'package:kinos/models/item_base_model.dart';
import 'package:kinos/models/settings/home_row_model.dart';
import 'package:kinos/providers/dashboard_mode_provider.dart';
import 'package:kinos/providers/dashboard_provider.dart';
import 'package:kinos/providers/dashboard/hero_items_provider.dart';
import 'package:kinos/providers/settings/home_rows_provider.dart';
import 'package:kinos/providers/user_provider.dart';
import 'package:kinos/providers/views_provider.dart';
import 'package:kinos/screens/dashboard/home_hero_section.dart';
import 'package:kinos/screens/dashboard/home_row_section.dart';
import 'package:kinos/screens/dashboard/music_dashboard_screen.dart';
import 'package:kinos/screens/dashboard/catalog_inventory_section.dart';
import 'package:kinos/screens/dashboard/recently_added_section.dart';
import 'package:kinos/screens/dashboard/recommendation_row_section.dart';
import 'package:kinos/screens/dashboard/seed_row_section.dart';
import 'package:kinos/screens/dashboard/seerr_discovery_section.dart';
import 'package:kinos/routes/auto_router.gr.dart';
import 'package:kinos/screens/home_screen.dart';
import 'package:kinos/screens/shared/nested_scaffold.dart';
import 'package:kinos/screens/shared/nested_sliver_appbar.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/adaptive_layout/adaptive_layout.dart';
import 'package:kinos/util/sliver_list_padding.dart';
import 'package:kinos/widgets/shared/pull_to_refresh.dart';

/// Types de collection dans le périmètre du projet — films et séries
/// uniquement (cf. CLAUDE.md § Périmètre).
const _dashboardCollectionTypes = {
  CollectionType.movies,
  CollectionType.tvshows,
  CollectionType.boxsets,
  CollectionType.homevideos,
};

@RoutePage()
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({
    super.key,
  });

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  late final Timer _timer;
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 120), (timer) {
      _refreshIndicatorKey.currentState?.show();
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<void> _refreshHome() async {
    if (mounted) {
      await ref.read(userProvider.notifier).updateInformation();
      await ref.read(viewsProvider.notifier).fetchViews();
      await ref.read(dashboardProvider.notifier).fetchNextUpAndResume();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = ref.watch(catalogScopeProvider);
    final index = scope == allCatalog
        ? 0
        : scope.kind == BaseItemKind.movie
            ? 1
            : 2;
    return CatalogPageMotion(
        index: index,
        child: scope == allCatalog
            ? _buildDashboard(context)
            : CatalogHomeScreen(scope: scope));
  }

  Widget _buildDashboard(BuildContext context) {
    if (ref.watch(musicDashboardModeProvider)) {
      return const MusicDashboardScreen();
    }

    // horizontalPadding: AppSpacing.screenPadding — explicite, sinon
    // adaptivePadding retombe sur son défaut interne (12) : le bandeau
    // aligne son contenu sur AppSpacing.screenPadding, donc les titres de
    // section en dessous (qui partagent ce même `padding`) doivent viser la
    // même valeur pour rester alignés verticalement avec lui.
    final padding = AdaptiveLayout.adaptivePadding(context,
        horizontalPadding: AppSpacing.screenPadding);
    final dashboardData = ref.watch(dashboardProvider);
    final views = ref.watch(viewsProvider);
    final allRows = ref.watch(homeRowsProvider);
    final enabledRows = allRows.where((row) => row.enabled).toList();
    // Rangées de recommandation (lot B) séparées du reste : rendues plus
    // haut sur la page, entre "Continuer à regarder" et "Ajouts récents"
    // (cf. spec), pas après comme les rangées configurables classiques.
    // Toujours dans `homeRowsProvider`/`homeRows` (même activation,
    // même réordonnancement clavier/glisser-déposer que les autres) —
    // seule leur position d'affichage est différente, cf.
    // `HomeRowType.forYou`/`.setAside`.
    final recommendationRows = enabledRows
        .where((row) =>
            row.type == HomeRowType.forYou || row.type == HomeRowType.setAside)
        .toList();
    // Types catégorie du lot graines/inventaire (cf. le commentaire sur
    // `HomeRowType`) : comme les deux ci-dessus, activés/réordonnés via
    // `homeRowsProvider`, mais routés vers leurs propres sections
    // (`TasteSeedRowsSection`/`CatalogInventorySection`) plutôt que la
    // boucle générique ci-dessous — leur contenu réel (0 à N sous-rangées
    // dynamiques) ne vient jamais de `homeRowItemsProvider`.
    final enabledCatalogTypes = enabledRows.map((r) => r.type).toSet();
    final homeRows = enabledRows
        .where((row) =>
            row.type != HomeRowType.forYou &&
            row.type != HomeRowType.setAside &&
            row.type != HomeRowType.tasteSeeds &&
            row.type != HomeRowType.seerrDiscovery &&
            row.type != HomeRowType.catalogWellRated &&
            row.type != HomeRowType.catalogNarrowGenres &&
            row.type != HomeRowType.catalogDecades &&
            row.type != HomeRowType.catalogLongFilms)
        .toList();

    final recentlyAdded = views.dashboardViews
        .where(
            (view) => _dashboardCollectionTypes.contains(view.collectionType))
        .expand((view) => view.recentlyAdded)
        .toList();

    final heroItems =
        ref.watch(heroItemsProvider).asData?.value ?? const <ItemBaseModel>[];
    // resumeVideo d'abord (déjà en cours), puis nextUp — dédoublonnés.
    final seenContinue = <String>{};
    final continueWatching = [
      ...dashboardData.resumeVideo,
      ...dashboardData.nextUp
    ].where((item) => seenContinue.add(item.id)).toList();

    return NestedScaffold(
      body: PullToRefresh(
        refreshKey: _refreshIndicatorKey,
        displacement: 80 + MediaQuery.of(context).viewPadding.top,
        onRefresh: () async => await _refreshHome(),
        child: (context) => CustomScrollView(
          controller: AdaptiveLayout.scrollOf(context, HomeTabs.dashboard),
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Sur desktop, le bandeau passe derrière le chrome translucide.
            // Sans bandeau, conserver l'espace de sécurité pour les rangées.
            if (heroItems.isEmpty || !AdaptiveLayout.isDesktop(context))
              const DefaultSliverTopBadding(),
            if (AdaptiveLayout.viewSizeOf(context) == ViewSize.phone)
              NestedSliverAppBar(
                route: LibrarySearchRoute(),
                parent: context,
              ),
            HomeHeroSection(
              heroItems: heroItems,
              resumeItems: continueWatching,
              contentPadding: padding,
            ),
            // Les genres, tout de suite sous « Continuer à regarder » : un accès
            // direct qui évite de défiler. Une rangée de tuiles remplace
            // l'empilement d'une rangée par genre ; chaque tuile mène à la
            // page du genre.
            if (enabledCatalogTypes.contains(HomeRowType.catalogNarrowGenres))
              GenreBrowseSection(scope: allCatalog, contentPadding: padding),
            // Entre "Continuer à regarder" et "Ajouts récents" (cf. spec)
            // — en dehors du SliverStack/FadingHeroBackdrop ci-dessus,
            // donc sur AppColors.background pur comme tout ce qui suit,
            // jamais teinté (cf. CLAUDE.md § Bandeau teinté : "la grille
            // Ajouts récents et tout ce qui suit restent sur #0A0A0A
            // pur").
            for (final row in recommendationRows)
              SliverPadding(
                padding: const EdgeInsets.only(top: AppSpacing.xl),
                sliver: switch (row.type) {
                  // Rangées Letterboxd juste après « Pour vous ».
                  HomeRowType.forYou => SliverMainAxisGroup(slivers: [
                      ForYouRowSection(row: row, contentPadding: padding),
                      LetterboxdHomeSections(contentPadding: padding),
                    ]),
                  HomeRowType.setAside =>
                    SetAsideRowSection(row: row, contentPadding: padding),
                  _ => const SliverToBoxAdapter(child: SizedBox.shrink()),
                },
              ),
            // Graines + inventaire du catalogue (cf. spec) : entre les
            // rangées de recommandation et "Ajouts récents", qui garde sa
            // position actuelle. Pas de rangée/titre de transition
            // explicite entre les deux — seule la typographie des titres
            // d'inventaire change de registre (cf.
            // `AppTypography.catalogSectionTitle`).
            if (enabledCatalogTypes.contains(HomeRowType.tasteSeeds))
              SliverPadding(
                padding: const EdgeInsets.only(top: AppSpacing.xl),
                sliver: TasteSeedRowsSection(contentPadding: padding),
              ),
            for (final row in enabledRows
                .where((row) => row.type == HomeRowType.seerrDiscovery)
                .take(1))
              SeerrDiscoverySection(
                  key: ValueKey(row.id), row: row, contentPadding: padding),
            SliverPadding(
              padding: const EdgeInsets.only(top: AppSpacing.xl),
              sliver: CatalogInventorySection(
                contentPadding: padding,
                showWellRated:
                    enabledCatalogTypes.contains(HomeRowType.catalogWellRated),
                showNarrowGenres: false,
                showDecades:
                    enabledCatalogTypes.contains(HomeRowType.catalogDecades),
                showLongFilms:
                    enabledCatalogTypes.contains(HomeRowType.catalogLongFilms),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.only(top: AppSpacing.xl),
              sliver: RecentlyAddedSection(
                items: recentlyAdded,
                contentPadding: padding,
              ),
            ),
            for (final row in homeRows)
              SliverPadding(
                padding: const EdgeInsets.only(top: AppSpacing.xl),
                sliver: HomeRowSection(
                  row: row,
                  contentPadding: padding,
                ),
              ),
            const DefaultSliverBottomPadding(),
          ],
        ),
      ),
    );
  }
}
