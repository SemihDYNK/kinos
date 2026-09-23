import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kinos/arr/models/arr_library_entry.dart';
import 'package:kinos/arr/models/arr_library_item.dart';
import 'package:kinos/arr/models/arr_service.dart';
import 'package:kinos/arr/providers/arr_providers.dart'
    show arrCredentialsStoreProvider;
import 'package:kinos/arr/services/arr_api_client.dart';
import 'package:kinos/jellyfin/jellyfin_open_api.enums.swagger.dart';
import 'package:kinos/models/item_base_model.dart';
import 'package:kinos/models/syncing/database_item.dart';
import 'package:kinos/providers/api_provider.dart';
import 'package:kinos/providers/dashboard/home_row_random_seed_provider.dart';
import 'package:kinos/providers/database_provider.dart';
import 'package:kinos/providers/user_provider.dart';
import 'package:kinos/recommendations/adapters/arr_candidate_adapter.dart';
import 'package:kinos/recommendations/adapters/jellyfin_candidate_adapter.dart';
import 'package:kinos/recommendations/adapters/jellyfin_trait_extraction.dart';
import 'package:kinos/recommendations/adapters/jellyfin_watch_event_adapter.dart';
import 'package:kinos/recommendations/adapters/recommendation_cache_adapter.dart';
import 'package:kinos/recommendations/engine/arr_added_date_ranking.dart';
import 'package:kinos/recommendations/engine/arr_jellyfin_dedup.dart';
import 'package:kinos/recommendations/engine/paginated_fetch.dart';
import 'package:kinos/recommendations/engine/recommendation_scorer.dart';
import 'package:kinos/recommendations/engine/taste_profile_builder.dart';
import 'package:kinos/recommendations/models/scored_candidate.dart';

/// Champs Jellyfin nécessaires à l'extraction de traits — sans `fields:`
/// explicite, l'API ne renvoie ni les studios, ni les personnes, ni les
/// tags (cf. `usersUserIdItemsGet`/`usersUserIdItemsResumeGet` ailleurs
/// dans le client, même limitation).
///
/// `providerids`/`originaltitle` : pas des traits de goût, mais
/// nécessaires à `findKnownJellyfinMatch` (`arr_jellyfin_dedup.dart`) —
/// appariement Arr/Jellyfin par tmdbId/imdbId/tvdbId en priorité, par
/// titre original en repli.
const _traitFields = [
  ItemFields.genres,
  ItemFields.people,
  ItemFields.studios,
  ItemFields.tags,
  ItemFields.providerids,
  ItemFields.originaltitle,
];

const _itemTypes = [BaseItemKind.movie, BaseItemKind.series];

/// Films/séries que Jellyfin considère comme un visionnage terminé —
/// alimente `buildJellyfinWatchEvents` (revu/terminé favori/terminé
/// neutre). Volontairement sans limite : un historique tronqué fausse
/// la fréquence des traits (IDF) sur laquelle repose tout le profil.
/// `enableUserData: true` explicite — Jellyfin le suppose par défaut sur
/// ces routes, mais ne pas dépendre d'un défaut implicite pour la seule
/// donnée qui détermine si un signal se déclenche.
final playedItemsProvider =
    FutureProvider.autoDispose<List<ItemBaseModel>>((ref) async {
  final api = ref.read(jellyApiProvider);
  final response = await api.usersUserIdItemsGet(
    isPlayed: true,
    recursive: true,
    includeItemTypes: _itemTypes,
    fields: _traitFields,
  );
  return response.body?.items
          ?.map((e) => ItemBaseModel.fromBaseDto(e, ref))
          .toList() ??
      const [];
});

/// Films/séries repris ou abandonnés — alimente `buildJellyfinWatchEvents`
/// (abandon précoce/tardif) et sert aussi à exclure ce qui est "en
/// cours" des candidats (cf. spec).
///
/// `mediaTypes: [MediaType.video]`, jamais `includeItemTypes: _itemTypes`
/// (film/série) : un item "en cours" d'une série est un ÉPISODE
/// (`BaseItemKind.episode`), jamais la série elle-même — filtrer sur
/// `_itemTypes` ici excluait donc silencieusement tout abandon en cours
/// de série. Même filtre que `DashboardNotifier.fetchNextUpAndResume`
/// (`dashboard_provider.dart`), qui a le même besoin pour "Continuer à
/// regarder".
final resumableItemsProvider =
    FutureProvider.autoDispose<List<ItemBaseModel>>((ref) async {
  final api = ref.read(jellyApiProvider);
  final response = await api.usersUserIdItemsResumeGet(
    mediaTypes: [MediaType.video],
    fields: _traitFields,
    enableTotalRecordCount: false,
    enableUserData: true,
    limit: 200,
  );
  return response.body?.items
          ?.map((e) => ItemBaseModel.fromBaseDto(e, ref))
          .toList() ??
      const [];
});

/// Pagination concurrente pour [unwatchedLibraryProvider] — la requête
/// bibliothèque "non vus" était le goulot unique de l'accueil (45 s sur
/// un aller-retour unique). Calibrage : mesuré contre une requête unique
/// (45 s -> 29 s en pages de 200, concurrence 4), puis contre une
/// concurrence pleine à 6 (28,4 s contre 29,1 s, mais page la plus lente
/// en hausse de 50 % — 19,6 s contre 13,1 s, 69 % du total : le serveur
/// sature, pas de gain). Réglage retenu : pages de 200, concurrence 4 —
/// c'est le plancher réseau mesuré (~28-29 s) avec des pages
/// individuellement rapides, ce qui profite à la diffusion progressive
/// ci-dessous (premier aperçu en quelques secondes plutôt qu'en fin de
/// requête unique).
const useConcurrentUnwatchedFetch = true;
const unwatchedFetchPageSize = 200;
const unwatchedFetchConcurrency = 4;

/// Premier sous-ensemble "suffisant" de la bibliothèque "non vus" — la
/// première page seule, publiée dès qu'elle répond, bien avant que
/// [unwatchedLibraryProvider] lui-même n'aboutisse avec l'ensemble
/// complet. `null` avant que cette première page ne réponde, et remis à
/// `null` au tout début de chaque nouveau calcul de
/// [unwatchedLibraryProvider] — jamais un résidu d'un calcul précédent
/// affiché comme s'il était frais.
///
/// Consommé uniquement par `homeCatalogInventoryResultProvider`
/// (`home_catalog_providers.dart`), pour les catégories dont l'identité
/// ne dépend pas de la représentativité de l'échantillon (bien notés
/// films/séries, longs métrages — un simple filtre, jamais une
/// sélection parmi plusieurs). Délibérément pas utilisé pour "genres
/// étroits"/"décennies" (l'ensemble des rangées elles-mêmes pourrait
/// changer entre l'aperçu et la version complète) ni pour les rangées
/// par graine (un sous-ensemble biaisé pourrait faire remonter un trait
/// différent, donc un titre de rangée différent).
final unwatchedLibraryFirstPageProvider =
    StateProvider<List<ItemBaseModel>?>((ref) => null);

/// Bibliothèque Jellyfin non vue — source de candidats "normale" (cf.
/// spec § Sources). `isPlayed: false` exclut déjà ce qui est terminé ;
/// l'exclusion "en cours" (resumable) se fait via `excludedIds` au
/// moment du score, pas ici, pour ne dépendre que d'un seul filtre côté
/// serveur par requête.
final unwatchedLibraryProvider =
    FutureProvider.autoDispose<List<ItemBaseModel>>((ref) async {
  final api = ref.read(jellyApiProvider);
  ref.read(unwatchedLibraryFirstPageProvider.notifier).state = null;

  if (!useConcurrentUnwatchedFetch) {
    final response = await api.usersUserIdItemsGet(
      isPlayed: false,
      recursive: true,
      includeItemTypes: _itemTypes,
      fields: _traitFields,
    );
    return response.body?.items
            ?.map((e) => ItemBaseModel.fromBaseDto(e, ref))
            .toList() ??
        const [];
  }

  Future<PageResult<ItemBaseModel>> fetchPage(
      {required int startIndex, required int limit}) async {
    final response = await api.usersUserIdItemsGet(
      isPlayed: false,
      recursive: true,
      includeItemTypes: _itemTypes,
      fields: _traitFields,
      startIndex: startIndex,
      limit: limit,
      enableTotalRecordCount: true,
    );
    final items = response.body?.items
            ?.map((e) => ItemBaseModel.fromBaseDto(e, ref))
            .toList() ??
        const <ItemBaseModel>[];
    final total = response.body?.totalRecordCount ?? items.length;
    return (items: items, totalRecordCount: total);
  }

  final result = await fetchAllPagesConcurrently<ItemBaseModel>(
    fetchPage,
    pageSize: unwatchedFetchPageSize,
    concurrency: unwatchedFetchConcurrency,
    onFirstPage: (items) =>
        ref.read(unwatchedLibraryFirstPageProvider.notifier).state = items,
  );

  return result.items;
});

/// Bibliothèque Radarr/Sonarr, toutes instances configurées — source des
/// candidats "intention pure" (cf. spec).
///
/// N'utilise délibérément pas `arrLibraryProvider`/`radarrClientProvider`
/// (les providers déjà en place pour l'onglet Bibliothèque du module
/// Arr) : ces deux providers dérivent de `arrCredentialsProvider`, un
/// `StateNotifierProvider` qui charge les identifiants de façon
/// asynchrone à sa première lecture — `ref.read(...).valueOrNull`
/// immédiatement après peut retomber sur l'état initial
/// (`AsyncValue.loading()`, donc `null`) si rien n'a encore déclenché ce
/// chargement ailleurs dans la session. Lire directement le coffre
/// (`ArrCredentialsStore`, intrinsèquement asynchrone, sans cet état
/// intermédiaire) et construire les clients ici élimine la course
/// plutôt que de la déplacer.
final _arrLibraryEntriesProvider =
    FutureProvider.autoDispose<List<ArrLibraryEntry>>((ref) async {
  final store = ref.read(arrCredentialsStoreProvider);
  final entries = <ArrLibraryEntry>[];

  for (final service in ArrService.values) {
    final credentials = await store.read(service);
    if (credentials == null || !credentials.isConfigured) continue;

    switch (service) {
      case ArrService.radarr:
        final client = RadarrApiClient(
            baseUrl: credentials.baseUrl, apiKey: credentials.apiKey);
        try {
          final result = await client.searchMovies('');
          if (result case ArrSuccess<List<ArrMovie>>(:final data)) {
            entries.addAll(data.map(ArrLibraryEntry.movie));
          }
        } finally {
          client.close();
        }
      case ArrService.sonarr:
        final client = SonarrApiClient(
            baseUrl: credentials.baseUrl, apiKey: credentials.apiKey);
        try {
          final result = await client.searchSeries('');
          if (result case ArrSuccess<List<ArrSeries>>(:final data)) {
            entries.addAll(data.map(ArrLibraryEntry.series));
          }
        } finally {
          client.close();
        }
    }
  }
  return entries;
});

/// Résultat complet d'un calcul de recommandations.
///
/// [candidates] (Jellyfin) est un classement par affinité de goût.
/// [arrOnlyCandidates] n'en est plus un : les candidats Arr,
/// structurellement limités à genres/décennie/studio (Radarr/Sonarr
/// n'exposent ni réalisateur ni distribution), ne portent pas assez de
/// traits crédibles pour un vrai classement de goût — "une
/// recommandation qui ne peut pas se justifier ne vaut pas mieux qu'un
/// tri honnête". [arrOnlyCandidates] est donc trié par date d'ajout
/// décroissante (cf. `rankArrCandidatesByAddedDate`), l'affinité ne
/// servant plus que de critère secondaire à date proche. Les deux
/// listes s'excluent mutuellement (cf.
/// `excludeArrCandidatesKnownToJellyfin`) : une œuvre déjà connue de
/// Jellyfin, sous n'importe quel état, n'apparaît plus côté Arr — la
/// rangée [candidates] est prioritaire.
///
/// [jellyfinItemsById]/[arrEntriesById] : les objets d'origine (image,
/// navigation) derrière chaque candidat noté, indexés sur le même id
/// que [ScoredCandidate.item.id] — le moteur (`CandidateItem`) ne porte
/// délibérément ni image ni référence Jellyfin/Arr ; c'est la rangée
/// d'accueil (`lib/screens/dashboard/recommendation_row_section.dart`)
/// qui en a besoin pour rendre une vraie jaquette et naviguer vers la
/// bonne fiche.
///
/// [arrJellyfinMatchesById] : pour une entrée de [arrOnlyCandidates] qui
/// existe malgré tout dans Jellyfin (le dédoublonnage de la rangée
/// elle-même ne regarde que les candidats Jellyfin *avec traits*, cf.
/// `findKnownJellyfinMatch`), l'objet Jellyfin correspondant — la
/// rangée doit y naviguer au lieu de la fiche Arr. Absent de la table :
/// aucune correspondance connue, la fiche Arr reste la destination.
typedef RecommendationResult = ({
  List<ScoredCandidate> candidates,
  List<ScoredCandidate> arrOnlyCandidates,
  Map<String, ItemBaseModel> jellyfinItemsById,
  Map<String, ArrLibraryEntry> arrEntriesById,
  Map<String, ItemBaseModel> arrJellyfinMatchesById,
});

/// Calcule les recommandations pour l'utilisateur courant — `autoDispose`
/// avec `keepAlive()` après succès : un seul calcul par session, jamais
/// recalculé tant que rien ne force un `refresh` explicite (cf.
/// [recommendationRecomputeNeededProvider] pour la décision de le
/// déclencher au lancement).
///
/// Observé par les deux rangées d'accueil (lot B —
/// `lib/screens/dashboard/recommendation_row_section.dart`,
/// `ForYouRowSection`/`SetAsideRowSection`) et par
/// [recommendationRegistrySeedProvider] (`home_catalog_providers.dart`,
/// dédoublonnage avec les rangées plus bas sur la page) — les deux
/// passent par la même instance de ce provider, donc un calcul déjà mis
/// en cache par l'un profite immédiatement à l'autre.
final recommendationResultProvider =
    FutureProvider.autoDispose<RecommendationResult>((ref) async {
  final seed = ref.watch(homeRowRandomSeedProvider);
  final now = DateTime.now();

  final playedFuture = ref.watch(playedItemsProvider.future);
  final resumableFuture = ref.watch(resumableItemsProvider.future);
  final unwatchedFuture = ref.watch(unwatchedLibraryProvider.future);
  final arrFuture = ref.watch(_arrLibraryEntriesProvider.future);

  final played = await playedFuture;
  final resumable = await resumableFuture;
  final unwatched = await unwatchedFuture;
  final arrEntries = await arrFuture;

  final events = [
    ...buildJellyfinWatchEvents(played, now: now),
    ...buildJellyfinWatchEvents(resumable, now: now),
  ];
  final jellyfinCandidates = buildJellyfinCandidates(unwatched);
  final arrCandidatesRaw = buildArrCandidates(arrEntries);
  // `played` ∪ `unwatched` couvre toute la bibliothèque (cf.
  // `buildLibraryTraitStats`) — jamais de requête séparée pour ça.
  final libraryStats = buildLibraryTraitStats([...played, ...unwatched]);

  // Réglages par défaut de TasteProfileBuilder (saturation sqrt, genres
  // sous-pondérés) — cf. `defaultTraitKindWeights`/
  // `AccumulationSaturation` pour comparer d'autres réglages.
  const builder = TasteProfileBuilder();
  final profile = builder.build(events, libraryStats: libraryStats);

  // "Vu, en cours, ou déjà présent dans la file d'attente de lecture" —
  // vu et bibliothèque non vue sont déjà séparés côté requête
  // (`isPlayed`) ; "en cours" (resumable) est exclu ici explicitement,
  // ces items pouvant réapparaître dans `unwatched` selon la version du
  // serveur.
  final excludedIds = resumable.map((e) => e.id).toSet();

  // Candidats Arr déjà connus de Jellyfin (peu importe l'état : joué, en
  // cours, ou déjà dans la bibliothèque non vue) — écartés avant tout
  // calcul, sur le titre/année déjà en mémoire (cf.
  // `arr_jellyfin_dedup.dart`) : ni doublon visible entre les deux
  // rangées, ni entrée "jamais lancée" qui ne le serait plus.
  final knownJellyfinWorks = <TitledWork>[
    for (final c in jellyfinCandidates) (title: c.title, year: c.year),
    // `yearAired`, pas `productionYear` — seul champ réellement peuplé
    // pour un item chargé depuis le serveur (cf.
    // `OverviewModel.fromBaseItemDto`).
    for (final item in [...played, ...resumable])
      (title: item.name, year: item.overview.yearAired),
  ];
  final arrCandidates =
      excludeArrCandidatesKnownToJellyfin(arrCandidatesRaw, knownJellyfinWorks);

  // `libraryStats` passé au scorer, pas seulement au profil : filtre
  // aussi les mots-clés/studios trop peu crédibles du choix de la
  // justification.
  final scorer = RecommendationScorer(libraryStats: libraryStats);

  final scoredJellyfin = scorer.score(
    profile,
    jellyfinCandidates,
    excludedIds: excludedIds,
    seed: seed,
  );
  // Tri par date d'ajout puis, au-delà de `stableOrderAge`, ordre
  // aléatoire stabilisé par la même graine de session que les autres
  // rangées "aléatoires" — cf. `arr_added_date_ranking.dart`.
  final scoredArr = rankArrCandidatesByAddedDate(
    profile,
    arrCandidates,
    scorer: scorer,
    now: now,
    seed: seed,
  );

  // Destination du clic : une entrée "Vous l'aviez mis de côté" qui
  // existe déjà dans Jellyfin doit ouvrir sa fiche Jellyfin, pas sa
  // fiche Arr — depuis l'accueil on veut lire, pas gérer. Même règle de
  // correspondance que le dédoublonnage ci-dessus
  // (`findKnownJellyfinMatch`, cf. `arr_jellyfin_dedup.dart`), mais sur
  // un catalogue plus large (`unwatched` brut, pas `jellyfinCandidates`
  // filtré aux candidats *avec traits*) : un filet de sécurité contre
  // les cas que le dédoublonnage de la rangée laisse passer.
  //
  // Identifiant externe en priorité (tmdbId/imdbId/tvdbId, cf.
  // `ArrLibraryEntry`/`OverviewModel.providerIds`) — insensible à toute
  // divergence de titre (notation, langue). Titre original en repli
  // secondaire, en plus du titre d'affichage (`originalTitleOf`) — vide
  // plutôt que `null` quand non chargé, cf. `ItemBaseModel
  // .originalTitle`, d'où le passage à `null` explicite ici.
  final arrEntriesById = {
    for (final entry in arrEntries) arrCandidateId(entry): entry
  };
  final allKnownJellyfinItems = [...unwatched, ...played, ...resumable];
  final arrJellyfinMatchesById = <String, ItemBaseModel>{
    for (final scored in scoredArr)
      if (arrEntriesById[scored.item.id] case final entry?)
        if (findKnownJellyfinMatch(
          entry.title,
          entry.year,
          allKnownJellyfinItems,
          titleOf: (item) => item.name,
          // `yearAired`, pas `productionYear` — même raison que
          // `knownJellyfinWorks` ci-dessus.
          yearOf: (item) => item.overview.yearAired,
          originalTitleOf: (item) => item.originalTitle?.isNotEmpty == true
              ? item.originalTitle
              : null,
          externalIds: (
            tmdbId: entry.tmdbId,
            imdbId: entry.imdbId,
            tvdbId: entry.tvdbId,
          ),
          externalIdsOf: (item) => (
            tmdbId: item.overview.tmdbId,
            imdbId: item.overview.imdbId,
            tvdbId: item.overview.tvdbId,
          ),
        )
            case final match?)
          scored.item.id: match,
  };
  final jellyfinItemsById = {for (final item in unwatched) item.id: item};

  // Persistance du cache — jamais attendue avant de résoudre ce
  // provider : la rangée doit basculer sur le résultat frais dès qu'il
  // est prêt, pas rester bloquée le temps d'une écriture disque qui ne
  // sert qu'au *prochain* lancement. Best-effort : une écriture qui
  // échoue laisse simplement le cache existant en l'état (cf.
  // `_syncRecommendationCache`, qui avale ses propres exceptions).
  final userId = ref.read(userProvider)?.id;
  if (userId != null && userId.isNotEmpty) {
    final db = ref.read(appDatabaseProvider);
    unawaited(_syncRecommendationCache(
      db: db,
      userId: userId,
      rowKind: RecommendationRowKind.forYou,
      freshEntries:
          buildJellyfinCacheEntries(userId, scoredJellyfin, jellyfinItemsById),
    ));
    unawaited(_syncRecommendationCache(
      db: db,
      userId: userId,
      rowKind: RecommendationRowKind.setAside,
      freshEntries: buildArrCacheEntries(userId, scoredArr, arrEntriesById),
    ));
    // Marqueur de fraîcheur (cf. [recommendationRecomputeNeededProvider])
    // — posé après un calcul réussi, que son contenu ait changé ou non :
    // ce n'est pas "le cache a changé" que ce marqueur retient (cf.
    // `capturedAt`, qui lui ne bouge pas si `sameCacheEntries` est vrai),
    // c'est "un calcul complet a bien tourné à cet instant".
    unawaited(db.setSetting(
      recommendationLastComputedSettingKey,
      now.toIso8601String(),
      scope: recommendationSettingsScope,
    ));
  }

  ref.keepAlive();
  return (
    candidates: scoredJellyfin,
    arrOnlyCandidates: scoredArr,
    jellyfinItemsById: jellyfinItemsById,
    // Construite sur `arrEntries` (avant filtre "avec fichier"/dédup),
    // pas `arrCandidates` : un sur-ensemble suffit pour une table de
    // recherche, aucun besoin qu'elle corresponde exactement aux
    // candidats retenus.
    arrEntriesById: arrEntriesById,
    arrJellyfinMatchesById: arrJellyfinMatchesById,
  );
});

/// Remplace le cache d'une rangée par [freshEntries] — sauf s'il n'y a
/// littéralement rien de nouveau (cf. [sameCacheEntries]), auquel cas
/// rien n'est écrit ("ne reconstruis rien" au sens strict : ni la base,
/// ni donc la moindre notification aux widgets qui la lisent).
/// Best-effort, jamais une exception qui remonte : une écriture de cache
/// qui échoue doit laisser le cache existant intact pour le prochain
/// lancement, jamais interrompre ou signaler quoi que ce soit dans la
/// session en cours.
Future<void> _syncRecommendationCache({
  required AppDatabase db,
  required String userId,
  required RecommendationRowKind rowKind,
  required List<RecommendationCacheEntriesCompanion> freshEntries,
}) async {
  try {
    final cached =
        await db.getRecommendationCache(userId: userId, rowKind: rowKind).get();
    if (sameCacheEntries(freshEntries, cached)) return;
    await db.replaceRecommendationCache(
      userId: userId,
      rowKind: rowKind,
      entries: freshEntries,
    );
  } catch (_) {
    // Best-effort — cf. la note sur cette fonction.
  }
}

/// Seuil de fraîcheur avant un nouveau recalcul complet — distinct de
/// [defaultRecommendationCacheMaxAge] (7 jours, décide si le cache est
/// *affichable*) : celui-ci décide si un recalcul est même *déclenché*.
/// Paramétrable, 24 h par défaut — un historique qui bouge à peine
/// d'un lancement à l'autre ne justifie pas de refaire 28 s de travail
/// (fetch + scoring) à chaque fois.
const defaultRecommendationRecomputeThreshold = Duration(hours: 24);

/// Clé/portée du marqueur "dernier calcul réussi", table `settings` —
/// même mécanisme que les autres drapeaux ponctuels du projet (cf.
/// `home_rows_provider.dart`). Publiques : [forceRecommendationRecompute]
/// (bouton de réglages) doit pouvoir l'effacer sans dupliquer la clé.
const recommendationLastComputedSettingKey = 'recommendation_last_computed_at';
const recommendationSettingsScope = 'recommendations';

/// `false` : un calcul a réussi il y a moins de
/// [defaultRecommendationRecomputeThreshold], et au moins une des deux
/// rangées a un cache non vide et affichable (cf.
/// `AppDatabase.getRecommendationCache`, qui applique déjà le maxAge de
/// 7 jours) — [recommendationResultProvider] ne doit pas être déclenché,
/// les deux rangées se contentent du cache. `true` dans tous les autres
/// cas — pas de marqueur connu, marqueur périmé, ou cache absent/périmé
/// au-delà du maxAge malgré le marqueur (une écriture de cache
/// best-effort a pu échouer malgré un calcul réussi) — y compris par
/// défaut si la vérification elle-même échoue : ne jamais supprimer un
/// recalcul par excès de prudence.
final recommendationRecomputeNeededProvider =
    FutureProvider.autoDispose<bool>((ref) async {
  final userId = ref.read(userProvider)?.id;
  if (userId == null || userId.isEmpty) return true;

  final db = ref.read(appDatabaseProvider);
  try {
    final lastComputed = await db.getSetting(
        recommendationLastComputedSettingKey,
        scope: recommendationSettingsScope);
    if (lastComputed == null) return true;
    final lastComputedAt = DateTime.tryParse(lastComputed.value);
    if (lastComputedAt == null) return true;
    if (DateTime.now().difference(lastComputedAt) >=
        defaultRecommendationRecomputeThreshold) {
      return true;
    }

    final forYouCache = await db
        .getRecommendationCache(
            userId: userId, rowKind: RecommendationRowKind.forYou)
        .get();
    final setAsideCache = await db
        .getRecommendationCache(
            userId: userId, rowKind: RecommendationRowKind.setAside)
        .get();
    if (forYouCache.isEmpty && setAsideCache.isEmpty) return true;

    return false;
  } catch (_) {
    return true;
  }
});

/// Force un nouveau calcul complet au prochain affichage de l'accueil —
/// efface le marqueur de fraîcheur (cf.
/// [recommendationRecomputeNeededProvider]) et invalide les deux
/// providers concernés. Appelé depuis une action de réglages ; jamais un
/// recalcul immédiat ici (pas de contexte d'affichage à bloquer dessus),
/// seulement la levée du frein pour la prochaine fois que l'accueil
/// observe ces providers. `WidgetRef` : seul appelant, un bouton de
/// réglages (cf. `client_settings_page.dart`).
Future<void> forceRecommendationRecompute(WidgetRef ref) async {
  final userId = ref.read(userProvider)?.id;
  if (userId != null && userId.isNotEmpty) {
    final db = ref.read(appDatabaseProvider);
    await db.deleteSetting(recommendationLastComputedSettingKey,
        scope: recommendationSettingsScope);
  }
  ref.invalidate(recommendationRecomputeNeededProvider);
  ref.invalidate(recommendationResultProvider);
}

/// Identifiants déjà affichés par "Pour vous"/"Vous l'aviez mis de côté"
/// — pour amorcer le registre de déduplication des rangées plus bas sur
/// la page (`home_catalog_providers.dart`) sans jamais forcer un calcul
/// complet juste pour ça. Deux sources selon
/// [recommendationRecomputeNeededProvider] :
/// - recalcul nécessaire (ou statut encore inconnu) : les candidats du
///   calcul frais, via `.valueOrNull` — jamais `.future` attendu, cf.
///   `home_catalog_providers.dart` sur pourquoi ces rangées ne bloquent
///   jamais sur le calcul complet des recommandations ;
/// - recalcul non nécessaire (cache frais, cf. le seuil de 24 h) : les
///   identifiants directement lus depuis le cache — c'est exactement ce
///   que ces deux rangées affichent dans ce cas, jamais désynchronisé.
final recommendationRegistrySeedProvider = FutureProvider.autoDispose<
    ({List<String> forYouIds, List<String> arrOnlyIds})>((ref) async {
  final recomputeNeeded =
      ref.watch(recommendationRecomputeNeededProvider).valueOrNull;

  if (recomputeNeeded == false) {
    final userId = ref.read(userProvider)?.id;
    if (userId == null || userId.isEmpty) {
      return (forYouIds: const <String>[], arrOnlyIds: const <String>[]);
    }
    final db = ref.read(appDatabaseProvider);
    final forYou = await db
        .getRecommendationCache(
            userId: userId, rowKind: RecommendationRowKind.forYou)
        .get();
    final arrOnly = await db
        .getRecommendationCache(
            userId: userId, rowKind: RecommendationRowKind.setAside)
        .get();
    return (
      forYouIds: [
        for (final row in forYou)
          if (row.jellyfinItemId != null) row.jellyfinItemId!
      ],
      arrOnlyIds: [
        for (final row in arrOnly)
          if (row.arrId != null) 'arr:${row.arrService}:${row.arrId}'
      ],
    );
  }

  final recommendation = ref.watch(recommendationResultProvider).valueOrNull;
  if (recommendation == null) {
    return (forYouIds: const <String>[], arrOnlyIds: const <String>[]);
  }
  return (
    forYouIds: [for (final c in recommendation.candidates) c.item.id],
    arrOnlyIds: [for (final c in recommendation.arrOnlyCandidates) c.item.id],
  );
});
