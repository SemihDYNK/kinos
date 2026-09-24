import 'package:flutter/services.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';

/// In-memory [FlutterSecureStoragePlatform] for tests.
///
/// `flutter_secure_storage`'s real backends (Keystore, Keychain, DPAPI,
/// libsecret) all go through platform channels, which aren't available in
/// `flutter test`. Installing this instead - the same way the package's own
/// docs recommend for tests - lets `SecureCredentialsStore` be exercised
/// against a real `FlutterSecureStorage()` without touching a platform.
class FakeSecureStoragePlatform extends FlutterSecureStoragePlatform {
  final Map<String, String> _values = {};

  /// Every [write] call, in order, as `key` - lets a test assert a key was
  /// written exactly once (e.g. to prove two concurrent migration attempts
  /// were memoized into a single one) without caring about the final value,
  /// which `_values` already covers.
  final List<String> writeLog = [];

  /// Simulates the vault being unavailable (e.g. no Linux keyring/secret
  /// service running) - every [write] throws instead of persisting,
  /// matching what a real backend failure looks like to callers.
  bool failWrites = false;

  /// Every [write] call attempted, whether it went on to throw
  /// ([failWrites]) or succeed - unlike [writeLog], which only records
  /// successful writes. Lets a test assert a durably-failing vault is only
  /// ever attempted once per session, not once per [getAccounts] call.
  int writeAttempts = 0;

  /// Installs a fresh fake as [FlutterSecureStoragePlatform.instance] and
  /// returns it, so tests can both use `FlutterSecureStorage()` normally and
  /// still inspect what ended up in the "vault".
  static FakeSecureStoragePlatform install() {
    final fake = FakeSecureStoragePlatform();
    FlutterSecureStoragePlatform.instance = fake;
    return fake;
  }

  Map<String, String> get values => Map.unmodifiable(_values);

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async {
    writeAttempts++;
    if (failWrites) {
      throw PlatformException(code: 'unavailable', message: 'Secure storage backend unavailable');
    }
    writeLog.add(key);
    _values[key] = value;
  }

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async =>
      _values[key];

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
  Future<Map<String, String>> readAll({required Map<String, String> options}) async => Map.of(_values);

  @override
  Future<void> deleteAll({required Map<String, String> options}) async {
    _values.clear();
  }
}
