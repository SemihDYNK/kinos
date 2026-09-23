import 'package:flutter/material.dart';

import 'package:auto_route/auto_route.dart';

import 'package:kinos/arr/models/arr_library_entry.dart';
import 'package:kinos/arr/models/arr_service.dart';
import 'package:kinos/models/item_base_model.dart';
import 'package:kinos/models/items/images_models.dart';
import 'package:kinos/routes/auto_router.gr.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/kinos_image.dart';
import 'package:kinos/widgets/shared/grid_focus_traveler.dart';

/// Une entrée affichable dans une rangée de recommandation — pont entre
/// le résultat du moteur (id/score, sans notion d'affichage) et ce
/// qu'il faut peindre et où naviguer au clic. Deux origines possibles,
/// unifiées par ces deux fermetures plutôt que par une union de champs
/// Jellyfin/Arr : une tuile peut aussi bien venir d'un objet vivant
/// (`ItemBaseModel`/`ArrLibraryEntry`, rangée "en direct") que d'une
/// ligne de `RecommendationCacheEntries` reconstruite au minimum (cf.
/// `recommendation_row_section.dart`,
/// `_cachedRecommendationTilesProvider`) — les deux cas partagent
/// exactement la même forme d'affichage.
///
/// Extrait de `recommendation_row_section.dart` (lot des rangées par
/// graine + inventaire du catalogue) pour être partagé avec
/// `seed_row_section.dart` — une rangée par graine réutilise exactement
/// le même rendu (jaquette, navigation) que "Pour vous", juste
/// restreinte à un trait.
///
/// Ne porte plus de justification affichable : la raison ("Produit par
/// X", "Parce que vous avez regardé Y") ne s'affiche plus au survol —
/// le calcul sous-jacent (`ScoredCandidate.justification`, une clé de
/// diversité et de titre pour les rangées par graine) reste entièrement
/// dans le moteur, cf. `recommendation_scorer.dart`/
/// `home_catalog_providers.dart`, aucun des deux non touché.
class RecommendationTile {
  final String title;
  final Widget Function(BuildContext context) buildPoster;
  final void Function(BuildContext context) navigate;

  const RecommendationTile({
    required this.title,
    required this.buildPoster,
    required this.navigate,
  });

  factory RecommendationTile.jellyfin({required ItemBaseModel item}) {
    return RecommendationTile(
      title: item.name,
      buildPoster: (context) => _jellyfinPoster(item),
      navigate: (context) => item.navigateTo(context),
    );
  }

  factory RecommendationTile.arr({
    required ArrLibraryEntry entry,
    // Destination du clic (troisième calibrage du lot B) : si cette
    // entrée existe malgré tout dans Jellyfin (cf.
    // `RecommendationResult.arrJellyfinMatchesById`), la carte doit
    // ouvrir sa fiche Jellyfin — jamais l'affichage (jaquette/titre
    // restent ceux d'`entry`, cf. spec : cette rangée montre "ce qui a
    // été mis de côté", pas un doublon déguisé de la rangée Jellyfin).
    ItemBaseModel? jellyfinMatch,
  }) {
    return RecommendationTile(
      title: entry.title,
      buildPoster: (context) => _arrPoster(entry.posterUrl),
      navigate: (context) {
        if (jellyfinMatch != null) {
          jellyfinMatch.navigateTo(context);
          return;
        }
        context.router.push(ArrDetailRoute(
          service: entry.isMovie ? ArrService.radarr : ArrService.sonarr,
          id: entry.id,
        ));
      },
    );
  }

  /// Depuis le cache — jaquette reconstruite depuis le seul id
  /// (`imageUtilityProvider.getItemsImageUrl`, vérifié : aucun tag
  /// d'image requis), navigation par id seul (`DetailsRoute(id: ...)`,
  /// même construction que les liens profonds et que la redirection Arr
  /// -> Jellyfin en direct — la fiche se charge elle-même, pas besoin de
  /// l'objet complet).
  factory RecommendationTile.cachedJellyfin({
    required String itemId,
    required String title,
    required ImageData image,
  }) {
    return RecommendationTile(
      title: title,
      buildPoster: (context) => KinosImage(image: image, fit: BoxFit.cover),
      navigate: (context) => context.router.push(DetailsRoute(id: itemId)),
    );
  }

  /// Depuis le cache — jaquette reconstruite depuis l'id Arr et les
  /// identifiants *actuels* de l'instance (`arrNativePosterUrl`, en-tête
  /// `X-Api-Key`, jamais une clé embarquée dans une URL conservée sur
  /// disque) : cf. `recommendation_cache_table.dart` sur pourquoi
  /// l'URL de jaquette elle-même n'est jamais persistée.
  factory RecommendationTile.cachedArr({
    required int arrId,
    required bool isMovie,
    required String title,
    required String posterUrl,
    required String apiKey,
  }) {
    return RecommendationTile(
      title: title,
      buildPoster: (context) => _arrPoster(posterUrl, apiKey: apiKey),
      navigate: (context) => context.router.push(ArrDetailRoute(
        service: isMovie ? ArrService.radarr : ArrService.sonarr,
        id: arrId,
      )),
    );
  }
}

/// Jaquette d'une tuile "en direct" côté Jellyfin — même repli que
/// `SingleRowSection._Tile` : contain sur fond surface pour une image
/// 16:9 (thumb/backdrop) dans une cellule 2:3, cover pour primary (déjà
/// en 2:3, rien à recadrer).
Widget _jellyfinPoster(ItemBaseModel item) {
  final image = item.getPosters?.primary;
  final fallback = image == null
      ? (item.getPosters?.thumb ?? item.getPosters?.randomBackDrop)
      : null;
  return KinosImage(
    image: image ?? fallback,
    fit: image != null ? BoxFit.cover : BoxFit.contain,
  );
}

/// Jaquette d'une tuile Arr — `apiKey` non nul seulement pour une tuile
/// en cache (cf. `RecommendationTile.cachedArr`) : côté direct,
/// `entry.posterUrl` porte déjà sa propre authentification quand elle
/// est nécessaire (`resolveArrPosterUrl`, construite à la lecture de la
/// bibliothèque).
Widget _arrPoster(String? posterUrl, {String? apiKey}) {
  if (posterUrl == null || posterUrl.isEmpty) return _missingPoster();
  return Image.network(
    posterUrl,
    headers: apiKey == null ? null : {'X-Api-Key': apiKey},
    fit: BoxFit.cover,
    errorBuilder: (context, error, stackTrace) => _missingPoster(),
  );
}

Widget _missingPoster() => const Center(
      child: Icon(Icons.movie_creation_outlined,
          color: AppColors.textDisabled, size: 32),
    );

/// Grille à une ligne, structurée comme `SingleRowSection` (titre, une
/// seule ligne de jaquettes, navigation clavier via
/// [GridFocusTraveler]).
class RecommendationRowGrid extends StatelessWidget {
  final String title;
  final List<RecommendationTile> tiles;
  final EdgeInsets contentPadding;

  const RecommendationRowGrid({
    required this.title,
    required this.tiles,
    required this.contentPadding,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width - contentPadding.horizontal;
    final columns = context.tokens.density.columnsFor(width);
    final visible = tiles.take(columns).toList();

    return SliverMainAxisGroup(
      slivers: [
        SliverPadding(
          padding: contentPadding,
          sliver: SliverToBoxAdapter(
            child:
                Text(title, style: Theme.of(context).textTheme.headlineMedium),
          ),
        ),
        SliverPadding(
          padding: contentPadding.copyWith(top: AppSpacing.sm),
          sliver: GridFocusTraveler(
            itemCount: visible.length,
            crossAxisCount: columns,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: AppSpacing.gridGap,
              mainAxisSpacing: AppSpacing.gridGap,
              childAspectRatio: 2 / 3,
            ),
            itemBuilder: (context, selectedIndex, index) =>
                _RecommendationTileWidget(tile: visible[index]),
          ),
        ),
      ],
    );
  }
}

class _RecommendationTileWidget extends StatelessWidget {
  final RecommendationTile tile;

  const _RecommendationTileWidget({required this.tile});

  @override
  Widget build(BuildContext context) {
    return FocusRing(
      onActivate: () => tile.navigate(context),
      child: ClipRRect(
        borderRadius: AppRadii.cardBorder,
        child: ColoredBox(
          color: AppColors.surface,
          child: tile.buildPoster(context),
        ),
      ),
    );
  }
}
