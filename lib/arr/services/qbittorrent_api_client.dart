import 'dart:async';

import 'package:http/http.dart' as http;

/// Client minimal pour l'API WebUI de qBittorrent (v2) — seule raison
/// d'être : pause/reprise d'un téléchargement par hash, une action que
/// l'API Radarr/Sonarr n'expose pas elle-même (`/api/v3/queue/{id}/pause`
/// répond 405 — confirmé contre un serveur réel, seul DELETE est accepté
/// sur ce chemin). `downloadId` d'une ligne de file *Arr est le hash du
/// torrent chez qBittorrent : c'est la clé attendue ici.
///
/// Authentification par cookie de session (`POST /api/v2/auth/login`),
/// pas de clé API — c'est ce que l'API WebUI attend. Session tenue en
/// mémoire pour la durée de vie du client, jamais persistée.
class QBittorrentApiClient {
  QBittorrentApiClient({
    required this.baseUrl,
    required this.username,
    required this.password,
    http.Client? httpClient,
  }) : _client = httpClient ?? http.Client();

  final String baseUrl;
  final String username;
  final String password;
  final http.Client _client;

  static const _timeout = Duration(seconds: 15);

  String? _sessionCookie;

  Uri _resolve(String path) {
    final trimmed = baseUrl.trim();
    final normalized = trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
    return Uri.parse('$normalized$path');
  }

  Future<bool> _ensureLoggedIn() async {
    if (_sessionCookie != null) return true;
    return _login();
  }

  Future<bool> _login() async {
    try {
      final response = await _client.post(
        _resolve('/api/v2/auth/login'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'username': username, 'password': password},
      ).timeout(_timeout);
      // qBittorrent répond 200 avec le corps "Fails." sur des identifiants
      // invalides — jamais un code d'erreur HTTP pour ce cas précis.
      if (response.statusCode != 200 || response.body.trim() != 'Ok.') {
        return false;
      }
      final setCookie = response.headers['set-cookie'];
      if (setCookie == null) return false;
      // "SID=xxxxxxxx; path=/; HttpOnly" — seul le couple nom=valeur nous
      // intéresse pour le renvoyer tel quel en en-tête `Cookie`.
      _sessionCookie = setCookie.split(';').first.trim();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// `null` : la route elle-même n'existe pas (404) — l'appelant peut
  /// retenter avec l'autre nom d'action. `true`/`false` : résultat
  /// définitif (y compris une erreur réseau), plus de retentative.
  Future<bool?> _tryAction(String action, String hash) async {
    try {
      final response = await _client.post(
        _resolve('/api/v2/torrents/$action'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          if (_sessionCookie != null) 'Cookie': _sessionCookie!,
        },
        body: {'hashes': hash},
      ).timeout(_timeout);
      if (response.statusCode == 404) return null;
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Essaie le nom d'action introduit par qBittorrent 5.x d'abord
  /// (`stop`/`start`), puis se replie sur l'ancien nom (`pause`/`resume`,
  /// toujours en service sur les versions précédentes) si la route
  /// renvoie 404 — plus simple et tout aussi fiable qu'analyser la
  /// version exacte du serveur pour choisir entre les deux.
  Future<bool> _actionWithFallback(
      String newAction, String oldAction, String hash) async {
    if (!await _ensureLoggedIn()) return false;
    final withNewName = await _tryAction(newAction, hash);
    if (withNewName != null) return withNewName;
    return await _tryAction(oldAction, hash) ?? false;
  }

  Future<bool> pause(String hash) => _actionWithFallback('stop', 'pause', hash);

  Future<bool> resume(String hash) =>
      _actionWithFallback('start', 'resume', hash);

  /// Vérifie que l'URL et les identifiants mènent bien à une instance
  /// qBittorrent joignable.
  Future<bool> testConnection() => _ensureLoggedIn();

  void close() => _client.close();
}
