import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kinos/jellyfin/jellyfin_open_api.enums.swagger.dart';
import 'package:kinos/models/home_model.dart';
import 'package:kinos/models/item_base_model.dart';
import 'package:kinos/models/views_model.dart';
import 'package:kinos/providers/dashboard/home_row_random_seed_provider.dart';
import 'package:kinos/providers/dashboard_provider.dart';
import 'package:kinos/providers/views_provider.dart';
import 'package:kinos/recommendations/adapters/catalog_inventory.dart';
import 'package:kinos/recommendations/adapters/jellyfin_candidate_adapter.dart';
import 'package:kinos/recommendations/adapters/jellyfin_trait_extraction.dart';
import 'package:kinos/recommendations/adapters/jellyfin_watch_event_adapter.dart';
import 'package:kinos/recommendations/adapters/justification_label.dart';
import 'package:kinos/recommendations/engine/home_registry.dart';
import 'package:kinos/recommendations/engine/recommendation_scorer.dart';
import 'package:kinos/recommendations/engine/seed_clustering.dart';
import 'package:kinos/recommendations/engine/taste_profile_builder.dart';
import 'package:kinos/recommendations/models/scored_candidate.dart';
import 'package:kinos/recommendations/models/trait.dart';
import 'package:kinos/recommendations/providers/recommendation_providers.dart';

/// Types de collection dans le périmètre du projet — même filtre que
/// `dashboard_screen.dart` (`_dashboardCollectionTypes`, privé là-bas,
/// dupliqué ici plutôt que rendu public pour un unique consommateur) :
/// c'est le même ensemble d'œuvres qu'"Ajouts récents" affiche
/// réellement qu'on doit amorcer dans le registre.
const _dashboardCollectionTypes = {
  CollectionType.movies,
  CollectionType.tvshows,
  CollectionType.boxsets,
  CollectionType.homevideos,
};

/// Nombre maximal de colonnes qu'une grille affiche jamais en pratique —
/// `AppDensity.columnsFor` (`app_theme.dart`) borne à 10, pas 8 (cf.
/// CLAUDE.md, "grilles à 6–8 colonnes" : une cible de conception, pas la
/// borne réelle du code). Le registre doit réserver au moins ce
/// maximum réel, sinon un titre visible en colonne 9 ou 10 sur un grand
/// écran passe au travers de la déduplication — cf. calibrage : Avatar
/// visible à la fois dans "Bien notés jamais vus", "Fantasy" et
/// "Science Fiction" alors que le registre semblait "ne pas fonctionner"
/// — il réservait bien le sommet de chaque rangée, mais un sommet trop
/// court (8) face à ce qu'un écran large affiche réellement (jusqu'à
/// 10).
const _registryReserve = 10;

/// Genres tirés au hasard par session parmi le pot éligible (cf.
/// `catalog_inventory.dart`, [genreRowPool]) — cf. spec du calibrage :
/// "cinq sont tirés au hasard à chaque session".
const _genreRowDrawCount = 5;

/// Décennies tirées au hasard par session parmi le pot éligible (cf.
/// [decadeRowPool]) — cf. spec : "trois ou quatre sont tirées par
/// session".
const _decadeRowDrawCount = 4;

/// Plancher d'une rangée par graine *après* exclusion du registre —
/// même valeur que [selectSeedTraits]'s `minSharedCandidates` par
/// défaut (8) : une rangée qui reste crédible avant dédoublonnage doit
/// le rester après, pas seulement "non vide".
const _seedRowMinItemsAfterExclusion = 8;

/// Une rangée par graine — restreinte à un seul trait ([seed]), titrée
/// depuis l'œuvre vue qui y a le plus contribué (cf. [seedRowTitle]).
typedef SeedRow = ({
  TraitKey seed,
  String title,
  List<ScoredCandidate> candidates,
});

/// Résultat des rangées par graine — dérivé de la seule bibliothèque
/// Jellyfin (`played`/`resumable`/`unwatched`), profil de goût reconstruit
/// localement (cf. la note sur [homeSeedRowsResultProvider]).
typedef HomeSeedRowsResult = ({
  List<SeedRow> seedRows,

  /// Objets Jellyfin derrière chaque candidat de [seedRows] — le moteur
  /// (`CandidateItem`) ne porte ni image ni référence Jellyfin, c'est
  /// l'écran qui en a besoin pour peindre une vraie jaquette et naviguer
  /// vers la bonne fiche.
  Map<String, ItemBaseModel> jellyfinItemsById,
});

/// Résultat de l'inventaire du catalogue — dérivé de la seule
/// bibliothèque Jellyfin, cf. la note sur [homeCatalogInventoryResultProvider].
typedef HomeCatalogInventoryResult = ({
  /// Séparé des séries (cf. spec du calibrage) : une note ne veut pas
  /// dire la même chose pour un film de deux heures que pour une série
  /// de soixante épisodes, l'engagement demandé n'est pas comparable —
  /// une seule rangée "bien notés" mélangeant les deux aurait masqué
  /// cette différence plutôt que de la respecter. Toujours dans cet
  /// ordre (films avant séries) à l'affichage.
  List<ItemBaseModel> wellRatedMovies,
  List<ItemBaseModel> wellRatedSeries,
  Map<String, List<ItemBaseModel>> narrowGenres,
  Map<int, List<ItemBaseModel>> decades,
  List<ItemBaseModel> longFilms,

  /// `false` : ce résultat vient d'un aperçu partiel (la première page
  /// seulement, cf. `unwatchedLibraryFirstPageProvider`) — "genres
  /// étroits"/"décennies" sont alors vides par construction (cf. la note
  /// sur `homeCatalogInventoryResultProvider`), seuls "bien notés"/"longs
  /// métrages" reflètent déjà du contenu réel. `true` une fois la
  /// bibliothèque complète en main : ce même provider se recalcule alors
  /// automatiquement (`ref.watch`), sans qu'aucun widget n'ait à s'en
  /// soucier.
  bool isComplete,
});

/// Ce que "Continuer à regarder" affiche réellement — resumeVideo puis
/// nextUp, dédoublonnés (même logique que `dashboard_screen.dart`,
/// dupliquée ici à dessein : les deux providers de ce fichier en ont
/// besoin indépendamment l'un de l'autre, cf. calibrage "chaque section
/// observe ce dont elle a besoin, rien de plus" — aucun des deux
/// n'attend l'autre pour le calculer).
List<ItemBaseModel> _continueWatching(HomeModel dashboard) {
  final seen = <String>{};
  return [...dashboard.resumeVideo, ...dashboard.nextUp]
      .where((item) => seen.add(item.id))
      .toList();
}

/// Ce qu'"Ajouts récents" affiche réellement — même filtre que
/// `dashboard_screen.dart` (`_dashboardCollectionTypes`). Même
/// duplication assumée que [_continueWatching].
List<ItemBaseModel> _recentlyAdded(ViewsModel views) {
  return views.dashboardViews
      .where((view) => _dashboardCollectionTypes.contains(view.collectionType))
      .expand((view) => view.recentlyAdded)
      .toList();
}

/// Registre amorcé avec ce qui est déjà connu plus haut sur la page —
/// jamais bloquant sur `recommendationResultProvider` (cf. calibrage :
/// "toute la page attend les 45 s du calcul des recommandations, y
/// compris l'inventaire, qui n'a besoin que de la bibliothèque
/// Jellyfin"). [registrySeed] vient de `recommendationRegistrySeedProvider`
/// (`recommendation_providers.dart`), lu via `.valueOrNull` par
/// l'appelant, jamais attendu : `null` tant qu'il n'a pas résolu, auquel
/// cas "Pour vous"/"Vous l'aviez mis de côté" ne contribuent simplement
/// rien au registre pour l'instant. Comme l'appelant observe ce résultat
/// avec `ref.watch` (pas `ref.read`), ce provider se recalcule
/// automatiquement dès qu'il change — un doublon passager le temps que
/// ce calcul termine, jamais une page qui attend.
Set<String> _knownFromHigherRows({
  required List<ItemBaseModel> continueWatching,
  required List<ItemBaseModel> recentlyAdded,
  required ({List<String> forYouIds, List<String> arrOnlyIds})? registrySeed,
}) {
  return {
    ...reserveIds(continueWatching, (item) => item.id,
        reserve: _registryReserve),
    if (registrySeed != null) ...[
      ...reserveIds(registrySeed.forYouIds, (id) => id,
          reserve: _registryReserve),
      ...reserveIds(registrySeed.arrOnlyIds, (id) => id,
          reserve: _registryReserve),
    ],
    ...reserveIds(recentlyAdded, (item) => item.id, reserve: _registryReserve),
  };
}

/// Rangées par graine, pour la suite de l'accueil après "Ajouts récents"
/// (cf. spec du lot graines/inventaire).
///
/// Ne dépend que de [playedItemsProvider]/[resumableItemsProvider]/
/// [unwatchedLibraryProvider] (bibliothèque Jellyfin, déjà chargée par
/// `recommendationResultProvider` — Riverpod sert la valeur mise en
/// cache, aucun nouvel aller-retour réseau) : le profil de goût et les
/// candidats sont reconstruits localement à partir de ces trois
/// providers, jamais depuis `recommendationResultProvider` lui-même —
/// le calcul se mesure à quelques dizaines de ms (cf. le calibrage de
/// performance), le refaire est négligeable face à attendre les 45 s du
/// calcul complet (scoring, dédoublonnage Arr...) pour une rangée qui
/// n'en a besoin que pour amorcer son registre d'exclusion (cf.
/// [_knownFromHigherRows], non bloquant).
final homeSeedRowsResultProvider =
    FutureProvider.autoDispose<HomeSeedRowsResult>((ref) async {
  final seed = ref.watch(homeRowRandomSeedProvider);
  final now = DateTime.now();

  final played = await ref.watch(playedItemsProvider.future);
  final resumable = await ref.watch(resumableItemsProvider.future);
  final unwatched = await ref.watch(unwatchedLibraryProvider.future);

  final events = [
    ...buildJellyfinWatchEvents(played, now: now),
    ...buildJellyfinWatchEvents(resumable, now: now),
  ];
  final jellyfinCandidates = buildJellyfinCandidates(unwatched);
  final libraryStats = buildLibraryTraitStats([...played, ...unwatched]);

  const builder = TasteProfileBuilder();
  final profile = builder.build(events, libraryStats: libraryStats);
  final scorer = RecommendationScorer(libraryStats: libraryStats);

  final registrySeed =
      ref.watch(recommendationRegistrySeedProvider).valueOrNull;
  final continueWatching = _continueWatching(ref.watch(dashboardProvider));
  final recentlyAdded = _recentlyAdded(ref.watch(viewsProvider));

  final registry = _knownFromHigherRows(
    continueWatching: continueWatching,
    recentlyAdded: recentlyAdded,
    registrySeed: registrySeed,
  );

  final watchedItemsById = {
    for (final item in [...played, ...resumable]) item.id: item,
  };

  // Graines : sélection déterministe par poids (cf. [selectSeedTraits]),
  // rotation de l'*ordre d'affichage* seulement (mélange par la graine
  // de session, même mécanisme que les autres rangées "aléatoires" de
  // l'accueil).
  final seedTraits =
      _seededShuffle(selectSeedTraits(profile, jellyfinCandidates), seed);

  final seedRows = <SeedRow>[];
  for (final seedTrait in seedTraits) {
    final sharing =
        jellyfinCandidates.where((c) => c.traits.contains(seedTrait)).toList();
    final afterRegistry = excludeKnown(sharing, (c) => c.id, registry);
    if (afterRegistry.length < _seedRowMinItemsAfterExclusion) continue;

    final scored = [
      for (final candidate in afterRegistry)
        scorer.scoreCandidate(profile, candidate),
    ]..sort((a, b) => b.score.compareTo(a.score));

    final sourceEvent = sourceEventForTrait(seedTrait, events, now: now);
    final sourceTitle =
        sourceEvent == null ? null : watchedItemsById[sourceEvent.itemId]?.name;
    final title = sourceTitle != null
        ? seedRowTitle(sourceTitle)
        : justificationLabel(seedTrait);
    if (title == null) continue;

    seedRows.add((seed: seedTrait, title: title, candidates: scored));
    registry.addAll(
        reserveIds(scored, (c) => c.item.id, reserve: _registryReserve));
  }

  return (
    seedRows: seedRows,
    jellyfinItemsById: {for (final item in unwatched) item.id: item},
  );
});

/// Inventaire du catalogue — filtres/tris purs, sans scoring, pour la
/// suite de l'accueil après les rangées par graine (cf. spec du lot).
///
/// Ne dépend que de [playedItemsProvider]/[unwatchedLibraryProvider]
/// (bibliothèque Jellyfin — ni `resumableItemsProvider` ni aucune donnée
/// Arr, aucune de ces cinq catégories n'en a besoin) : ni profil de
/// goût, ni scoring, ni `recommendationResultProvider`. Se construit dès
/// que la bibliothèque est disponible, indépendamment du calcul complet
/// des recommandations (cf. calibrage : "toute la page attend les 45 s
/// du calcul, y compris l'inventaire — découple-les").
///
/// `recommendationResultProvider` et [homeSeedRowsResultProvider] sont
/// observés via `.valueOrNull` (jamais `.future` attendu) uniquement
/// pour amorcer le registre d'exclusion avec ce qu'ils affichent déjà
/// plus haut sur la page — `null` tant qu'ils n'ont pas résolu, auquel
/// cas ils ne contribuent simplement rien pour l'instant : l'inventaire
/// s'affiche avec ce qui est connu, quitte à ce que le dédoublonnage
/// s'affine automatiquement dès qu'ils aboutissent (`ref.watch`
/// déclenche un recalcul à ce moment-là). Un doublon passager vaut mieux
/// qu'une page vide.
final homeCatalogInventoryResultProvider =
    FutureProvider.autoDispose<HomeCatalogInventoryResult>((ref) async {
  final seed = ref.watch(homeRowRandomSeedProvider);

  final played = await ref.watch(playedItemsProvider.future);

  // Diffusion progressive (cf. calibrage : "rends chaque page
  // exploitable dès son arrivée") — la première page ([firstPage],
  // [unwatchedLibraryFirstPageProvider]) sert de sous-ensemble "suffisant"
  // pour un premier rendu dès qu'elle répond, bien avant que la
  // pagination complète n'aboutisse. Les deux providers sont observés
  // sans condition, avant toute branche : c'est ce qui permet à Riverpod
  // d'abandonner un calcul encore en vol (cf. la branche `else`
  // ci-dessous, qui attend la bibliothèque complète) dès que la première
  // page répond, et de relancer aussitôt avec elle plutôt que d'attendre
  // la fin de cette attente.
  final firstPage = ref.watch(unwatchedLibraryFirstPageProvider);
  final unwatchedComplete = ref.watch(unwatchedLibraryProvider).valueOrNull;

  final List<ItemBaseModel> unwatched;
  final bool isComplete;
  if (unwatchedComplete != null) {
    unwatched = unwatchedComplete;
    isComplete = true;
  } else if (firstPage != null) {
    unwatched = firstPage;
    isComplete = false;
  } else {
    // Rien encore disponible, même pas un aperçu — attend la même
    // requête que les autres rangées partagées (played/unwatched) :
    // exactement l'attente d'avant la diffusion progressive, pas une
    // régression, simplement rien à montrer avant que la première page
    // ne réponde.
    unwatched = await ref.watch(unwatchedLibraryProvider.future);
    isComplete = true;
  }

  final libraryStats = buildLibraryTraitStats([...played, ...unwatched]);

  final registrySeed =
      ref.watch(recommendationRegistrySeedProvider).valueOrNull;
  final seedRowsResult = ref.watch(homeSeedRowsResultProvider).valueOrNull;
  final continueWatching = _continueWatching(ref.watch(dashboardProvider));
  final recentlyAdded = _recentlyAdded(ref.watch(viewsProvider));

  final registry = _knownFromHigherRows(
    continueWatching: continueWatching,
    recentlyAdded: recentlyAdded,
    registrySeed: registrySeed,
  );
  if (seedRowsResult != null) {
    for (final row in seedRowsResult.seedRows) {
      registry.addAll(reserveIds(row.candidates, (c) => c.item.id,
          reserve: _registryReserve));
    }
  }

  // Films et séries séparés (cf. spec du calibrage) : `wellRatedNeverWatched`
  // reste générique (testée telle quelle), le partage par type se fait
  // ici, au même titre qu'un simple filtre supplémentaire sur `unwatched`
  // avant de l'appeler — aucun nouveau parcours de la bibliothèque.
  //
  // Dédoublonné par tmdbId (cf. calibrage : "les deux Kingsman côte à
  // côte sont deux versions du même film, indexées séparément par
  // Jellyfin") — appliqué seulement ici, pour l'inventaire, jamais sur
  // `unwatched`/`jellyfinCandidates` d'origine (rangées par graine,
  // calculées dans un provider séparé, cf. [homeSeedRowsResultProvider]).
  final unwatchedDeduped = dedupeByTmdbId(unwatched);
  final unwatchedMovies = unwatchedDeduped
      .where((item) => item.type == KinosItemType.movie)
      .toList();
  final unwatchedSeries = unwatchedDeduped
      .where((item) => item.type == KinosItemType.series)
      .toList();

  // Inventaire — chaque catégorie exclut le registre courant, vérifie
  // son plancher *après* exclusion, puis s'ajoute elle-même au registre
  // avant la catégorie suivante — dans l'ordre d'affichage fixe (cf.
  // spec) : films bien notés -> séries bien notées -> genres étroits ->
  // décennies -> longs métrages.
  final wellRatedMovies = excludeKnown(
      wellRatedNeverWatched(unwatchedMovies), (item) => item.id, registry);
  registry.addAll(reserveIds(wellRatedMovies, (item) => item.id,
      reserve: _registryReserve));

  final wellRatedSeries = excludeKnown(
      wellRatedNeverWatched(unwatchedSeries), (item) => item.id, registry);
  registry.addAll(reserveIds(wellRatedSeries, (item) => item.id,
      reserve: _registryReserve));

  // "Genres étroits"/"décennies" attendent la bibliothèque complète (cf.
  // calibrage : "si le résultat te paraît instable à l'œil, dis-le-moi
  // plutôt que de le forcer") — jamais calculées sur l'aperçu de la
  // première page. L'éligibilité (`genreRowPool`/`decadeRowPool`) et le
  // tirage dépendent de la distribution de *toute* la bibliothèque ;
  // sur un sous-ensemble non représentatif (la première page suit
  // l'ordre par défaut du serveur, jamais garanti aléatoire), l'ensemble
  // des rangées affichées pourrait changer entre l'aperçu et la version
  // complète, pas seulement leur contenu — une rangée qui apparaît puis
  // disparaît, contrairement à "bien notés"/"longs métrages" (un simple
  // filtre, dont l'identité ne bouge jamais, seul le contenu s'affine).
  // Résultat : ces deux catégories restent vides sur l'aperçu, puis
  // apparaissent d'un coup une fois la bibliothèque complète en main —
  // jamais un remplissage progressif, jamais une rangée qui change
  // d'identité sous les yeux.
  final narrowGenres = <String, List<ItemBaseModel>>{};
  final decades = <int, List<ItemBaseModel>>{};

  if (isComplete) {
    // Rotation (cf. spec du calibrage) : le pot entier reste éligible
    // d'une session à l'autre (cf. `genreRowPool`, qui n'écarte que les
    // genres structurellement trop larges), seul le sous-ensemble
    // *affiché* tourne — tiré au hasard, stabilisé par la graine de
    // session. L'ordre des rangées (bien notés -> genres -> décennies ->
    // longs métrages) reste fixe, c'est le contenu du pot qui tourne,
    // pas la structure.
    final genrePool = genreRowPool(unwatchedDeduped, libraryStats);
    final drawnGenres = _seededShuffle(genrePool.keys.toList()..sort(), seed)
        .take(_genreRowDrawCount);

    for (final label in drawnGenres) {
      final afterRegistry =
          excludeKnown(genrePool[label]!, (item) => item.id, registry);
      if (afterRegistry.length < defaultGenreRowMinItems) continue;
      narrowGenres[label] = afterRegistry;
      registry.addAll(reserveIds(afterRegistry, (item) => item.id,
          reserve: _registryReserve));
    }

    final decadePool = decadeRowPool(unwatchedDeduped);
    // Sélection tirée au hasard, affichage remis dans l'ordre de la plus
    // récente à la plus ancienne (cf. spec d'origine du lot) — seul le
    // *choix* des décennies tourne, pas leur ordre une fois choisies.
    final drawnDecades = (_seededShuffle(decadePool.keys.toList()..sort(), seed)
        .take(_decadeRowDrawCount)
        .toList()
      ..sort((a, b) => b.compareTo(a)));

    for (final decade in drawnDecades) {
      final afterRegistry =
          excludeKnown(decadePool[decade]!, (item) => item.id, registry);
      if (afterRegistry.length < defaultDecadeMinItemsPerRow) continue;
      decades[decade] = afterRegistry;
      registry.addAll(reserveIds(afterRegistry, (item) => item.id,
          reserve: _registryReserve));
    }
  }

  final longFilmsResult =
      excludeKnown(longFilms(unwatchedDeduped), (item) => item.id, registry);

  return (
    wellRatedMovies: wellRatedMovies,
    wellRatedSeries: wellRatedSeries,
    narrowGenres: narrowGenres,
    decades: decades,
    longFilms: longFilmsResult,
    isComplete: isComplete,
  );
});

/// Mélange de Fisher-Yates déterministe — même principe et même raison
/// que `_seededShuffle` dans `home_row_items_provider.dart`/
/// `recommendation_scorer.dart`/`arr_added_date_ranking.dart` : copie
/// délibérée, pas un partage entre fichiers.
List<T> _seededShuffle<T>(List<T> items, int seed) {
  final random = Random(seed);
  final shuffled = [...items];
  for (var i = shuffled.length - 1; i > 0; i--) {
    final j = random.nextInt(i + 1);
    final swap = shuffled[i];
    shuffled[i] = shuffled[j];
    shuffled[j] = swap;
  }
  return shuffled;
}
