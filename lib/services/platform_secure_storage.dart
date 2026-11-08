import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';

/// Uses the platform vault everywhere except unsigned macOS distribution
/// builds, whose Keychain access is rejected by macOS without a Developer ID.
const platformSecureStorage = FlutterSecureStorage(
  mOptions: MacOsOptions(usesDataProtectionKeychain: false),
);

/// Installs the macOS fallback before any account is restored.
///
/// The fallback intentionally dies with the app: persisting a token outside
/// the Keychain would weaken the credential-storage guarantee.
void configurePlatformSecureStorage() {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.macOS) return;
  if (FlutterSecureStoragePlatform.instance is _SessionSecureStorage) return;
  FlutterSecureStoragePlatform.instance = _SessionSecureStorage();
}

class _SessionSecureStorage extends FlutterSecureStoragePlatform {
  final _values = <String, String>{};

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async =>
      _values.containsKey(key);

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async {
    _values.remove(key);
  }

  @override
  Future<void> deleteAll({required Map<String, String> options}) async {
    _values.clear();
  }

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async =>
      _values[key];

  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async =>
      Map.of(_values);

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async {
    _values[key] = value;
  }
}
