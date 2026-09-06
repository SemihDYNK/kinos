import 'dart:async';

import 'package:flutter/material.dart';

import 'package:auto_route/auto_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fladder/jellyfin/jellyfin_open_api.enums.swagger.dart';
import 'package:fladder/models/item_base_model.dart';
import 'package:fladder/providers/dashboard_mode_provider.dart';
import 'package:fladder/providers/dashboard_provider.dart';
import 'package:fladder/providers/settings/home_rows_provider.dart';
import 'package:fladder/providers/user_provider.dart';
import 'package:fladder/providers/views_provider.dart';
import 'package:fladder/screens/dashboard/continue_watching_section.dart';
import 'package:fladder/screens/dashboard/hero_carousel.dart';
import 'package:fladder/screens/dashboard/home_row_section.dart';
import 'package:fladder/screens/dashboard/music_dashboard_screen.dart';
import 'package:fladder/screens/dashboard/recently_added_section.dart';
import 'package:fladder/routes/auto_router.gr.dart';
import 'package:fladder/screens/home_screen.dart';
import 'package:fladder/screens/shared/nested_scaffold.dart';
import 'package:fladder/screens/shared/nested_sliver_appbar.dart';
import 'package:fladder/theme/app_theme.dart';
import 'package:fladder/util/adaptive_layout/adaptive_layout.dart';
import 'package:fladder/util/sliver_list_padding.dart';
import 'package:fladder/widgets/shared/pull_to_refresh.dart';

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

  /// Films et séries non vus des ajouts récents, dédoublonnés, 8 max.
  List<ItemBaseModel> _heroCandidates(List<ItemBaseModel> recentlyAdded) {
    final seen = <String>{};
    final candidates = <ItemBaseModel>[];
    for (final item in recentlyAdded) {
      if (item.type != FladderItemType.movie &&
          item.type != FladderItemType.series) {
        continue;
      }
      if (!item.unWatched) continue;
      if (!seen.add(item.id)) continue;
      candidates.add(item);
      if (candidates.length >= 8) break;
    }
    return candidates;
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(musicDashboardModeProvider)) {
      return const MusicDashboardScreen();
    }

    final padding = AdaptiveLayout.adaptivePadding(context);
    // `padding` inclut déjà la largeur de la barre latérale (cf.
    // AdaptiveLayout.adaptivePadding) : la barre latérale n'est pas une
    // colonne séparée, c'est un calque semi-transparent posé par-dessus un
    // contenu plein cadre (SideNavigationRail). Le fond teinté ci-dessous
    // doit donc s'arrêter *avant* cette largeur, sans quoi il transparaît
    // sous elle — d'où la fuite. On sépare : `sideBarInset` appliqué une
    // fois par le wrapper du fond, `innerPadding` (sans lui) pour le
    // contenu qui vit à l'intérieur de ce même wrapper.
    final sideBarInset = AdaptiveLayout.of(context).sideBarWidth;
    final innerPadding = padding.copyWith(left: padding.left - sideBarInset);
    final dashboardData = ref.watch(dashboardProvider);
    final views = ref.watch(viewsProvider);
    final homeRows =
        ref.watch(homeRowsProvider).where((row) => row.enabled).toList();

    final recentlyAdded = views.dashboardViews
        .where(
            (view) => _dashboardCollectionTypes.contains(view.collectionType))
        .expand((view) => view.recentlyAdded)
        .toList();

    final heroItems = _heroCandidates(recentlyAdded);

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
            const DefaultSliverTopBadding(),
            if (AdaptiveLayout.viewSizeOf(context) == ViewSize.phone)
              NestedSliverAppBar(
                route: LibrarySearchRoute(),
                parent: context,
              ),
            // Fond de la zone de contenu : heroTint sous le bandeau, résorbé
            // en AppColors.background avant la fin de cette rangée — donc
            // bien avant "Ajouts récents". Un dégradé de couleur simple, pas
            // un flou d'image : cette zone défile et change à chaque diapo.
            // Inséré à `sideBarInset` : la barre latérale reste sur
            // AppColors.background pur, jamais teintée.
            //
            // Trois arrêts, pas deux : la teinte reste pleine jusqu'à ~0.55
            // (couvre la hauteur du bandeau — 320-480 selon la densité —
            // plus sa marge avant "Continuer à regarder", estimé sur un
            // ratio hauteur bandeau / hauteur totale du bloc), puis descend
            // progressivement pour n'atteindre le fond pur qu'au tout
            // dernier point (fin de "Continuer à regarder"). Avec un seul
            // arrêt intermédiaire, la teinte commençait à s'estomper dès le
            // haut du bandeau et touchait déjà le fond pur bien avant la fin
            // de la rangée — d'où la coupure nette perçue juste sous le
            // bandeau.
            SliverPadding(
              padding: EdgeInsetsDirectional.only(start: sideBarInset),
              sliver: DecoratedSliver(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0, 0.55, 1],
                    colors: [
                      heroItems.isNotEmpty
                          ? context.tokens.heroTint
                          : AppColors.background,
                      heroItems.isNotEmpty
                          ? context.tokens.heroTint
                          : AppColors.background,
                      AppColors.background,
                    ],
                  ),
                ),
                sliver: SliverMainAxisGroup(
                  slivers: [
                    if (heroItems.isNotEmpty)
                      SliverPadding(
                        padding: innerPadding.copyWith(top: 0, bottom: 0),
                        sliver: SliverToBoxAdapter(
                          child: HeroCarousel(items: heroItems),
                        ),
                      ),
                    SliverPadding(
                      padding: EdgeInsets.only(
                          top: heroItems.isNotEmpty ? AppSpacing.xl : 0),
                      sliver: ContinueWatchingSection(
                        items: continueWatching,
                        contentPadding: innerPadding,
                      ),
                    ),
                  ],
                ),
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
