import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kinos/jellyfin/jellyfin_open_api.enums.swagger.dart';
import 'package:kinos/letterboxd/home/letterboxd_home_sections.dart';
import 'package:kinos/models/item_base_model.dart';
import 'package:kinos/models/items/images_models.dart';
import 'package:kinos/providers/dashboard/catalog_navigation_provider.dart';
import 'package:kinos/providers/dashboard/genre_browse_provider.dart';
import 'package:kinos/routes/auto_router.gr.dart';
import 'package:kinos/screens/dashboard/genre_hero.dart';
import 'package:kinos/screens/dashboard/recommendation_tile.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/adaptive_layout/adaptive_layout.dart';

/// Ouvre la page du genre [genre] dans la portée [scope]. Une vraie page du
/// routeur : le logo, la barre du haut et le menu latéral la quittent comme
/// n'importe quelle autre.
Future<void> openGenrePage(
        BuildContext context, CatalogScope scope, BrowseGenre genre) =>
    context.router.push(GenrePageRoute(
        label: genre.label,
        names: genre.names,
        kind: scope.kind,
        libraryId: scope.libraryId,
        image: genre.image));

/// Page d'un genre : grand titre sur une image du genre, puis des rangées
/// (mieux notés, récents, pas encore vus, films et séries séparés sur
/// « À la une », Letterboxd, une par décennie), et l'accès à tout le genre
/// dans la recherche. Échap ou la flèche reviennent à l'accueil.
@RoutePage()
class GenrePageScreen extends ConsumerWidget {
  const GenrePageScreen({
    required this.label,
    required this.names,
    this.kind,
    this.libraryId,
    this.image,
    super.key,
  });
  final String label;
  final List<String> names;
  final BaseItemKind? kind;
  final String? libraryId;
  final ImageData? image;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CatalogScope scope = (kind: kind, libraryId: libraryId);
    final page = ref.watch(genrePageProvider(genrePageKey(scope, names)));
    final padding = AdaptiveLayout.adaptivePadding(context,
        horizontalPadding: AppSpacing.screenPadding);
    final bannerHeight = (MediaQuery.sizeOf(context).height *
            AppGenrePage.bannerHeightFraction)
        .clamp(AppGenrePage.bannerMinHeight, AppGenrePage.bannerMaxHeight);

    List<RecommendationTile> tiles(List<ItemBaseModel> items) =>
        [for (final item in items) RecommendationTile.jellyfin(item: item)];

    void seeAll() => context.router.push(LibrarySearchRoute(
          recursive: true,
          genres: {for (final name in names) name: true},
          types: kind == null
              ? null
              : {
                  kind == BaseItemKind.movie
                      ? KinosItemType.movie
                      : KinosItemType.series: true
                },
        ));

    Widget row(String title, List<ItemBaseModel> items) => items.isEmpty
        ? const SliverToBoxAdapter(child: SizedBox.shrink())
        : SliverPadding(
            padding: const EdgeInsets.only(top: AppSpacing.xl),
            sliver: RecommendationRowGrid(
                title: title, tiles: tiles(items), contentPadding: padding),
          );

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            context.router.maybePop(),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: CustomScrollView(slivers: [
            SliverToBoxAdapter(
              child: SizedBox(
                height: bannerHeight,
                child: Stack(fit: StackFit.expand, children: [
                  // Le bandeau est l'image de la tuile, arrivée en haut de la
                  // page (cf. genre_hero.dart).
                  genreBackdropHero(context,
                      tag: genreImageTag(kind, libraryId, label),
                      image: image,
                      mix: 1),
                  Padding(
                    padding: padding.copyWith(top: AppSpacing.xl),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Tooltip(
                        message: 'Retour · Échap',
                        child: FocusRing(
                          borderRadius: AppRadii.controlBorder,
                          onActivate: () => context.router.maybePop(),
                          child: const Padding(
                            padding: EdgeInsets.all(AppSpacing.xs),
                            child:
                                Icon(Icons.arrow_back, semanticLabel: 'Retour'),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: padding.copyWith(bottom: AppSpacing.md),
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: genreTitleHero(context,
                          tag: genreTitleTag(kind, libraryId, label),
                          label: label,
                          big: true),
                    ),
                  ),
                ]),
              ),
            ),
            if (page.valueOrNull case final data?) ...[
              row('Les mieux notés', data.topRated),
              row('Ajoutés récemment', data.recent),
              row('Pas encore vus', data.unvisited),
              row('Films', data.movies),
              row('Séries', data.series),
              LetterboxdGenreSections(label: label, contentPadding: padding),
              for (final MapEntry(key: decade, value: items)
                  in data.decades.entries)
                row('Les ${decade}s', items),
              SliverToBoxAdapter(
                child: Padding(
                  padding: padding.copyWith(top: AppSpacing.lg),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                        onPressed: seeAll, child: Text('Voir tout : $label')),
                  ),
                ),
              ),
            ] else if (page.hasError)
              SliverToBoxAdapter(
                child: Padding(
                  padding: padding.copyWith(top: AppSpacing.xl),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                        onPressed: () => ref.invalidate(
                            genrePageProvider(genrePageKey(scope, names))),
                        child: const Text('Genre indisponible · Réessayer')),
                  ),
                ),
              )
            else
              const SliverPadding(
                padding: EdgeInsets.only(top: AppSpacing.xxl),
                sliver: SliverToBoxAdapter(
                    child: Center(child: CircularProgressIndicator())),
              ),
            const SliverPadding(
                padding: EdgeInsets.only(bottom: AppSpacing.xxl)),
          ]),
        ),
      ),
    );
  }
}
