import 'dart:convert';
import 'dart:developer';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:fladder/models/credentials_model.dart';

/// Persists [CredentialsModel] (server URL, token, deviceId, ...) in the
/// platform's secure credential vault instead of plain SharedPreferences -
/// Keystore-backed on Android, Keychain on iOS/macOS, DPAPI on Windows, and
/// libsecret (the same secret-service API GNOME Keyring/KWallet implement)
/// on Linux.
///
/// Entries are keyed by `serverId:userId`, so the same device can hold
/// credentials for several server/user combinations (multi-profile) without
/// collisions - the same pair `AccountModel.sameIdentity` already uses to
/// tell accounts apart.
class SecureCredentialsStore {
  const SecureCredentialsStore({FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static String keyFor(String serverId, String userId) => '$serverId:$userId';

  Future<void> save(String serverId, String userId, CredentialsModel credentials) =>
      _storage.write(key: keyFor(serverId, userId), value: jsonEncode(credentials.toJson()));

  Future<CredentialsModel?> read(String serverId, String userId) async {
    final raw = await _storage.read(key: keyFor(serverId, userId));
    if (raw == null) return null;
    try {
      return CredentialsModel.fromJson(jsonDecode(raw));
    } catch (e, stacktrace) {
      log('Failed to decode secure credentials for ${keyFor(serverId, userId)}: $e\n$stacktrace');
      return null;
    }
  }

  Future<void> delete(String serverId, String userId) => _storage.delete(key: keyFor(serverId, userId));
}
