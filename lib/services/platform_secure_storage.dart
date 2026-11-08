import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Uses the platform vault everywhere except unsigned macOS distribution
/// builds, whose Keychain access is rejected by macOS without a Developer ID.
const platformSecureStorage = FlutterSecureStorage(
  mOptions: MacOsOptions(usesDataProtectionKeychain: false),
);

/// Installs the macOS fallback before any account is restored.
///
/// shortcut: macOS credentials are persisted in a user-readable local file,
/// replace with Keychain when Kinos has a Developer ID profile.
Future<void> configurePlatformSecureStorage(
    {Directory? storageDirectory}) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.macOS) return;
  if (FlutterSecureStoragePlatform.instance is _MacOsFileSecureStorage) return;
  final directory = storageDirectory ?? await getApplicationSupportDirectory();
  FlutterSecureStoragePlatform.instance =
      await _MacOsFileSecureStorage.open(directory);
}

class _MacOsFileSecureStorage extends FlutterSecureStoragePlatform {
  _MacOsFileSecureStorage._(this._file, this._values);

  final File _file;
  final Map<String, String> _values;
  Future<void> _pending = Future.value();

  static Future<_MacOsFileSecureStorage> open(Directory directory) async {
    await directory.create(recursive: true);
    final file = File(path.join(directory.path, 'credentials.json'));
    if (!await file.exists()) return _MacOsFileSecureStorage._(file, {});
    await _restrictPermissions(file);
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return _MacOsFileSecureStorage._(file, {});
      final values = <String, String>{};
      for (final entry in decoded.entries) {
        if (entry.key is! String || entry.value is! String) {
          return _MacOsFileSecureStorage._(file, {});
        }
        values[entry.key as String] = entry.value as String;
      }
      return _MacOsFileSecureStorage._(file, values);
    } on FormatException {
      return _MacOsFileSecureStorage._(file, {});
    }
  }

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) =>
      _enqueue(() async => _values.containsKey(key));

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) =>
      _enqueue(() async {
        _values.remove(key);
        await _persist();
      });

  @override
  Future<void> deleteAll({required Map<String, String> options}) =>
      _enqueue(() async {
        _values.clear();
        await _persist();
      });

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) =>
      _enqueue(() async => _values[key]);

  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) =>
      _enqueue(() async => Map.of(_values));

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) =>
      _enqueue(() async {
        _values[key] = value;
        await _persist();
      });

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    final result = _pending.then((_) => operation());
    _pending = result.then<void>((_) {}, onError: (_, __) {});
    return result;
  }

  Future<void> _persist() async {
    if (_values.isEmpty) {
      if (await _file.exists()) await _file.delete();
      return;
    }
    final temporary = File('${_file.path}.tmp');
    await temporary.writeAsString(jsonEncode(_values), flush: true);
    await _restrictPermissions(temporary);
    await temporary.rename(_file.path);
  }

  static Future<void> _restrictPermissions(File file) async {
    final result = await Process.run('/bin/chmod', ['600', file.path]);
    if (result.exitCode != 0) {
      throw FileSystemException(
          'Unable to restrict credential file permissions', file.path);
    }
  }
}
