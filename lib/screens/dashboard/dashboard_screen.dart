import 'dart:async';

import 'package:flutter/material.dart';

import 'package:auto_route/auto_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sliver_tools/sliver_tools.dart';

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
import 'package:fladder/widgets/shared/fading_hero_backdrop.dart';
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

  // Diapo affichée par HeroCarousel — reportée ici via son callback pour
  // que FadingHeroBackdrop (posé derrière lui ET "Continuer à regarder")
  // suive la même image, sans dupliquer l'état de rotation à deux endroits.
  ItemBaseModel? _heroCurrent;

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

    // horizontalPadding: AppSpacing.screenPadding — explicite, sinon
    // adaptivePadding retombe sur son défaut interne (12) : le bandeau
    // aligne son contenu sur AppSpacing.screenPadding, donc les titres de
    // section en dessous (qui partagent ce même `padding`) doivent viser la
    // même valeur pour rester alignés verticalement avec lui.
    final padding = AdaptiveLayout.adaptivePadding(context,
        horizontalPadding: AppSpacing.screenPadding);
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
    final density = context.tokens.density;
    // Diapo réellement affichée par HeroCarousel une fois montée
    // (`_heroCurrent`, reporté par son callback) ; en repli, la première
    // diapo, pour ne pas laisser le fond nu le temps du premier frame.
    final heroDisplayItem = _heroCurrent ?? heroItems.firstOrNull;
    final heroImage = heroDisplayItem?.getPosters?.randomBackDrop ??
        heroDisplayItem?.getPosters?.primary;
    // `fadeCompleteBy` (hauteur minimale du carrousel, 320-400px) est
    // nettement plus court que sur le bandeau film/série (680-760px) : les
    // distances par défaut de FadingHeroBackdrop (200 + 150 = 350px), non
    // scalées, y dépasseraient `fadeCompleteBy` lui-même et feraient
    // démarrer la montée de teinte dès le haut du calque — l'image
    // resterait visible bien moins longtemps que voulu. Réduites ici de
    // sorte que l'image reste nue sur exactement la moitié de
    // `fadeCompleteBy`, comme sur la fiche film.
    final heroRampDistance = density == AppDensity.couch ? 110.0 : 90.0;
    final heroResolveDistance = density == AppDensity.couch ? 90.0 : 70.0;

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
            // Fond de la zone bandeau + "Continuer à regarder" : même
            // principe que MediaDetailScaffold (FadingHeroBackdrop) —
            // l'image continue derrière "Continuer à regarder" et se
            // dissout sous un voile, plutôt que de s'arrêter net à la
            // hauteur du carrousel. SliverStack (sliver_tools) superpose,
            // dans le même espace de défilement :
            // - FadingHeroBackdrop, épinglé en haut sur `backdropHeight`
            //   (positionné via SliverPositioned, hors du calcul de taille
            //   du groupe) ;
            // - HeroCarousel puis "Continuer à regarder", qui déterminent
            //   la taille réelle du groupe.
            // La dissolution complète (jamais un aplat de substitution —
            // une seule surface peinte au final, celle de la page) est
            // garantie au plus tard à la hauteur minimale du carrousel
            // (`HeroCarousel.minHeightFor`), la seule hauteur de contenu
            // garantie ici — "Continuer à regarder" peut être vide. Inséré
            // à `sideBarInset` : la barre latérale reste sur
            // AppColors.background pur, jamais teintée.
            SliverPadding(
              padding: EdgeInsetsDirectional.only(start: sideBarInset),
              sliver: heroItems.isEmpty
                  ? ContinueWatchingSection(
                      items: continueWatching,
                      contentPadding: innerPadding,
                    )
                  : SliverStack(
                      children: [
                        SliverPositioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          height: density == AppDensity.couch ? 1000.0 : 900.0,
                          child: FadingHeroBackdrop(
                            image: heroImage,
                            heroTint: context.tokens.heroTint,
                            fadeCompleteBy: HeroCarousel.minHeightFor(density),
                            rampDistance: heroRampDistance,
                            resolveDistance: heroResolveDistance,
                          ),
                        ),
                        SliverMainAxisGroup(
                          slivers: [
                            // Pleine largeur, jusqu'aux bords : pas de
                            // SliverPadding ici, contrairement au reste de
                            // la page. L'alignement de son contenu
                            // (sur-titre, titre, etc.) avec les titres de
                            // section en dessous vient uniquement du
                            // padding interne du bandeau
                            // (AppSpacing.screenPadding), pas d'un padding
                            // externe superposé.
                            SliverToBoxAdapter(
                              child: HeroCarousel(
                                items: heroItems,
                                onCurrentChanged: (item) =>
                                    setState(() => _heroCurrent = item),
                              ),
                            ),
                            SliverPadding(
                              padding:
                                  const EdgeInsets.only(top: AppSpacing.xl),
                              sliver: ContinueWatchingSection(
                                items: continueWatching,
                                contentPadding: innerPadding,
                              ),
                            ),
                          ],
                        ),
                      ],
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
