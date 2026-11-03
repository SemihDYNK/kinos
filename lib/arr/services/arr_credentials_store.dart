import 'dart:convert';
import 'dart:developer';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kinos/services/platform_secure_storage.dart';

import 'package:kinos/arr/models/arr_credentials.dart';
import 'package:kinos/arr/models/arr_service.dart';

/// Persiste [ArrCredentials] (URL, clé API) dans le coffre sécurisé de la
/// plateforme — même politique que [SecureCredentialsStore] pour les
/// identifiants Jellyfin, jamais SharedPreferences. Clé composite par
/// service : `arr:radarr` / `arr:sonarr`.
class ArrCredentialsStore {
  const ArrCredentialsStore({FlutterSecureStorage? storage})
      : _storage = storage ?? platformSecureStorage;

  final FlutterSecureStorage _storage;

  static String keyFor(ArrService service) => 'arr:${service.name}';

  Future<void> save(ArrService service, ArrCredentials credentials) => _storage
      .write(key: keyFor(service), value: jsonEncode(credentials.toJson()));

  Future<ArrCredentials?> read(ArrService service) async {
    final raw = await _storage.read(key: keyFor(service));
    if (raw == null) return null;
    try {
      return ArrCredentials.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e, stacktrace) {
      log('Failed to decode secure Arr credentials for ${keyFor(service)}: $e\n$stacktrace');
      return null;
    }
  }

  Future<void> delete(ArrService service) =>
      _storage.delete(key: keyFor(service));
}
