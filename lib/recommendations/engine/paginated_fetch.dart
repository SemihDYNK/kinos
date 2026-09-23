/// Récupère toutes les pages d'un jeu de résultats paginé, en parallèle
/// avec une concurrence bornée plutôt que d'attendre chaque page l'une
/// après l'autre — cf. calibrage : la requête bibliothèque "non vus" est
/// le goulot unique de l'accueil (45 s mesurées sur un aller-retour
/// unique), à comparer contre un découpage en pages plus petites lancées
/// de front.
///
/// [PageFetcher] : une page à la fois (`startIndex`, `limit`) -> ses
/// éléments et le nombre total connu du serveur — ce fichier ne connaît
/// ni Jellyfin ni aucune API réseau précise (l'appelant construit la
/// vraie requête), pour rester testable avec une fausse implémentation.
///
/// Échec d'une page : un seul nouvel essai, puis [PaginatedFetchException]
/// si le second essai échoue aussi — jamais un résultat amputé rendu en
/// silence, une page manquante fausserait l'inventaire et les
/// recommandations sans que rien ne le signale.
library;

typedef PageFetcher<T> = Future<PageResult<T>> Function({
  required int startIndex,
  required int limit,
});

typedef PageResult<T> = ({List<T> items, int totalRecordCount});

/// Durée d'une page, du premier essai jusqu'à son succès final (retry
/// inclus) — le temps réellement écoulé pour obtenir cette page, pas
/// seulement celui de son dernier essai.
typedef PageTiming = ({int startIndex, Duration elapsed, bool retried});

typedef PaginatedFetchResult<T> = ({
  List<T> items,
  int pageCount,
  Duration totalElapsed,
  Duration slowestPageElapsed,
  List<PageTiming> pageTimings,
});

/// Une page a échoué deux fois de suite (premier essai + un nouveau
/// essai, cf. la note sur ce fichier) — jamais avalée : l'appelant doit
/// savoir que le résultat n'aurait pas été complet plutôt que de
/// recevoir silencieusement une liste amputée.
class PaginatedFetchException implements Exception {
  final int startIndex;
  final Object cause;

  const PaginatedFetchException(this.startIndex, this.cause);

  @override
  String toString() =>
      'PaginatedFetchException: la page à startIndex=$startIndex a échoué '
      'deux fois de suite (cause : $cause)';
}

/// Récupère la première page pour connaître `totalRecordCount`, puis le
/// reste par lots d'au plus [concurrency] pages simultanées (pas toutes
/// d'un coup) — [pageSize] par page. Fusionne dans l'ordre des pages
/// (`startIndex` croissant), jamais dans l'ordre d'arrivée : deux appels
/// identiques doivent produire le même ordre, indépendamment des aléas
/// réseau qui font terminer une page avant une autre.
///
/// [onFirstPage], s'il est fourni, est appelé dès que la première page
/// répond — bien avant que cette fonction elle-même ne retourne (qui
/// attend toutes les pages) — pour qu'un appelant puisse publier un
/// aperçu anticipé sans attendre la fusion complète (cf. calibrage :
/// diffusion progressive). Jamais appelé une seconde fois : un seul
/// aperçu, jamais un par page.
Future<PaginatedFetchResult<T>> fetchAllPagesConcurrently<T>(
  PageFetcher<T> fetchPage, {
  int pageSize = 200,
  int concurrency = 4,
  void Function(List<T> firstPageItems)? onFirstPage,
}) async {
  final overallTimer = Stopwatch()..start();
  final pageTimings = <PageTiming>[];
  final pagesByStart = <int, List<T>>{};

  final first = await _fetchPageWithRetry(fetchPage, 0, pageSize, pageTimings);
  pagesByStart[0] = first.items;
  onFirstPage?.call(first.items);
  final total = first.totalRecordCount;

  if (total > pageSize) {
    final remainingStarts = [
      for (var start = pageSize; start < total; start += pageSize) start,
    ];
    for (var i = 0; i < remainingStarts.length; i += concurrency) {
      final batch = remainingStarts.skip(i).take(concurrency);
      final results = await Future.wait([
        for (final start in batch)
          _fetchPageWithRetry(fetchPage, start, pageSize, pageTimings)
              .then((result) => (start: start, result: result)),
      ]);
      for (final entry in results) {
        pagesByStart[entry.start] = entry.result.items;
      }
    }
  }

  final orderedStarts = pagesByStart.keys.toList()..sort();
  final items = [for (final start in orderedStarts) ...pagesByStart[start]!];

  final slowest = pageTimings.isEmpty
      ? Duration.zero
      : pageTimings.map((p) => p.elapsed).reduce((a, b) => a > b ? a : b);

  return (
    items: items,
    pageCount: pageTimings.length,
    totalElapsed: overallTimer.elapsed,
    slowestPageElapsed: slowest,
    pageTimings: List<PageTiming>.unmodifiable(pageTimings),
  );
}

Future<PageResult<T>> _fetchPageWithRetry<T>(
  PageFetcher<T> fetchPage,
  int startIndex,
  int limit,
  List<PageTiming> pageTimings,
) async {
  // Un seul chronomètre, jamais réinitialisé entre les deux essais : le
  // temps rapporté pour une page retentée est le temps réel écoulé
  // depuis le tout premier essai, pas seulement celui du second —
  // sinon "la page la plus lente" sous-estimerait exactement les pages
  // qui ont eu besoin d'un nouvel essai.
  final timer = Stopwatch()..start();
  try {
    final result = await fetchPage(startIndex: startIndex, limit: limit);
    pageTimings
        .add((startIndex: startIndex, elapsed: timer.elapsed, retried: false));
    return result;
  } catch (_) {
    try {
      final result = await fetchPage(startIndex: startIndex, limit: limit);
      pageTimings
          .add((startIndex: startIndex, elapsed: timer.elapsed, retried: true));
      return result;
    } catch (e) {
      throw PaginatedFetchException(startIndex, e);
    }
  }
}
