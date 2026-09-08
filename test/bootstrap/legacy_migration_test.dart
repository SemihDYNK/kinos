import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kinos/bootstrap/legacy_migration.dart';

import '../support/fake_secure_storage_platform.dart';

void main() {
  group('migrateLegacyDataDirectory', () {
    late Directory tempRoot;

    setUp(() async {
      tempRoot = await Directory.systemTemp.createTemp('kinos_migration_test_');
    });

    tearDown(() async {
      if (await tempRoot.exists()) await tempRoot.delete(recursive: true);
    });

    test('moves the legacy directory contents to the new one', () async {
      final oldDir = Directory('${tempRoot.path}/$legacyApplicationId');
      await oldDir.create(recursive: true);
      await File('${oldDir.path}/app.db').writeAsString('fake sqlite bytes');
      await Directory('${oldDir.path}/sub').create();
      await File('${oldDir.path}/sub/nested.txt').writeAsString('nested');

      await migrateLegacyDataDirectory(dataHomeOverride: tempRoot.path);

      final newDir = Directory('${tempRoot.path}/$applicationId');
      expect(await newDir.exists(), isTrue);
      expect(await File('${newDir.path}/app.db').readAsString(),
          'fake sqlite bytes');
      expect(
          await File('${newDir.path}/sub/nested.txt').readAsString(), 'nested');
      // L'original a bien été déplacé, pas dupliqué.
      expect(await oldDir.exists(), isFalse);
    });

    test('no legacy directory — no-op, nothing created', () async {
      await migrateLegacyDataDirectory(dataHomeOverride: tempRoot.path);

      final newDir = Directory('${tempRoot.path}/$applicationId');
      expect(await newDir.exists(), isFalse);
    });

    test('the new directory already exists — never overwritten', () async {
      final oldDir = Directory('${tempRoot.path}/$legacyApplicationId');
      await oldDir.create(recursive: true);
      await File('${oldDir.path}/app.db').writeAsString('legacy bytes');

      final newDir = Directory('${tempRoot.path}/$applicationId');
      await newDir.create(recursive: true);
      await File('${newDir.path}/app.db').writeAsString('already current');

      await migrateLegacyDataDirectory(dataHomeOverride: tempRoot.path);

      expect(await File('${newDir.path}/app.db').readAsString(),
          'already current');
      // L'ancien dossier reste intact — pas de perte si la migration ne
      // s'applique pas.
      expect(await oldDir.exists(), isTrue);
    });

    test('resolves \$XDG_DATA_HOME when no override is passed', () async {
      final oldDir = Directory('${tempRoot.path}/$legacyApplicationId');
      await oldDir.create(recursive: true);
      await File('${oldDir.path}/marker').writeAsString('x');

      await migrateLegacyDataDirectory(
          environment: {'XDG_DATA_HOME': tempRoot.path});

      expect(await File('${tempRoot.path}/$applicationId/marker').exists(),
          isTrue);
    });
  });

  group('migrateLegacySecureStorage', () {
    late FakeSecureStoragePlatform fakePlatform;

    setUp(() {
      fakePlatform = FakeSecureStoragePlatform.install();
    });

    test(
        'new storage already has data — never overwritten, secret-tool not called',
        () async {
      const storage = FlutterSecureStorage();
      await storage.write(key: 'already-here', value: 'v');
      var called = false;

      await migrateLegacySecureStorage(
        storage: storage,
        runProcess: (exe, args) async {
          called = true;
          return ProcessResult(0, 0, '', '');
        },
      );

      expect(called, isFalse);
    });

    test('secret-tool absent (throws) — silent no-op', () async {
      const storage = FlutterSecureStorage();

      await migrateLegacySecureStorage(
        storage: storage,
        runProcess: (exe, args) =>
            throw ProcessException(exe, args, 'not found'),
      );

      expect(fakePlatform.values, isEmpty);
    });

    test('secret-tool exits non-zero (locked keyring, nothing found) — no-op',
        () async {
      const storage = FlutterSecureStorage();

      await migrateLegacySecureStorage(
        storage: storage,
        runProcess: (exe, args) async =>
            ProcessResult(0, 1, '', 'no such object'),
      );

      expect(fakePlatform.values, isEmpty);
    });

    test('blob is not valid JSON — no-op, does not throw', () async {
      const storage = FlutterSecureStorage();

      await migrateLegacySecureStorage(
        storage: storage,
        runProcess: (exe, args) async =>
            ProcessResult(0, 0, 'not json at all', ''),
      );

      expect(fakePlatform.values, isEmpty);
    });

    test('valid blob — every key replayed through the normal write path',
        () async {
      const storage = FlutterSecureStorage();
      final blob = jsonEncode({
        'server-1:user-1': '{"token":"abc"}',
        'arr:radarr': '{"apiKey":"def"}',
      });

      await migrateLegacySecureStorage(
        storage: storage,
        runProcess: (exe, args) async {
          expect(exe, 'secret-tool');
          expect(args, ['lookup', 'account', legacySecureStorageAccount]);
          return ProcessResult(0, 0, blob, '');
        },
      );

      expect(fakePlatform.values, {
        'server-1:user-1': '{"token":"abc"}',
        'arr:radarr': '{"apiKey":"def"}',
      });
    });
  });
}
