import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/anilist/anilist_account.dart';
import 'package:kinos/arr/models/arr_service.dart';
import 'package:kinos/arr/services/arr_credentials_store.dart';
import 'package:kinos/arr/services/qbittorrent_credentials_store.dart';
import 'package:kinos/services/secure_credentials_store.dart';
import 'package:kinos/services/seerr_credentials_store.dart';
import 'package:kinos/services/platform_secure_storage.dart';

import '../support/fake_secure_storage_platform.dart';

class _RecordingVault extends FakeSecureStoragePlatform {
  final optionsLog = <Map<String, String>>[];

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async {
    optionsLog.add(options);
    return super.read(key: key, options: options);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('macOS persists credentials in a private local file across app restarts',
      () async {
    final original = FlutterSecureStoragePlatform.instance;
    final directory =
        await Directory.systemTemp.createTemp('kinos-macos-storage-test');
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() async {
      debugDefaultTargetPlatformOverride = null;
      FlutterSecureStoragePlatform.instance = original;
      await directory.delete(recursive: true);
    });

    await configurePlatformSecureStorage(storageDirectory: directory);
    const storage = FlutterSecureStorage();
    await storage.write(key: 'token', value: 'secret');
    await storage.write(key: 'token', value: 'rotated-secret');

    FlutterSecureStoragePlatform.instance = original;
    await configurePlatformSecureStorage(storageDirectory: directory);

    expect(await storage.read(key: 'token'), 'rotated-secret');
    expect(
        (await File('${directory.path}/credentials.json').stat()).mode & 0x1ff,
        0x180);
  });

  test('macOS deletes local credentials permanently', () async {
    final original = FlutterSecureStoragePlatform.instance;
    final directory =
        await Directory.systemTemp.createTemp('kinos-macos-storage-test');
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() async {
      debugDefaultTargetPlatformOverride = null;
      FlutterSecureStoragePlatform.instance = original;
      await directory.delete(recursive: true);
    });

    await configurePlatformSecureStorage(storageDirectory: directory);
    const storage = FlutterSecureStorage();
    await storage.write(key: 'token', value: 'secret');
    await storage.delete(key: 'token');

    FlutterSecureStoragePlatform.instance = original;
    await configurePlatformSecureStorage(storageDirectory: directory);

    expect(await storage.read(key: 'token'), isNull);
    expect(await File('${directory.path}/credentials.json').exists(), isFalse);
  });

  test('macOS ignores malformed local credential entries', () async {
    final original = FlutterSecureStoragePlatform.instance;
    final directory =
        await Directory.systemTemp.createTemp('kinos-macos-storage-test');
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() async {
      debugDefaultTargetPlatformOverride = null;
      FlutterSecureStoragePlatform.instance = original;
      await directory.delete(recursive: true);
    });
    await File('${directory.path}/credentials.json')
        .writeAsString('{"token":42}');

    await configurePlatformSecureStorage(storageDirectory: directory);

    expect(await const FlutterSecureStorage().read(key: 'token'), isNull);
  });

  for (final platform in [
    TargetPlatform.macOS,
    TargetPlatform.windows,
    TargetPlatform.linux,
  ]) {
    test('all credential stores use the supported vault on $platform',
        () async {
      final original = FlutterSecureStoragePlatform.instance;
      final vault = _RecordingVault();
      FlutterSecureStoragePlatform.instance = vault;
      debugDefaultTargetPlatformOverride = platform;
      try {
        await const SecureCredentialsStore().read('server', 'user');
        await const SeerrCredentialsStore().read('server', 'user');
        await const ArrCredentialsStore().read(ArrService.radarr);
        await const QBittorrentCredentialsStore().read();
        await const AnilistAccountStore().read('profile');
        expect(vault.optionsLog, hasLength(5));
        for (final options in vault.optionsLog) {
          if (platform == TargetPlatform.macOS) {
            expect(options['usesDataProtectionKeychain'], 'false',
                reason: 'Ad hoc apps must use the macOS login Keychain');
          } else {
            const defaults = FlutterSecureStorage();
            expect(
                options,
                platform == TargetPlatform.windows
                    ? defaults.wOptions.params
                    : defaults.lOptions.params);
          }
        }
      } finally {
        debugDefaultTargetPlatformOverride = null;
        FlutterSecureStoragePlatform.instance = original;
      }
    });
  }
}
