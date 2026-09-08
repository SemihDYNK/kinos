import 'dart:convert';
import 'dart:developer';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:fladder/arr/models/qbittorrent_credentials.dart';

/// Persiste [QBittorrentCredentials] dans le coffre sécurisé — même
/// politique que [ArrCredentialsStore], jamais SharedPreferences. Une
/// seule instance de client de téléchargement (contrairement à
/// Radarr/Sonarr, pas de clé par service) : Radarr et Sonarr pointent
/// généralement vers le même qBittorrent.
class QBittorrentCredentialsStore {
  const QBittorrentCredentialsStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _key = 'qbittorrent:credentials';

  Future<void> save(QBittorrentCredentials credentials) =>
      _storage.write(key: _key, value: jsonEncode(credentials.toJson()));

  Future<QBittorrentCredentials?> read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return null;
    try {
      return QBittorrentCredentials.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (e, stacktrace) {
      log('Failed to decode secure qBittorrent credentials: $e\n$stacktrace');
      return null;
    }
  }

  Future<void> delete() => _storage.delete(key: _key);
}
