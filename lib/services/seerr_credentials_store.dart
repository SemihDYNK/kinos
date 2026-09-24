import 'dart:convert';
import 'dart:developer';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:kinos/models/seerr_credentials_model.dart';

/// Persists [SeerrCredentialsModel] (apiKey, sessionCookie) in the
/// platform's secure credential vault instead of plain SharedPreferences -
/// same policy as [SecureCredentialsStore] for Jellyfin credentials and
/// [ArrCredentialsStore] for Arr/qBittorrent.
///
/// Entries are keyed by `seerr:serverId:userId` - the `seerr:` prefix keeps
/// this namespace disjoint from [SecureCredentialsStore]'s own
/// `serverId:userId` keys in the same underlying vault, while the
/// `serverId:userId` suffix reuses the exact composite key Jellyfin
/// credentials already use, so the same device/profile pairing rules apply:
/// one account can never read another profile's Seerr credentials.
class SeerrCredentialsStore {
  const SeerrCredentialsStore({FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static String keyFor(String serverId, String userId) => 'seerr:$serverId:$userId';

  Future<void> save(String serverId, String userId, SeerrCredentialsModel credentials) =>
      _storage.write(key: keyFor(serverId, userId), value: jsonEncode(credentials.toJson()));

  Future<SeerrCredentialsModel?> read(String serverId, String userId) async {
    final raw = await _storage.read(key: keyFor(serverId, userId));
    if (raw == null) return null;
    try {
      return SeerrCredentialsModel.fromJson(jsonDecode(raw));
    } catch (e, stacktrace) {
      log('Failed to decode secure Seerr credentials for ${keyFor(serverId, userId)}: $e\n$stacktrace');
      return null;
    }
  }

  Future<void> delete(String serverId, String userId) => _storage.delete(key: keyFor(serverId, userId));
}
