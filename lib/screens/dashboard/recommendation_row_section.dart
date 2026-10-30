import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kinos/arr/models/arr_library_poster.dart';
import 'package:kinos/arr/models/arr_service.dart';
import 'package:kinos/arr/providers/arr_providers.dart'
    show arrCredentialsStoreProvider;
import 'package:kinos/models/items/images_models.dart';
import 'package:kinos/models/settings/home_row_model.dart';
import 'package:kinos/models/syncing/database_item.dart';
import 'package:kinos/providers/database_provider.dart';
import 'package:kinos/providers/image_provider.dart';
import 'package:kinos/providers/user_provider.dart';
import 'package:kinos/recommendations/providers/recommendation_providers.dart';
import 'package:kinos/screens/dashboard/recommendation_tile.dart';

/// Rangée "Pour vous" — classement Jellyfin de
/// `recommendationResultProvider`. `autoDispose` : la requête ne part que quand cette
/// effectivement construite (elle approche du champ de vision), comme
/// toute autre rangée de l'accueil — le calcul lui-même est mis en
/// cache par le provider (`ref.keepAlive()` après succès, cf.
/// `recommendation_providers.dart`), donc un aller-retour hors champ
/// puis retour ne le relance jamais dans la même session.
///
/// Persistance : si le cache est assez frais (cf.
/// `recommendationRecomputeNeededProvider`, seuil de 24 h), cette rangée
/// se contente du cache et ne déclenche jamais
/// `recommendationResultProvider` — jamais de recalcul complet juste
/// parce que l'accueil s'est rouvert. Sinon (cache absent, périmé, ou
/// marqueur trop vieux), le calcul frais tourne normalement ; pendant
/// qu'il charge ou s'il échoue, la rangée affiche le dernier résultat
/// connu plutôt que rien.
class ForYouRowSection extends ConsumerWidget {
  final HomeRowModel row;
  final EdgeInsets contentPadding;

  const ForYouRowSection({
    required this.row,
    required this.contentPadding,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cached = ref.watch(
        _cachedRecommendationTilesProvider(RecommendationRowKind.forYou));
    final recomputeNeeded =
        ref.watch(recommendationRecomputeNeededProvider).valueOrNull;

    if (recomputeNeeded == false) {
      return _cacheOnly(
          row: row, contentPadding: contentPadding, cached: cached);
    }

    final live = ref.watch(recommendationResultProvider);
    return live.when(
      data: (data) {
        final tiles = <RecommendationTile>[
          for (final scored in data.candidates)
            if (data.jellyfinItemsById[scored.item.id] case final item?)
              RecommendationTile.jellyfin(item: item),
        ];
        if (tiles.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }
        return RecommendationRowGrid(
          title: row.title,
          tiles: tiles,
          contentPadding: contentPadding,
        );
      },
      // Calcul pas encore prêt ou en échec : jamais d'erreur ni de
      // squelette visible — la rangée retombe sur le cache, silencieuse
      // s'il n'y en a pas non plus (ex. premier lancement).
      loading: () =>
          _cacheOnly(row: row, contentPadding: contentPadding, cached: cached),
      error: (error, stack) =>
          _cacheOnly(row: row, contentPadding: contentPadding, cached: cached),
    );
  }
}

/// Rangée "Vous l'aviez mis de côté" — classement Arr de
/// `recommendationResultProvider`, trié par date d'ajout (cf. le
/// commentaire sur `RecommendationResult` : ce n'est plus un classement
/// de goût). Même principe de chargement, de cache, et de recalcul
/// borné à 24 h que [ForYouRowSection].
class SetAsideRowSection extends ConsumerWidget {
  final HomeRowModel row;
  final EdgeInsets contentPadding;

  const SetAsideRowSection({
    required this.row,
    required this.contentPadding,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cached = ref.watch(
        _cachedRecommendationTilesProvider(RecommendationRowKind.setAside));
    final recomputeNeeded =
        ref.watch(recommendationRecomputeNeededProvider).valueOrNull;

    if (recomputeNeeded == false) {
      return _cacheOnly(
          row: row, contentPadding: contentPadding, cached: cached);
    }

    final live = ref.watch(recommendationResultProvider);
    return live.when(
      data: (data) {
        final tiles = <RecommendationTile>[
          for (final scored in data.arrOnlyCandidates)
            if (data.arrEntriesById[scored.item.id] case final entry?)
              RecommendationTile.arr(
                entry: entry,
                // Destination du clic : si cette entrée existe malgré
                // tout dans Jellyfin (cf.
                // `RecommendationResult.arrJellyfinMatchesById`), la
                // carte doit ouvrir sa fiche Jellyfin, pas sa fiche Arr
                // — depuis l'accueil on veut lire, pas gérer.
                jellyfinMatch: data.arrJellyfinMatchesById[scored.item.id],
              ),
        ];
        if (tiles.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }
        return RecommendationRowGrid(
          title: row.title,
          tiles: tiles,
          contentPadding: contentPadding,
        );
      },
      loading: () =>
          _cacheOnly(row: row, contentPadding: contentPadding, cached: cached),
      error: (error, stack) =>
          _cacheOnly(row: row, contentPadding: contentPadding, cached: cached),
    );
  }
}

/// Rendu depuis le cache seul — cf. spec : "si le calcul frais échoue
/// ou n'aboutit pas, la rangée reste sur le cache sans rien signaler",
/// et le même principe s'applique quand le calcul frais n'a jamais été
/// déclenché (cache assez frais, cf.
/// `recommendationRecomputeNeededProvider`). Silencieuse si le cache est
/// lui-même vide ou pas encore prêt — exactement comme un premier
/// lancement sans aucun cache.
Widget _cacheOnly({
  required HomeRowModel row,
  required EdgeInsets contentPadding,
  required AsyncValue<List<RecommendationTile>> cached,
}) {
  final tiles = cached.valueOrNull ?? const <RecommendationTile>[];
  if (tiles.isEmpty) {
    return const SliverToBoxAdapter(child: SizedBox.shrink());
  }
  return RecommendationRowGrid(
    title: row.title,
    tiles: tiles,
    contentPadding: contentPadding,
  );
}

/// Lit `RecommendationCacheEntries` pour une rangée et reconstruit des
/// tuiles affichables — jaquette et destination de clic reconstruites
/// depuis le minimum persisté (cf. `recommendation_cache_table.dart`),
/// sans aucun accès à `recommendationResultProvider` : les deux
/// providers sont entièrement indépendants, c'est ce qui garantit que
/// l'un n'attend jamais l'autre — y compris quand le calcul frais n'est
/// jamais déclenché (cf. `recommendationRecomputeNeededProvider`), cette
/// rangée reste alors la seule source réelle du rendu.
///
/// `autoDispose.family` : une requête par rangée, seulement quand elle
/// est effectivement observée — même principe que le reste de l'accueil.
final _cachedRecommendationTilesProvider = FutureProvider.autoDispose
    .family<List<RecommendationTile>, RecommendationRowKind>(
        (ref, rowKind) async {
  final userId = ref.read(userProvider)?.id;
  if (userId == null || userId.isEmpty) return const [];

  final db = ref.read(appDatabaseProvider);
  final rows =
      await db.getRecommendationCache(userId: userId, rowKind: rowKind).get();
  if (rows.isEmpty) return const [];

  final needsRadarr = rows.any((r) => r.arrService == 'radarr');
  final needsSonarr = rows.any((r) => r.arrService == 'sonarr');
  var radarrCredentials = (baseUrl: '', apiKey: '', configured: false);
  var sonarrCredentials = (baseUrl: '', apiKey: '', configured: false);
  if (needsRadarr || needsSonarr) {
    final store = ref.read(arrCredentialsStoreProvider);
    if (needsRadarr) {
      final creds = await store.read(ArrService.radarr);
      if (creds != null && creds.isConfigured) {
        radarrCredentials =
            (baseUrl: creds.baseUrl, apiKey: creds.apiKey, configured: true);
      }
    }
    if (needsSonarr) {
      final creds = await store.read(ArrService.sonarr);
      if (creds != null && creds.isConfigured) {
        sonarrCredentials =
            (baseUrl: creds.baseUrl, apiKey: creds.apiKey, configured: true);
      }
    }
  }

  final imageUtility = ref.read(imageUtilityProvider);
  final tiles = <RecommendationTile>[];
  for (final row in rows) {
    if (row.source == RecommendationEntrySource.jellyfin) {
      final itemId = row.jellyfinItemId;
      if (itemId == null) continue;
      tiles.add(RecommendationTile.cachedJellyfin(
        itemId: itemId,
        isMovie: row.jellyfinItemType != 'series',
        year: row.year,
        title: row.title,
        image: ImageData(
          path: imageUtility.getItemsImageUrl(itemId),
          key: itemId,
        ),
      ));
    } else {
      final arrId = row.arrId;
      if (arrId == null) continue;
      final credentials =
          row.arrService == 'radarr' ? radarrCredentials : sonarrCredentials;
      if (!credentials.configured) continue;
      tiles.add(RecommendationTile.cachedArr(
        title: row.title,
        arrId: arrId,
        year: row.year,
        isMovie: row.arrService == 'radarr',
        posterUrl: arrNativePosterUrl(arrId, baseUrl: credentials.baseUrl),
        apiKey: credentials.apiKey,
      ));
    }
  }
  return tiles;
});
