import 'package:kinos/models/item_base_model.dart';
import 'package:kinos/recommendations/models/library_trait_stats.dart';
import 'package:kinos/recommendations/models/trait.dart';

/// Inventaire pur du catalogue — filtres/tris sans scoring, à l'opposé
/// des rangées "Pour vous"/"par graine" (cf. spec : "un inventaire
/// honnête n'a pas besoin de recommander"). Toutes les fonctions ici
/// opèrent sur [ItemBaseModel]/[OverviewModel] déjà en mémoire (les
/// mêmes `unwatched` que le reste du moteur), aucun nouvel appel réseau.

/// Plancher par défaut d'une rangée de genre/décennie — exposé pour que
/// `home_catalog_providers.dart` applique exactement le même seuil une
/// seconde fois, après exclusion du registre de déduplication (cf. spec
/// : "vérifie le minimum après exclusion"), sans dupliquer le nombre en
/// dur à deux endroits.
const defaultGenreRowMinItems = 8;

/// Même rôle que [defaultGenreRowMinItems], pour "Décennies".
const defaultDecadeMinItemsPerRow = 8;

/// Traductions/fusions de genres connus pour apparaître en anglais, ou
/// sous un nom différent selon la taxonomie de la source (cf. rapport de
/// calibrage : les séries et les films n'utilisent pas le même
/// vocabulaire de genre chez Jellyfin — TVDB pour l'un, TMDB pour
/// l'autre par exemple — d'où "Drama"/"Drame" ou "War & Politics"/
/// "Guerre" comme deux rangées distinctes pour le même sujet). Un genre
/// absent d'ici passe tel quel (déjà en français dans la bibliothèque,
/// ou un cas non couvert par cette liste de démarrage) — jamais bloquant.
const defaultGenreLabelTranslations = {
  'action': 'Action',
  'action & adventure': 'Action et aventure',
  'adventure': 'Aventure',
  'animation': 'Animation',
  'comedy': 'Comédie',
  'crime': 'Crime',
  'documentary': 'Documentaire',
  'drama': 'Drame',
  'family': 'Familial',
  'fantasy': 'Fantastique',
  'history': 'Histoire',
  'horror': 'Horreur',
  'kids': 'Enfants',
  'music': 'Musique',
  'musical': 'Musique',
  'mystery': 'Mystère',
  'news': 'Actualités',
  'reality': 'Télé-réalité',
  'romance': 'Romance',
  'sci-fi & fantasy': 'Science-fiction et fantastique',
  'science fiction': 'Science-fiction',
  'soap': 'Feuilleton',
  'talk': 'Talk-show',
  'thriller': 'Thriller',
  'tv movie': 'Téléfilm',
  'war': 'Guerre',
  'war & politics': 'Guerre',
  'western': 'Western',
};

/// Libellé canonique d'un genre brut — clé de fusion entre les variantes
/// de taxonomie (cf. [defaultGenreLabelTranslations]) : deux genres qui
/// se traduisent vers le même libellé fusionnent en une seule rangée,
/// une seule fois comptés dans une même œuvre (cf. [genreRowPool]).
String canonicalGenreLabel(
  String rawGenre, {
  Map<String, String> translations = defaultGenreLabelTranslations,
}) {
  final trimmed = rawGenre.trim();
  return translations[trimmed.toLowerCase()] ?? trimmed;
}

/// Fusionne les entrées qui pointent vers la même œuvre — Jellyfin peut
/// indexer séparément deux fichiers d'un même film (ex. deux qualités
/// distinctes importées séparément), chacun comme une entrée de
/// bibliothèque à part entière (cf. calibrage : "les deux Kingsman côte
/// à côte sont deux versions du même film"). Garde la première
/// occurrence rencontrée dans [items] (ordre stable), écarte les
/// suivantes qui partagent le même `tmdbId`. Une œuvre sans `tmdbId`
/// connu n'est jamais fusionnée avec quoi que ce soit — mieux vaut un
/// doublon occasionnel qu'une fusion hasardeuse entre deux œuvres
/// distinctes qui partageraient un identifiant vide.
List<ItemBaseModel> dedupeByTmdbId(List<ItemBaseModel> items) {
  final seenTmdbIds = <String>{};
  final result = <ItemBaseModel>[];
  for (final item in items) {
    final tmdbId = item.overview.tmdbId;
    if (tmdbId == null || tmdbId.isEmpty) {
      result.add(item);
      continue;
    }
    if (seenTmdbIds.add(tmdbId)) {
      result.add(item);
    }
  }
  return result;
}

/// Œuvres jamais vues, notées au moins [minRating] (`communityRating` —
/// le champ que ce client peuple depuis le fournisseur de métadonnées
/// configuré côté serveur, généralement TMDB) — triées par note
/// décroissante.
List<ItemBaseModel> wellRatedNeverWatched(
  List<ItemBaseModel> unwatched, {
  double minRating = 7.5,
}) {
  final rated = unwatched
      .where((item) => (item.overview.communityRating ?? 0) >= minRating)
      .toList()
    ..sort((a, b) => (b.overview.communityRating ?? 0)
        .compareTo(a.overview.communityRating ?? 0));
  return rated;
}

/// Pot des genres éligibles à une rangée d'inventaire ("Genres étroits")
/// — libellé canonique (cf. [canonicalGenreLabel]) -> œuvres jamais vues
/// qui le portent. Remplace un seuil de fréquence fixe (cf. calibrage :
/// "le seuil ne filtre rien" — sur cette bibliothèque, aucun genre isolé
/// ne dépassait la fraction fixée, alors que la fusion Drama/Drame
/// aurait dû faire dépasser "Drame" largement) par une exclusion
/// *relative* : un genre est "trop large" si sa fréquence dépasse
/// [broadGenreMedianMultiplier] fois la fréquence médiane des genres
/// éligibles — un calcul qui s'adapte à la distribution réelle de
/// n'importe quelle bibliothèque plutôt qu'une fraction absolue à
/// recalibrer à la main, et qui n'écarte que les vrais outliers (drame,
/// action et assimilés), jamais un genre "moyen".
///
/// L'appelant tire ensuite un sous-ensemble au hasard dans ce pot,
/// stabilisé par la graine de session (cf. `home_catalog_providers
/// .dart`) — cette fonction ne fait que déterminer l'éligibilité, jamais
/// la sélection finale ni l'ordre d'affichage.
Map<String, List<ItemBaseModel>> genreRowPool(
  List<ItemBaseModel> unwatched,
  LibraryTraitStats libraryStats, {
  int minItemsPerRow = defaultGenreRowMinItems,
  double broadGenreMedianMultiplier = 3.0,
}) {
  if (libraryStats.librarySize == 0) return const {};

  final byGenre = <String, List<ItemBaseModel>>{};
  for (final item in unwatched) {
    final seenLabels = <String>{};
    for (final genre in item.overview.genres) {
      if (genre.isEmpty) continue;
      final label = canonicalGenreLabel(genre);
      // Une œuvre dont les deux variantes ("Drama" et "Drame") seraient
      // présentes en même temps ne doit compter qu'une fois pour ce
      // libellé fusionné — improbable en pratique (une œuvre vient d'une
      // seule source de métadonnées), mais gratuit à garantir.
      if (seenLabels.add(label)) {
        byGenre.putIfAbsent(label, () => []).add(item);
      }
    }
  }

  // Fréquence canonique sur toute la bibliothèque (pas seulement
  // `unwatched`) : `libraryStats` couvre `played` ∪ `unwatched`, déjà
  // calculée ailleurs (cf. `buildLibraryTraitStats`), regroupée ici par
  // libellé fusionné en sommant les variantes qui s'y traduisent — sûr
  // tant qu'une même œuvre ne porte jamais deux variantes du même genre
  // fusionné à la fois (cf. plus haut).
  final canonicalFrequency = <String, int>{};
  for (final entry in libraryStats.traitDocFrequency.entries) {
    if (entry.key.kind != TraitKind.genre) continue;
    final label = canonicalGenreLabel(entry.key.value);
    canonicalFrequency[label] = (canonicalFrequency[label] ?? 0) + entry.value;
  }

  final eligible = byGenre.keys
      .where((label) => byGenre[label]!.length >= minItemsPerRow)
      .toList();
  if (eligible.isEmpty) return const {};

  final median =
      _median([for (final label in eligible) canonicalFrequency[label] ?? 0]);

  final pool = <String, List<ItemBaseModel>>{};
  for (final label in eligible..sort()) {
    final frequency = canonicalFrequency[label] ?? 0;
    if (median > 0 && frequency > median * broadGenreMedianMultiplier) {
      continue; // Genre trop large pour avoir une identité propre.
    }
    pool[label] = byGenre[label]!;
  }
  return pool;
}

num _median(List<int> values) {
  if (values.isEmpty) return 0;
  final sorted = [...values]..sort();
  final mid = sorted.length ~/ 2;
  if (sorted.length.isOdd) return sorted[mid];
  return (sorted[mid - 1] + sorted[mid]) / 2;
}

/// Pot des décennies éligibles à une rangée d'inventaire ("Décennies")
/// — décennie -> œuvres jamais vues qui y sont sorties, pour celles
/// atteignant [minItemsPerRow]. Comme [genreRowPool], ne fait que
/// déterminer l'éligibilité : l'appelant tire un sous-ensemble au
/// hasard, stabilisé par la graine de session.
///
/// Lit `overview.yearAired`, pas `overview.productionYear` — cf.
/// calibrage : les deux champs coexistent sur [OverviewModel], mais seul
/// `yearAired` est réellement peuplé par `OverviewModel.fromBaseItemDto`
/// (le chemin de construction utilisé pour un item chargé depuis le
/// serveur, `MovieModel`/`SeriesModel.fromBaseDto` avec un `Ref` non
/// nul) ; `productionYear` n'y est jamais écrit, `null` pour toute
/// œuvre venant du serveur — d'où un pot vide alors que `ProductionYear`
/// est bien demandé et présent côté API (c'est un champ scalaire
/// renvoyé par défaut par Jellyfin, sans `fields:` à ajouter, contraste
/// avec `genres`/`people`/`studios`/`tags`/`providerids` qui en ont
/// besoin).
Map<int, List<ItemBaseModel>> decadeRowPool(
  List<ItemBaseModel> unwatched, {
  int minItemsPerRow = defaultDecadeMinItemsPerRow,
}) {
  final byDecade = <int, List<ItemBaseModel>>{};
  for (final item in unwatched) {
    final year = item.overview.yearAired;
    if (year == null) continue;
    final decade = (year ~/ 10) * 10;
    byDecade.putIfAbsent(decade, () => []).add(item);
  }

  final pool = <int, List<ItemBaseModel>>{};
  for (final decade in byDecade.keys.toList()..sort((a, b) => b.compareTo(a))) {
    final items = byDecade[decade]!;
    if (items.length >= minItemsPerRow) pool[decade] = items;
  }
  return pool;
}

/// Œuvres jamais vues, d'une durée au moins [minRuntime].
List<ItemBaseModel> longFilms(
  List<ItemBaseModel> unwatched, {
  Duration minRuntime = const Duration(hours: 2, minutes: 30),
}) {
  return unwatched
      .where((item) => (item.overview.runTime ?? Duration.zero) >= minRuntime)
      .toList();
}
