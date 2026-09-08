import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:http/http.dart' as http;

import 'package:kinos/arr/models/arr_library_item.dart';
import 'package:kinos/arr/models/arr_media_detail.dart';
import 'package:kinos/arr/models/arr_queue_item.dart';
import 'package:kinos/arr/models/arr_release.dart';

/// Catégories d'échec explicites, pour un message clair côté écran —
/// jamais une exception brute affichée telle quelle.
enum ArrApiError {
  /// URL injoignable : DNS, connexion refusée, TLS, délai dépassé, URL
  /// malformée.
  unreachable,

  /// Clé API absente ou invalide (401/403).
  unauthorized,

  /// Route inexistante (404) — le plus souvent une base URL erronée
  /// (bon hôte, mauvais chemin) plutôt qu'un vrai contenu manquant.
  notFound,

  /// Réponse HTTP inattendue (autre code que succès/401/403/404).
  serverError,

  /// Réponse 2xx mais illisible ou de forme inattendue — ex. un serveur
  /// qui répond, mais pas avec du JSON *Arr (mauvais service, proxy...).
  invalidResponse,
}

/// Résultat d'un appel — succès avec les données décodées, ou échec avec
/// une catégorie et un détail optionnel destiné à l'utilisateur.
sealed class ArrResult<T> {
  const ArrResult();
}

class ArrSuccess<T> extends ArrResult<T> {
  final T data;
  const ArrSuccess(this.data);
}

class ArrFailure<T> extends ArrResult<T> {
  final ArrApiError error;
  final String? detail;
  const ArrFailure(this.error, [this.detail]);
}

/// Résultat du test de connexion (`GET /api/v3/system/status`).
sealed class ArrConnectionResult {
  const ArrConnectionResult();
}

class ArrConnectionOk extends ArrConnectionResult {
  final String version;
  const ArrConnectionOk(this.version);
}

class ArrConnectionFailed extends ArrConnectionResult {
  final ArrApiError error;
  final String? detail;
  const ArrConnectionFailed(this.error, [this.detail]);
}

/// Client HTTP minimal pour l'API v3, commune à Radarr et Sonarr :
/// en-tête `X-Api-Key`, URL de base configurable. Module neuf et isolé
/// (cf. CLAUDE.md § Règles de fork) — un client `package:http` direct
/// suffit à sa surface d'API, pas besoin du client généré (chopper) de
/// l'intégration Jellyfin.
abstract class ArrApiClient {
  ArrApiClient({
    required this.baseUrl,
    required this.apiKey,
    http.Client? httpClient,
  }) : _client = httpClient ?? http.Client();

  final String baseUrl;
  final String apiKey;
  final http.Client _client;

  static const _timeout = Duration(seconds: 30);

  /// Nom d'application attendu dans la réponse de `/system/status` — sert
  /// à détecter une URL/clé Radarr collée dans les réglages Sonarr (ou
  /// l'inverse), l'erreur de configuration la plus probable en pratique.
  String get expectedAppName;

  Uri _resolve(String path, [Map<String, String>? query]) {
    final trimmed = baseUrl.trim();
    final normalized = trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
    final uri = Uri.parse('$normalized$path');
    return query == null ? uri : uri.replace(queryParameters: query);
  }

  Map<String, String> get _headers => {
        'X-Api-Key': apiKey,
        'Accept': 'application/json',
      };

  Future<ArrResult<dynamic>> get(String path,
      {Map<String, String>? query}) async {
    final Uri uri;
    try {
      uri = _resolve(path, query);
    } on FormatException {
      return const ArrFailure(ArrApiError.unreachable, 'URL invalide');
    }
    try {
      final response =
          await _client.get(uri, headers: _headers).timeout(_timeout);
      return _handle(response);
    } on TimeoutException {
      return const ArrFailure(ArrApiError.unreachable, 'Délai dépassé');
    } catch (e) {
      return ArrFailure(ArrApiError.unreachable, e.toString());
    }
  }

  Future<ArrResult<dynamic>> post(String path, {Object? body}) async {
    final Uri uri;
    try {
      uri = _resolve(path);
    } on FormatException {
      return const ArrFailure(ArrApiError.unreachable, 'URL invalide');
    }
    try {
      final response = await _client
          .post(
            uri,
            headers: {..._headers, 'Content-Type': 'application/json'},
            body: body == null ? null : jsonEncode(body),
          )
          .timeout(_timeout);
      return _handle(response);
    } on TimeoutException {
      return const ArrFailure(ArrApiError.unreachable, 'Délai dépassé');
    } catch (e) {
      return ArrFailure(ArrApiError.unreachable, e.toString());
    }
  }

  Future<ArrResult<dynamic>> put(String path, {Object? body}) async {
    final Uri uri;
    try {
      uri = _resolve(path);
    } on FormatException {
      return const ArrFailure(ArrApiError.unreachable, 'URL invalide');
    }
    try {
      final response = await _client
          .put(
            uri,
            headers: {..._headers, 'Content-Type': 'application/json'},
            body: body == null ? null : jsonEncode(body),
          )
          .timeout(_timeout);
      return _handle(response);
    } on TimeoutException {
      return const ArrFailure(ArrApiError.unreachable, 'Délai dépassé');
    } catch (e) {
      return ArrFailure(ArrApiError.unreachable, e.toString());
    }
  }

  Future<ArrResult<dynamic>> delete(String path,
      {Map<String, String>? query, Object? body}) async {
    final Uri uri;
    try {
      uri = _resolve(path, query);
    } on FormatException {
      return const ArrFailure(ArrApiError.unreachable, 'URL invalide');
    }
    try {
      final response = await _client
          .delete(
            uri,
            headers: {..._headers, 'Content-Type': 'application/json'},
            body: body == null ? null : jsonEncode(body),
          )
          .timeout(_timeout);
      return _handle(response);
    } on TimeoutException {
      return const ArrFailure(ArrApiError.unreachable, 'Délai dépassé');
    } catch (e) {
      return ArrFailure(ArrApiError.unreachable, e.toString());
    }
  }

  ArrResult<dynamic> _handle(http.Response response) {
    final status = response.statusCode;
    if (status >= 200 && status < 300) {
      if (response.body.isEmpty) return const ArrSuccess(null);
      try {
        return ArrSuccess(jsonDecode(response.body));
      } on FormatException {
        return const ArrFailure(
            ArrApiError.invalidResponse, 'Réponse illisible');
      }
    }
    if (status == 401 || status == 403) {
      return const ArrFailure(ArrApiError.unauthorized);
    }
    if (status == 404) return const ArrFailure(ArrApiError.notFound);
    return ArrFailure(ArrApiError.serverError, 'HTTP $status');
  }

  /// `GET /api/v3/system/status` — vérifie que l'URL et la clé mènent
  /// bien à une instance *Arr du bon type, et récupère sa version.
  Future<ArrConnectionResult> testConnection() async {
    final result = await get('/api/v3/system/status');
    return switch (result) {
      ArrSuccess(:final data) => _parseStatus(data),
      ArrFailure(:final error, :final detail) =>
        ArrConnectionFailed(error, detail),
    };
  }

  ArrConnectionResult _parseStatus(dynamic data) {
    if (data is! Map) {
      return const ArrConnectionFailed(
          ArrApiError.invalidResponse, 'Réponse inattendue');
    }
    final version = data['version'] as String?;
    if (version == null || version.isEmpty) {
      return const ArrConnectionFailed(
          ArrApiError.invalidResponse, 'Version absente de la réponse');
    }
    final appName = data['appName'] as String?;
    if (appName != null &&
        appName.toLowerCase() != expectedAppName.toLowerCase()) {
      return ArrConnectionFailed(
        ArrApiError.invalidResponse,
        'Ce serveur répond comme $appName, pas $expectedAppName — URL ou clé inversées avec l\'autre service ?',
      );
    }
    return ArrConnectionOk(version);
  }

  /// `GET /api/v3/release`, un des deux jeux de paramètres attendus par
  /// l'API : `{movieId}` (Radarr), `{episodeId}` ou
  /// `{seriesId, seasonNumber}` (Sonarr) — cf. [RadarrApiClient.releasesForMovie],
  /// [SonarrApiClient.releasesForEpisode], [SonarrApiClient.releasesForSeason].
  /// Peut prendre jusqu'à 30s : l'indexeur est interrogé en direct, pas une
  /// base locale.
  Future<ArrResult<List<ArrRelease>>> searchReleases(
      Map<String, String> query) async {
    final result = await get('/api/v3/release', query: query);
    return switch (result) {
      ArrSuccess(:final data) => _parseReleases(data),
      ArrFailure(:final error, :final detail) => ArrFailure(error, detail),
    };
  }

  ArrResult<List<ArrRelease>> _parseReleases(dynamic data) {
    if (data is! List) {
      return const ArrFailure(
          ArrApiError.invalidResponse, 'Réponse inattendue');
    }
    // Diagnostic (build debug uniquement, retiré des builds release par
    // `assert`) : imprime les champs bruts du premier résultat, pour
    // confirmer les noms de champs réellement renvoyés par le serveur en
    // cas de doute (âge, score, rejet...) sans avoir à ajouter un point
    // d'arrêt.
    assert(() {
      final first =
          data.isNotEmpty && data.first is Map ? data.first as Map : null;
      if (first != null) {
        log('Arr release (diagnostic) — rejected=${first['rejected']} '
            '(${first['rejected'].runtimeType}), rejections=${first['rejections']}, '
            'customFormatScore=${first['customFormatScore']} '
            '(${first['customFormatScore'].runtimeType}), age=${first['age']}, '
            'ageHours=${first['ageHours']}, publishDate=${first['publishDate']}');
      }
      return true;
    }());
    try {
      return ArrSuccess(data
          .whereType<Map<String, dynamic>>()
          .map(ArrRelease.fromJson)
          .toList());
    } catch (_) {
      return const ArrFailure(ArrApiError.invalidResponse, 'Réponse illisible');
    }
  }

  /// `POST /api/v3/release` — envoie la release au téléchargement. Mêmes
  /// `guid`/`indexerId` que ceux affichés dans le tableau de résultats.
  Future<ArrResult<void>> grabRelease({
    required String guid,
    required int indexerId,
  }) async {
    final result = await post('/api/v3/release', body: {
      'guid': guid,
      'indexerId': indexerId,
    });
    return switch (result) {
      ArrSuccess() => const ArrSuccess(null),
      ArrFailure(:final error, :final detail) => ArrFailure(error, detail),
    };
  }

  /// `GET /api/v3/queue` — file d'attente de téléchargement, tous les
  /// éléments d'une page (250 : largement au-delà de ce qu'une file
  /// affiche en pratique, évite d'avoir à paginer un tableau qui se
  /// rafraîchit déjà toutes les 5s). `includeUnknownXItems` couvre les
  /// entrées pas encore rattachées à un film/épisode connu (import
  /// manuel en attente), qui resteraient sinon invisibles.
  Future<ArrResult<List<ArrQueueItem>>> fetchQueue() async {
    final result = await get('/api/v3/queue', query: {
      'page': '1',
      'pageSize': '250',
      'includeUnknownMovieItems': 'true',
      'includeUnknownSeriesItems': 'true',
    });
    return switch (result) {
      ArrSuccess(:final data) => _parseQueue(data),
      ArrFailure(:final error, :final detail) => ArrFailure(error, detail),
    };
  }

  ArrResult<List<ArrQueueItem>> _parseQueue(dynamic data) {
    // Réponse paginée : `{records: [...], totalRecords: ...}`, pas une
    // liste nue comme `/release` — à la différence de la plupart des
    // autres endpoints de ce client.
    final records = data is Map ? data['records'] : null;
    if (records is! List) {
      return const ArrFailure(
          ArrApiError.invalidResponse, 'Réponse inattendue');
    }

    // Diagnostic (build debug uniquement) : Radarr porte `movie` en plus
    // des champs communs, Sonarr porte `series`/`episode` — si un champ
    // scalaire venait à différer entre les deux services d'une façon que
    // ArrQueueItem.fromJson ne tolère pas encore, ce sont ces clés-là
    // qu'il faut comparer.
    assert(() {
      final first = records.isNotEmpty && records.first is Map
          ? records.first as Map
          : null;
      if (first != null) {
        log('Arr queue (diagnostic) — clés du premier enregistrement : '
            '${first.keys.toList()}');
      }
      return true;
    }());

    // Chaque ligne est isolée : ArrQueueItem.fromJson ne devrait plus
    // lever (tous ses champs se replient proprement), mais une ligne
    // malformée d'une façon totalement imprévue ne doit dans tous les
    // cas jamais faire disparaître la file entière — seulement cette
    // ligne-là.
    final items = <ArrQueueItem>[];
    for (final record in records.whereType<Map<String, dynamic>>()) {
      try {
        items.add(ArrQueueItem.fromJson(record));
      } catch (e) {
        assert(() {
          log('Arr queue (diagnostic) — ligne ignorée, exception : $e');
          return true;
        }());
      }
    }
    return ArrSuccess(items);
  }

  /// `DELETE /api/v3/queue/{id}` — retire une ligne. [removeFromClient]
  /// annule aussi le téléchargement chez le client (torrent/usenet), pas
  /// seulement dans la file *Arr ; [blocklist] empêche le même
  /// téléchargement d'être proposé à nouveau et déclenche une recherche
  /// de remplacement côté serveur.
  Future<ArrResult<void>> removeQueueItem(
    int id, {
    required bool removeFromClient,
    required bool blocklist,
  }) async {
    final result = await delete('/api/v3/queue/$id', query: {
      'removeFromClient': removeFromClient.toString(),
      'blocklist': blocklist.toString(),
    });
    return switch (result) {
      ArrSuccess() => const ArrSuccess(null),
      ArrFailure(:final error, :final detail) => ArrFailure(error, detail),
    };
  }

  /// `DELETE /api/v3/queue/bulk` — même effet que [removeQueueItem], sur
  /// plusieurs lignes en un seul appel (sélection multiple).
  Future<ArrResult<void>> removeQueueItems(
    List<int> ids, {
    required bool removeFromClient,
    required bool blocklist,
  }) async {
    final result = await delete('/api/v3/queue/bulk', query: {
      'removeFromClient': removeFromClient.toString(),
      'blocklist': blocklist.toString(),
    }, body: {
      'ids': ids,
    });
    return switch (result) {
      ArrSuccess() => const ArrSuccess(null),
      ArrFailure(:final error, :final detail) => ArrFailure(error, detail),
    };
  }

  /// `POST /api/v3/queue/grab/{id}` — force l'import d'une ligne bloquée
  /// (import en attente/rejeté). Endpoint non vérifié contre un serveur
  /// réel au moment d'écrire ceci : un 404/405 signifie que cette version
  /// de Radarr/Sonarr ne l'expose pas ainsi — l'écran doit alors afficher
  /// l'échec plutôt que prétendre avoir réussi.
  Future<ArrResult<void>> forceImportQueueItem(int id) async {
    final result = await post('/api/v3/queue/grab/$id');
    return switch (result) {
      ArrSuccess() => const ArrSuccess(null),
      ArrFailure(:final error, :final detail) => ArrFailure(error, detail),
    };
  }

  // Pas de pause/reprise ici : confirmé contre un serveur réel que
  // `/api/v3/queue/{id}/pause` répond 405 (seul DELETE est accepté sur ce
  // chemin) — l'API *Arr n'expose pas cette action, elle appartient au
  // client de téléchargement lui-même. Cf. QBittorrentApiClient.

  /// `GET /api/v3/qualityprofile` — même ressource pour Radarr et Sonarr,
  /// sert au sélecteur de profil de la fiche détail (édition).
  Future<ArrResult<List<ArrQualityProfile>>> fetchQualityProfiles() async {
    final result = await get('/api/v3/qualityprofile');
    return switch (result) {
      ArrSuccess(:final data) when data is List => ArrSuccess(data
          .whereType<Map<String, dynamic>>()
          .map(ArrQualityProfile.fromJson)
          .toList()),
      ArrSuccess() =>
        const ArrFailure(ArrApiError.invalidResponse, 'Réponse inattendue'),
      ArrFailure(:final error, :final detail) => ArrFailure(error, detail),
    };
  }

  /// `GET /api/v3/rootfolder` — même ressource pour Radarr et Sonarr, sert
  /// au sélecteur de dossier racine de la fiche détail (édition).
  Future<ArrResult<List<ArrRootFolder>>> fetchRootFolders() async {
    final result = await get('/api/v3/rootfolder');
    return switch (result) {
      ArrSuccess(:final data) when data is List => ArrSuccess(data
          .whereType<Map<String, dynamic>>()
          .map(ArrRootFolder.fromJson)
          .toList()),
      ArrSuccess() =>
        const ArrFailure(ArrApiError.invalidResponse, 'Réponse inattendue'),
      ArrFailure(:final error, :final detail) => ArrFailure(error, detail),
    };
  }

  void close() => _client.close();
}

/// Caractères accentués courants (français, mais aussi espagnol,
/// allemand, portugais...) vers leur équivalent non accentué — pas de
/// `dart:ui`/paquet de normalisation Unicode disponible ici, une table de
/// correspondance directe suffit au cas d'usage (titres de films/séries).
const _accentedChars =
    'ÀÁÂÃÄÅàáâãäåÒÓÔÕÖØòóôõöøÈÉÊËèéêëÇçÌÍÎÏìíîïÙÚÛÜùúûüÑñŸÿýŽžŠšČčĆćĐđ';
const _plainChars =
    'AAAAAAaaaaaaOOOOOOooooooEEEEeeeeCcIIIIiiiiUUUUuuuuNnYyyZzSsCcCcDd';

String _stripDiacritics(String value) {
  final buffer = StringBuffer();
  for (final rune in value.runes) {
    final char = String.fromCharCode(rune);
    final index = _accentedChars.indexOf(char);
    buffer.write(index == -1 ? char : _plainChars[index]);
  }
  return buffer.toString();
}

/// Normalise pour une comparaison insensible à la casse ET aux accents —
/// une recherche "transformers" doit retrouver "Trans4mers" comme
/// "Astérix" doit retrouver "Asterix".
String _normalizeForSearch(String value) =>
    _stripDiacritics(value.toLowerCase());

/// Titres candidats d'un film/série (bibliothèque Radarr/Sonarr) pour la
/// correspondance de recherche : le titre principal, mais aussi le titre
/// original (langue d'origine, souvent différent du titre localisé) et
/// les titres alternatifs (`alternateTitles[].title`) — sans ces deux
/// derniers, une recherche ne retrouve que les entrées dont le titre
/// *affiché* correspond exactement, ratant tout le reste de la
/// bibliothèque.
Iterable<String> _titleCandidates(Map<String, dynamic> json) sync* {
  final title = json['title'];
  if (title is String && title.isNotEmpty) yield title;
  final original = json['originalTitle'];
  if (original is String && original.isNotEmpty) yield original;
  final alternates = json['alternateTitles'];
  if (alternates is List) {
    for (final entry in alternates) {
      if (entry is Map && entry['title'] is String) {
        yield entry['title'] as String;
      } else if (entry is String) {
        yield entry;
      }
    }
  }
}

/// Correspondance appliquée côté client sur la réponse brute (avant
/// construction du modèle d'affichage) : l'API ne propose pas de
/// recherche texte sur `/movie` ou `/series`, qui renvoient toute la
/// bibliothèque — seuls les films/séries déjà ajoutés à Radarr/Sonarr
/// peuvent donc apparaître ici, ce n'est pas une recherche TMDB/TVDB.
/// Insensible à la casse et aux accents ; cherche aussi dans le titre
/// original et les titres alternatifs, pas seulement le titre affiché.
bool _matchesQuery(Map<String, dynamic> json, String query) {
  final normalizedQuery = _normalizeForSearch(query.trim());
  if (normalizedQuery.isEmpty) return true;
  return _titleCandidates(json)
      .any((title) => _normalizeForSearch(title).contains(normalizedQuery));
}

class RadarrApiClient extends ArrApiClient {
  RadarrApiClient(
      {required super.baseUrl, required super.apiKey, super.httpClient});

  @override
  String get expectedAppName => 'Radarr';

  /// `GET /api/v3/movie` — toute la bibliothèque, filtrée sur [query]
  /// côté client (cf. [_matchesQuery]).
  Future<ArrResult<List<ArrMovie>>> searchMovies(String query) async {
    final result = await get('/api/v3/movie');
    return switch (result) {
      ArrSuccess(:final data) when data is List => ArrSuccess(data
          .whereType<Map<String, dynamic>>()
          .where((json) => _matchesQuery(json, query))
          .map((json) =>
              ArrMovie.fromJson(json, baseUrl: baseUrl, apiKey: apiKey))
          .toList()),
      ArrSuccess() =>
        const ArrFailure(ArrApiError.invalidResponse, 'Réponse inattendue'),
      ArrFailure(:final error, :final detail) => ArrFailure(error, detail),
    };
  }

  Future<ArrResult<List<ArrRelease>>> releasesForMovie(int movieId) =>
      searchReleases({'movieId': movieId.toString()});

  /// `GET /api/v3/movie/{id}` — fiche complète (résumé, genres, note,
  /// dossier, taille, fichier présent...), pour la fiche détail. Distinct
  /// de [searchMovies] (qui alimente la grille bibliothèque avec des
  /// champs plus légers).
  Future<ArrResult<ArrMovieDetail>> fetchMovieDetail(int id) async {
    final result = await get('/api/v3/movie/$id');
    return switch (result) {
      ArrSuccess(:final data) when data is Map => ArrSuccess(
          ArrMovieDetail.fromJson(Map<String, dynamic>.from(data),
              baseUrl: baseUrl, apiKey: apiKey)),
      ArrSuccess() =>
        const ArrFailure(ArrApiError.invalidResponse, 'Réponse inattendue'),
      ArrFailure(:final error, :final detail) => ArrFailure(error, detail),
    };
  }

  /// `PUT /api/v3/movie/{id}` — repart de [ArrMovieDetail.raw] (corps
  /// complet exigé par Radarr) avec surveillance/profil/dossier racine
  /// mis à jour. Si le dossier racine change, recalcule [ArrMovieDetail
  /// .path] en gardant le même nom de dossier (ex.
  /// `/movies/Inception (2010)` -> `/nouveau-dossier/Inception (2010)`)
  /// et ajoute `moveFiles=true` pour que Radarr déplace le fichier déjà
  /// présent — comportement non vérifié contre un serveur réel : Radarr
  /// recalcule normalement lui-même ce chemin depuis son propre format de
  /// nommage, que ce client ne connaît pas ; cette reconstruction n'est
  /// donc qu'un raisonnable best-effort qui garde le nom de dossier
  /// existant plutôt que d'en inventer un.
  Future<ArrResult<void>> updateMovie(
    ArrMovieDetail detail, {
    required bool monitored,
    required int qualityProfileId,
    required String rootFolderPath,
  }) {
    final rootFolderChanged = detail.rootFolderPath != null &&
        detail.rootFolderPath != rootFolderPath &&
        rootFolderPath.isNotEmpty;
    final newPath =
        rootFolderChanged ? _relocatePath(detail.path, rootFolderPath) : null;
    final body = {
      ...detail.raw,
      'monitored': monitored,
      'qualityProfileId': qualityProfileId,
      'rootFolderPath': rootFolderPath,
      if (newPath != null) 'path': newPath,
    };
    final path = rootFolderChanged
        ? '/api/v3/movie/${detail.id}?moveFiles=true'
        : '/api/v3/movie/${detail.id}';
    return _asVoid(() => put(path, body: body));
  }

  /// `PUT /api/v3/movie/{id}` — repart de [ArrMovie.raw] (Radarr exige le
  /// corps complet de la ressource, pas un correctif partiel) avec
  /// uniquement `monitored` changé.
  Future<ArrResult<void>> setMovieMonitored(ArrMovie movie, bool monitored) =>
      _asVoid(() => put('/api/v3/movie/${movie.id}',
          body: {...movie.raw, 'monitored': monitored}));

  /// `DELETE /api/v3/movie/{id}` — retire aussi le fichier déjà
  /// téléchargé, cohérent avec le "supprimer" attendu depuis la grille
  /// (pas seulement un retrait du suivi Radarr).
  Future<ArrResult<void>> deleteMovie(int id) => _asVoid(
      () => delete('/api/v3/movie/$id', query: const {'deleteFiles': 'true'}));

  /// `POST /api/v3/command` `{name: "MoviesSearch", movieIds: [id]}` —
  /// recherche automatique (indexeurs déjà configurés), pas la recherche
  /// interactive avec sélection manuelle de release.
  Future<ArrResult<void>> triggerMovieSearch(int id) =>
      _asVoid(() => post('/api/v3/command', body: {
            'name': 'MoviesSearch',
            'movieIds': [id]
          }));
}

class SonarrApiClient extends ArrApiClient {
  SonarrApiClient(
      {required super.baseUrl, required super.apiKey, super.httpClient});

  @override
  String get expectedAppName => 'Sonarr';

  /// `GET /api/v3/series` — toute la bibliothèque, filtrée sur [query]
  /// côté client (cf. [_matchesQuery]).
  Future<ArrResult<List<ArrSeries>>> searchSeries(String query) async {
    final result = await get('/api/v3/series');
    return switch (result) {
      ArrSuccess(:final data) when data is List => ArrSuccess(data
          .whereType<Map<String, dynamic>>()
          .where((json) => _matchesQuery(json, query))
          .map((json) =>
              ArrSeries.fromJson(json, baseUrl: baseUrl, apiKey: apiKey))
          .toList()),
      ArrSuccess() =>
        const ArrFailure(ArrApiError.invalidResponse, 'Réponse inattendue'),
      ArrFailure(:final error, :final detail) => ArrFailure(error, detail),
    };
  }

  /// `GET /api/v3/episode?seriesId=` — tous les épisodes d'une série,
  /// pour le sélecteur saison/épisode.
  Future<ArrResult<List<ArrEpisode>>> episodesForSeries(int seriesId) async {
    final result =
        await get('/api/v3/episode', query: {'seriesId': seriesId.toString()});
    return switch (result) {
      ArrSuccess(:final data) when data is List => ArrSuccess(data
          .whereType<Map<String, dynamic>>()
          .map(ArrEpisode.fromJson)
          .toList()),
      ArrSuccess() =>
        const ArrFailure(ArrApiError.invalidResponse, 'Réponse inattendue'),
      ArrFailure(:final error, :final detail) => ArrFailure(error, detail),
    };
  }

  Future<ArrResult<List<ArrRelease>>> releasesForEpisode(int episodeId) =>
      searchReleases({'episodeId': episodeId.toString()});

  Future<ArrResult<List<ArrRelease>>> releasesForSeason(
          int seriesId, int seasonNumber) =>
      searchReleases({
        'seriesId': seriesId.toString(),
        'seasonNumber': seasonNumber.toString(),
      });

  /// `GET /api/v3/series/{id}` — fiche complète, dont la liste des
  /// saisons. Distinct de [searchSeries] — cf. [RadarrApiClient
  /// .fetchMovieDetail].
  Future<ArrResult<ArrSeriesDetail>> fetchSeriesDetail(int id) async {
    final result = await get('/api/v3/series/$id');
    return switch (result) {
      ArrSuccess(:final data) when data is Map => ArrSuccess(
          ArrSeriesDetail.fromJson(Map<String, dynamic>.from(data),
              baseUrl: baseUrl, apiKey: apiKey)),
      ArrSuccess() =>
        const ArrFailure(ArrApiError.invalidResponse, 'Réponse inattendue'),
      ArrFailure(:final error, :final detail) => ArrFailure(error, detail),
    };
  }

  /// `PUT /api/v3/series/{id}` — même principe que [RadarrApiClient
  /// .updateMovie], y compris la mise en garde sur le recalcul de chemin.
  Future<ArrResult<void>> updateSeries(
    ArrSeriesDetail detail, {
    required bool monitored,
    required int qualityProfileId,
    required String rootFolderPath,
  }) {
    final rootFolderChanged = detail.rootFolderPath != null &&
        detail.rootFolderPath != rootFolderPath &&
        rootFolderPath.isNotEmpty;
    final newPath =
        rootFolderChanged ? _relocatePath(detail.path, rootFolderPath) : null;
    final body = {
      ...detail.raw,
      'monitored': monitored,
      'qualityProfileId': qualityProfileId,
      'rootFolderPath': rootFolderPath,
      if (newPath != null) 'path': newPath,
    };
    final path = rootFolderChanged
        ? '/api/v3/series/${detail.id}?moveFiles=true'
        : '/api/v3/series/${detail.id}';
    return _asVoid(() => put(path, body: body));
  }

  /// `PUT /api/v3/series/{id}` — même principe que
  /// [RadarrApiClient.setMovieMonitored].
  Future<ArrResult<void>> setSeriesMonitored(
          ArrSeries series, bool monitored) =>
      _asVoid(() => put('/api/v3/series/${series.id}',
          body: {...series.raw, 'monitored': monitored}));

  /// `DELETE /api/v3/series/{id}` — retire aussi les fichiers déjà
  /// téléchargés.
  Future<ArrResult<void>> deleteSeries(int id) => _asVoid(
      () => delete('/api/v3/series/$id', query: const {'deleteFiles': 'true'}));

  /// `POST /api/v3/command` `{name: "SeriesSearch", seriesId: id}` —
  /// recherche automatique de tous les épisodes manquants surveillés.
  Future<ArrResult<void>> triggerSeriesSearch(int id) => _asVoid(() =>
      post('/api/v3/command', body: {'name': 'SeriesSearch', 'seriesId': id}));
}

/// Reconstruit un chemin sous un nouveau dossier racine en gardant le nom
/// de dossier existant (dernier segment de [currentPath]) — cf. la mise
/// en garde sur [RadarrApiClient.updateMovie]. `null` si [currentPath] est
/// absent (rien à recalculer).
String? _relocatePath(String? currentPath, String newRootFolder) {
  if (currentPath == null || currentPath.isEmpty) return null;
  final normalizedRoot = newRootFolder.endsWith('/')
      ? newRootFolder.substring(0, newRootFolder.length - 1)
      : newRootFolder;
  final segments = currentPath.split('/').where((s) => s.isNotEmpty);
  if (segments.isEmpty) return null;
  return '$normalizedRoot/${segments.last}';
}

/// Réduit un résultat de faible intérêt (le corps de la réponse
/// PUT/DELETE/POST /command n'est pas exploité par les appelants) à
/// succès/échec, en conservant la catégorie d'erreur.
Future<ArrResult<void>> _asVoid(
    Future<ArrResult<dynamic>> Function() call) async {
  final result = await call();
  return switch (result) {
    ArrSuccess() => const ArrSuccess(null),
    ArrFailure(:final error, :final detail) => ArrFailure(error, detail),
  };
}
