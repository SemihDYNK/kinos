import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

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
    if (status == 401 || status == 403)
      return const ArrFailure(ArrApiError.unauthorized);
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

  void close() => _client.close();
}

class RadarrApiClient extends ArrApiClient {
  RadarrApiClient(
      {required super.baseUrl, required super.apiKey, super.httpClient});

  @override
  String get expectedAppName => 'Radarr';
}

class SonarrApiClient extends ArrApiClient {
  SonarrApiClient(
      {required super.baseUrl, required super.apiKey, super.httpClient});

  @override
  String get expectedAppName => 'Sonarr';
}
