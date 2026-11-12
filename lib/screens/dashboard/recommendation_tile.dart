import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinos/arr/providers/arr_jellyfin_link_provider.dart';
import 'package:kinos/providers/user_provider.dart';
import 'package:kinos/util/localization_helper.dart';
import 'package:kinos/jellyfin/jellyfin_open_api.swagger.dart' show BaseItemDto;
import 'package:kinos/models/items/movie_model.dart';
import 'package:kinos/models/items/series_model.dart';
import 'package:kinos/screens/shared/media_navigation.dart';
import 'package:flutter/material.dart';

import 'package:kinos/arr/models/arr_library_entry.dart';
import 'package:kinos/arr/models/arr_service.dart';
import 'package:kinos/models/item_base_model.dart';
import 'package:kinos/models/items/images_models.dart';
import 'package:kinos/models/seerr/seerr_dashboard_model.dart';
import 'package:kinos/seerr/seerr_models.dart';
import 'package:kinos/routes/auto_router.gr.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/kinos_image.dart';
import 'package:kinos/widgets/shared/grid_focus_traveler.dart';
import 'package:kinos/widgets/shared/poster_caption.dart';

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
  final Object identity;
  final ImageData? previewImage;
  final String title;

  /// Année (ou autre mention) sous le titre, quand on la connaît.
  final String? subtitle;
  final Widget Function(BuildContext context) buildPoster;
  final Future<void> Function(BuildContext context) navigate;

  const RecommendationTile({
    required this.identity,
    this.previewImage,
    required this.title,
    this.subtitle,
    required this.buildPoster,
    required this.navigate,
  });

  factory RecommendationTile.jellyfin({required ItemBaseModel item}) {
    return RecommendationTile(
      identity: ('jellyfin', item.id),
      previewImage: item.getPosters?.primary ??
          item.getPosters?.thumb ??
          item.getPosters?.randomBackDrop,
      title: item.name,
      subtitle: item.subText,
      buildPoster: (context) => _jellyfinPoster(item),
      navigate: (context) => openMediaDetails(context, item),
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
      identity: ('arr', entry.isMovie, entry.id),
      previewImage:
          entry.posterUrl == null ? null : _ArrPosterImage(entry.posterUrl!),
      title: entry.title,
      subtitle: entry.year?.toString(),
      buildPoster: (context) => _arrPoster(entry.posterUrl),
      navigate: (context) => _openArrTitle(context,
          id: entry.id,
          isMovie: entry.isMovie,
          title: entry.title,
          year: entry.year,
          image: entry.posterUrl == null
              ? null
              : _ArrPosterImage(entry.posterUrl!),
          knownMatch: jellyfinMatch),
    );
  }

  /// Film absent de la bibliothèque, à demander : ouvre sa fiche Seerr.
  /// Jaquette distante (Letterboxd), marquée « À demander » sur un voile.
  factory RecommendationTile.request({
    required int tmdbId,
    required String title,
    int? year,
    String? posterUrl,
  }) {
    final image = posterUrl == null
        ? null
        : ImageData(path: posterUrl, key: 'request:$tmdbId');
    return RecommendationTile(
      identity: ('request', tmdbId),
      previewImage: image,
      title: title,
      subtitle: year?.toString(),
      buildPoster: (context) => RequestPoster(image: image),
      navigate: (context) => pushMediaRoute(
          context,
          SeerrDetailsRoute(
            tag: MediaNavigationScope.tagOf(context),
            mediaType: 'movie',
            tmdbId: tmdbId,
            poster: SeerrDashboardPosterModel(
                id: 'tmdb:movie:$tmdbId',
                type: SeerrMediaType.movie,
                tmdbId: tmdbId,
                title: title,
                overview: '',
                images: ImagesData(primary: image),
                mediaStatus: SeerrMediaStatus.unknown,
                jellyfinItemId: null,
                releaseYear: year?.toString()),
          )),
    );
  }

  /// Le cache fournit aussi le type : la fiche peut exister dès la première frame du Hero.
  factory RecommendationTile.cachedJellyfin({
    required String itemId,
    required String title,
    required ImageData image,
    required bool isMovie,
    int? year,
  }) {
    return RecommendationTile.jellyfin(
        item: _libraryItem(
            itemId: itemId,
            title: title,
            image: image,
            isMovie: isMovie,
            year: year));
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
    int? year,
  }) {
    return RecommendationTile(
      identity: ('arr', isMovie, arrId),
      previewImage:
          posterUrl.isEmpty ? null : _ArrPosterImage(posterUrl, apiKey: apiKey),
      title: title,
      subtitle: year?.toString(),
      buildPoster: (context) => _arrPoster(posterUrl, apiKey: apiKey),
      navigate: (context) => _openArrTitle(context,
          id: arrId,
          isMovie: isMovie,
          title: title,
          year: year,
          image: posterUrl.isEmpty
              ? null
              : _ArrPosterImage(posterUrl, apiKey: apiKey)),
    );
  }
}

ItemBaseModel _libraryItem(
    {required String itemId,
    required String title,
    required ImageData? image,
    required bool isMovie,
    int? year}) {
  final dto = BaseItemDto(
      id: itemId,
      name: title,
      productionYear: year,
      premiereDate: DateTime(year ?? 0));
  final images = ImagesData(primary: image);
  return isMovie
      ? MovieModel.fromBaseDto(dto, null).copyWith(images: images)
      : SeriesModel.fromBaseDto(dto, null).copyWith(images: images);
}

Future<void> _openArrTitle(BuildContext context,
    {required int id,
    required bool isMovie,
    required String title,
    int? year,
    ImageData? image,
    ItemBaseModel? knownMatch}) async {
  if (knownMatch != null) {
    await openMediaDetails(context, knownMatch);
    return;
  }
  final container = ProviderScope.containerOf(context, listen: false);
  final account = container.read(userProvider);
  final accountKey =
      (account?.id, account?.credentials.serverId, account?.credentials.url);
  final source = ModalRoute.of(context);
  final focus = MediaNavigationScope.focusOf(context);
  focus?.requestFocus();
  final provider =
      arrJellyfinLinkProvider((title: title, year: year, isMovie: isMovie));
  final subscription = container.listen(provider, (_, __) {});
  ArrJellyfinLinkMatch? match;
  try {
    match = await container.read(provider.future);
  } finally {
    subscription.close();
  }
  if (!context.mounted ||
      source?.isCurrent == false ||
      (focus != null && !focus.hasFocus)) {
    return;
  }
  final active = container.read(userProvider);
  if ((active?.id, active?.credentials.serverId, active?.credentials.url) !=
      accountKey) {
    return;
  }
  if (match != null) {
    await openMediaDetails(
        context,
        _libraryItem(
            itemId: match.id,
            title: match.name,
            image: image,
            isMovie: isMovie,
            year: year));
  } else {
    await pushMediaRoute(
        context,
        ArrTitleDetailsRoute(
            service: isMovie ? ArrService.radarr : ArrService.sonarr,
            id: id,
            title: title,
            image: image,
            tag: MediaNavigationScope.tagOf(context)));
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
  return KinosImage(
      image: _ArrPosterImage(posterUrl, apiKey: apiKey),
      imageErrorBuilder: (_, __, ___) => _missingPoster());
}

class _ArrPosterImage extends ImageData {
  _ArrPosterImage(String url, {this.apiKey}) : super(path: url, key: url);
  final String? apiKey;
  @override
  ImageProvider get imageProvider => NetworkImage(path,
      headers: apiKey == null ? null : {'X-Api-Key': apiKey!});
}

/// Jaquette d'un titre à demander : libellé « À demander » sur voile sombre
/// dégradé, lisible quelle que soit l'affiche (cf. CLAUDE.md § Texte sur
/// image). Commune à toutes les rangées de l'accueil.
class RequestPoster extends StatelessWidget {
  const RequestPoster({required this.image, super.key});
  final ImageData? image;

  @override
  Widget build(BuildContext context) =>
      Stack(fit: StackFit.expand, children: [
        if (image case final image?)
          KinosImage(
              image: image,
              fit: BoxFit.cover,
              imageErrorBuilder: (_, __, ___) => _missingPoster())
        else
          _missingPoster(),
        Align(
          alignment: Alignment.bottomCenter,
          child: FractionallySizedBox(
            heightFactor: .6,
            widthFactor: 1,
            child: DecoratedBox(
                decoration: BoxDecoration(
                    gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                  AppColors.scrim.withValues(alpha: .85),
                  Colors.transparent
                ]))),
          ),
        ),
        Positioned(
          left: AppSpacing.xs,
          right: AppSpacing.xs,
          bottom: AppSpacing.xs,
          child: Row(children: [
            Icon(Icons.add_rounded,
                size: AppTypography.meta.fontSize,
                color: AppColors.textPrimary),
            const SizedBox(width: AppSpacing.xxs),
            Expanded(
                child: Text(context.localized.discoveryToRequest,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.meta
                        .copyWith(color: AppColors.textPrimary))),
          ]),
        ),
      ]);
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

  /// Accès au surplus (« tout voir »), comme `SingleRowSection`.
  final VoidCallback? onSeeAll;

  const RecommendationRowGrid({
    required this.title,
    required this.tiles,
    required this.contentPadding,
    this.onSeeAll,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(builder: (context, constraints) {
      final width = constraints.crossAxisExtent - contentPadding.horizontal;
      final columns = context.tokens.density.columnsFor(width);
      final visible = tiles.take(columns).toList();
      final tileWidth =
          (width - (columns - 1) * AppSpacing.gridGap) / columns;

      return SliverMainAxisGroup(
        slivers: [
        SliverPadding(
          padding: contentPadding,
          sliver: SliverToBoxAdapter(
            child: Row(children: [
              Expanded(
                  child: Text(title,
                      style: Theme.of(context).textTheme.headlineMedium)),
              if (onSeeAll != null)
                FocusRing(
                  borderRadius: AppRadii.controlBorder,
                  onActivate: onSeeAll,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs, vertical: AppSpacing.xxs),
                    child: Text('tout voir',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.textPrimary)),
                  ),
                ),
            ]),
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
              mainAxisExtent: captionedPosterHeight(context, tileWidth),
            ),
            itemBuilder: (context, selectedIndex, index) =>
                _RecommendationTileWidget(tile: visible[index]),
          ),
        ),
      ],
      );
    });
  }
}

/// Toutes les tuiles sur autant de lignes que nécessaire (page « tout
/// voir ») — même cellule et même navigation clavier que
/// [RecommendationRowGrid].
class RecommendationTileGrid extends StatelessWidget {
  final List<RecommendationTile> tiles;
  final EdgeInsets contentPadding;

  const RecommendationTileGrid(
      {required this.tiles, required this.contentPadding, super.key});

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(builder: (context, constraints) {
      final width = constraints.crossAxisExtent - contentPadding.horizontal;
      final columns = context.tokens.density.columnsFor(width);
      final tileWidth =
          (width - (columns - 1) * AppSpacing.gridGap) / columns;
      return SliverPadding(
        padding: contentPadding,
        sliver: GridFocusTraveler(
          itemCount: tiles.length,
          crossAxisCount: columns,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: AppSpacing.gridGap,
            mainAxisSpacing: AppSpacing.gridGap,
            mainAxisExtent: captionedPosterHeight(context, tileWidth),
          ),
          itemBuilder: (context, selectedIndex, index) =>
              _RecommendationTileWidget(tile: tiles[index]),
        ),
      );
    });
  }
}

class _RecommendationTileWidget extends StatefulWidget {
  final RecommendationTile tile;

  const _RecommendationTileWidget({required this.tile});

  @override
  State<_RecommendationTileWidget> createState() =>
      _RecommendationTileWidgetState();
}

class _RecommendationTileWidgetState extends State<_RecommendationTileWidget> {
  bool _opening = false;
  RecommendationTile get tile => widget.tile;

  Future<void> _open(BuildContext context) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      await tile.navigate(context);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MediaNavigation(
        key: ValueKey(tile.identity),
        previewImage: tile.previewImage,
        builder: (context) => FocusRing(
              posterMotion: true,
              focusNode: MediaNavigationScope.focusOf(context),
              onActivate: () => _open(context),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AspectRatio(
                      aspectRatio: AppMedia.posterAspectRatio,
                      child: ClipRRect(
                        borderRadius: AppRadii.cardBorder,
                        child: ColoredBox(
                          color: AppColors.surface,
                          child: Stack(fit: StackFit.expand, children: [
                            MediaArtwork(child: tile.buildPoster(context)),
                            if (_opening)
                              IgnorePointer(
                                  child: Center(
                                      child: SizedBox.square(
                                          dimension: AppSpacing.lg,
                                          child: CircularProgressIndicator(
                                              color: AppColors.textPrimary,
                                              strokeWidth: context
                                                  .tokens.density.focusWidth,
                                              semanticsLabel:
                                                  context.localized.loading)))),
                          ]),
                        ),
                      ),
                    ),
                    PosterCaption(title: tile.title, subtitle: tile.subtitle),
                  ]),
            ));
  }
}
