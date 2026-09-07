import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:http/http.dart' as http;

import 'package:fladder/arr/models/arr_library_item.dart';
import 'package:fladder/arr/models/arr_release.dart';

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

  void close() => _client.close();
}

/// Correspondance simple, insensible à la casse, appliquée côté client :
/// l'API ne propose pas de recherche texte sur `/movie` ou `/series`, qui
/// renvoient toute la bibliothèque.
bool _matchesQuery(String title, String query) =>
    query.trim().isEmpty ||
    title.toLowerCase().contains(query.trim().toLowerCase());

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
          .map((json) =>
              ArrMovie.fromJson(json, baseUrl: baseUrl, apiKey: apiKey))
          .where((movie) => _matchesQuery(movie.title, query))
          .toList()),
      ArrSuccess() =>
        const ArrFailure(ArrApiError.invalidResponse, 'Réponse inattendue'),
      ArrFailure(:final error, :final detail) => ArrFailure(error, detail),
    };
  }

  Future<ArrResult<List<ArrRelease>>> releasesForMovie(int movieId) =>
      searchReleases({'movieId': movieId.toString()});
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
          .map((json) =>
              ArrSeries.fromJson(json, baseUrl: baseUrl, apiKey: apiKey))
          .where((series) => _matchesQuery(series.title, query))
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
}
