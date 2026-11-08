import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kinos/models/account_model.dart';
import 'package:kinos/models/credentials_model.dart';
import 'package:kinos/models/seerr_credentials_model.dart';
import 'package:kinos/providers/shared_provider.dart';
import 'package:kinos/services/secure_credentials_store.dart';
import 'package:kinos/services/seerr_credentials_store.dart';
import 'package:kinos/services/platform_secure_storage.dart';

import '../support/fake_secure_storage_platform.dart';

/// [FlutterSecureStoragePlatform] whose `read` throws for a chosen set of
/// keys - simulates a locked/absent Linux keyring for specific entries
/// (rather than the whole backend), so one account's degraded hydration can
/// be exercised without also breaking every other account/store sharing the
/// same [FakeSecureStoragePlatform].
class _ReadFailingSecureStoragePlatform extends FakeSecureStoragePlatform {
  final Set<String> failingKeys;
  _ReadFailingSecureStoragePlatform(this.failingKeys);

  static _ReadFailingSecureStoragePlatform install(Set<String> failingKeys) {
    final fake = _ReadFailingSecureStoragePlatform(failingKeys);
    FlutterSecureStoragePlatform.instance = fake;
    return fake;
  }

  @override
  Future<String?> read(
      {required String key, required Map<String, String> options}) async {
    if (failingKeys.contains(key)) {
      throw PlatformException(code: 'locked', message: 'Keyring is locked');
    }
    return super.read(key: key, options: options);
  }
}

AccountModel _account({
  required String id,
  required String serverId,
  String token = 'super-secret-token',
  SeerrCredentialsModel? seerrCredentials,
}) =>
    AccountModel(
      name: 'Alice',
      id: id,
      avatar: '',
      lastUsed: DateTime(2024, 1, 1),
      credentials: CredentialsModel.internal(token: token, serverId: serverId),
      seerrCredentials: seerrCredentials,
    );

const _seerrCreds = SeerrCredentialsModel(
  serverUrl: 'https://seerr.example.com',
  apiKey: 'super-secret-api-key',
);

void main() {
  group('degraded vault reads', () {
    test(
        'macOS session storage does not restore an account without its expired session token',
        () async {
      final previousPlatform = FlutterSecureStoragePlatform.instance;
      final previousTarget = debugDefaultTargetPlatformOverride;
      addTearDown(() {
        FlutterSecureStoragePlatform.instance = previousPlatform;
        debugDefaultTargetPlatformOverride = previousTarget;
      });
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      configurePlatformSecureStorage();

      SharedPreferences.setMockInitialValues({
        'loginCredentialsKey': [
          jsonEncode(
              _account(id: 'user-1', serverId: 'server-1', token: '').toJson())
        ],
        'credentialsMigratedToSecureStorageKey': true,
        'seerrCredentialsMigratedToSecureStorageKey': true,
      });
      final helper = SharedHelper(
          sharedPreferences: await SharedPreferences.getInstance());

      expect(await helper.getAccounts(), isEmpty);
    });

    test('a read failure for one account never empties the whole list',
        () async {
      final failing =
          _ReadFailingSecureStoragePlatform.install({'server-1:user-1'});
      const jellyfinStore = SecureCredentialsStore();

      // user-2's Jellyfin credentials are readable; user-1's read() throws.
      await jellyfinStore.save('server-1', 'user-2',
          CredentialsModel.internal(token: 'ok', serverId: 'server-1'));

      SharedPreferences.setMockInitialValues({
        'loginCredentialsKey': [
          jsonEncode(
              _account(id: 'user-1', serverId: 'server-1', token: '').toJson()),
          jsonEncode(
              _account(id: 'user-2', serverId: 'server-1', token: '').toJson()),
        ],
        'credentialsMigratedToSecureStorageKey': true,
        'seerrCredentialsMigratedToSecureStorageKey': true,
      });
      final helper = SharedHelper(
          sharedPreferences: await SharedPreferences.getInstance());

      final accounts = await helper.getAccounts();

      expect(accounts, hasLength(2));
      final byId = {for (final a in accounts) a.id: a};
      // user-1 stays in the list, just without its real token.
      expect(byId['user-1']!.credentials.token, isEmpty);
      // user-2 hydrated normally.
      expect(byId['user-2']!.credentials.token, 'ok');
      expect(failing.failingKeys, contains('server-1:user-1'));
    });

    test(
        'a Seerr read failure does not block the Jellyfin read for the same account',
        () async {
      _ReadFailingSecureStoragePlatform.install({'seerr:server-1:user-1'});
      const jellyfinStore = SecureCredentialsStore();
      await jellyfinStore.save(
          'server-1',
          'user-1',
          CredentialsModel.internal(
              token: 'jellyfin-ok', serverId: 'server-1'));

      SharedPreferences.setMockInitialValues({
        'loginCredentialsKey': [
          jsonEncode(
              _account(id: 'user-1', serverId: 'server-1', token: '').toJson())
        ],
        'credentialsMigratedToSecureStorageKey': true,
        'seerrCredentialsMigratedToSecureStorageKey': true,
      });
      final helper = SharedHelper(
          sharedPreferences: await SharedPreferences.getInstance());

      final accounts = await helper.getAccounts();

      expect(accounts.single.credentials.token, 'jellyfin-ok');
      expect(accounts.single.seerrCredentials, isNull);
    });

    // No test asserts on the logged message itself: `dart:developer.log()`
    // doesn't route through `print`/a `Zone` override in `flutter test`, so
    // any capture attempt would be a no-op dressed up as a test. The
    // guarantee ("no secret in the message") is verified by inspection
    // instead - `_hydrateAccount` (shared_provider.dart) only ever
    // interpolates the account's non-secret composite `key`, the caught
    // exception `e`, and `stacktrace` into its log lines; `storedCredentials`
    // and `storedSeerrCredentials` (the only values that could contain a
    // secret) are never formatted into a string anywhere in that method.
  });

  group('degraded accounts are never written to the vault', () {
    test(
        'saveAccounts on a degraded account touches neither store, only SharedPreferences',
        () async {
      final failing =
          _ReadFailingSecureStoragePlatform.install({'server-1:user-1'});
      SharedPreferences.setMockInitialValues({
        'loginCredentialsKey': [
          jsonEncode(
              _account(id: 'user-1', serverId: 'server-1', token: '').toJson())
        ],
        'credentialsMigratedToSecureStorageKey': true,
        'seerrCredentialsMigratedToSecureStorageKey': true,
      });
      final helper = SharedHelper(
          sharedPreferences: await SharedPreferences.getInstance());

      final degraded = await helper.getAccounts();
      expect(degraded.single.credentials.token,
          isEmpty); // confirms it's actually degraded

      // A routine update (e.g. `updateAccountInfo` touching `lastUsed`)
      // must not go anywhere near the vault for this account.
      await helper.saveAccounts(degraded);

      expect(failing.values.keys, isEmpty);
    });

    test(
        'a pre-existing Jellyfin vault entry survives saveAccounts on a degraded account',
        () async {
      final failing =
          _ReadFailingSecureStoragePlatform.install({'server-1:user-1'});
      const jellyfinStore = SecureCredentialsStore();
      await jellyfinStore.save(
        'server-1',
        'user-1',
        CredentialsModel.internal(
            token: 'the-real-token', serverId: 'server-1'),
      );
      final before = Map.of(failing.values);

      SharedPreferences.setMockInitialValues({
        'loginCredentialsKey': [
          jsonEncode(
              _account(id: 'user-1', serverId: 'server-1', token: '').toJson())
        ],
        'credentialsMigratedToSecureStorageKey': true,
        'seerrCredentialsMigratedToSecureStorageKey': true,
      });
      final helper = SharedHelper(
          sharedPreferences: await SharedPreferences.getInstance());

      final degraded = await helper.getAccounts();
      await helper.saveAccounts(degraded);

      // Untouched: not overwritten by the placeholder, not deleted.
      expect(failing.values, before);
    });

    test(
        'a pre-existing Seerr vault entry survives saveAccounts when only Seerr failed to read',
        () async {
      final failing =
          _ReadFailingSecureStoragePlatform.install({'seerr:server-1:user-1'});
      const seerrStore = SeerrCredentialsStore();
      await seerrStore.save('server-1', 'user-1', _seerrCreds);
      final before = Map.of(failing.values);

      SharedPreferences.setMockInitialValues({
        'loginCredentialsKey': [
          jsonEncode(
              _account(id: 'user-1', serverId: 'server-1', token: '').toJson())
        ],
        'credentialsMigratedToSecureStorageKey': true,
        'seerrCredentialsMigratedToSecureStorageKey': true,
      });
      final helper = SharedHelper(
          sharedPreferences: await SharedPreferences.getInstance());

      final degraded = await helper.getAccounts();
      await helper.saveAccounts(degraded);

      expect(failing.values, before);
    });

    test(
        'the account heals on the next successful getAccounts, and saveAccounts resumes writing it',
        () async {
      final failing =
          _ReadFailingSecureStoragePlatform.install({'server-1:user-1'});
      const jellyfinStore = SecureCredentialsStore();
      await jellyfinStore.save('server-1', 'user-1',
          CredentialsModel.internal(token: 'real-token', serverId: 'server-1'));

      SharedPreferences.setMockInitialValues({
        'loginCredentialsKey': [
          jsonEncode(
              _account(id: 'user-1', serverId: 'server-1', token: '').toJson())
        ],
        'credentialsMigratedToSecureStorageKey': true,
        'seerrCredentialsMigratedToSecureStorageKey': true,
      });
      final helper = SharedHelper(
          sharedPreferences: await SharedPreferences.getInstance());

      final degraded = await helper.getAccounts();
      expect(degraded.single.credentials.token, isEmpty);

      // The vault "comes back".
      failing.failingKeys.clear();
      final healed = await helper.getAccounts();
      expect(healed.single.credentials.token, 'real-token');

      // Now a save for this account writes normally again.
      await helper.saveAccounts(healed
          .map((e) =>
              e.copyWith(credentials: e.credentials.copyWith(token: 'rotated')))
          .toList());
      final rehydrated = await jellyfinStore.read('server-1', 'user-1');
      expect(rehydrated?.token, 'rotated');
    });
  });

  group('removeAccount always clears both vault entries, degraded or not', () {
    test(
        'removeAccount deletes the Jellyfin and Seerr entries even for a degraded account',
        () async {
      final failing =
          _ReadFailingSecureStoragePlatform.install({'server-1:user-1'});
      const jellyfinStore = SecureCredentialsStore();
      const seerrStore = SeerrCredentialsStore();
      await jellyfinStore.save('server-1', 'user-1',
          CredentialsModel.internal(token: 'x', serverId: 'server-1'));
      await seerrStore.save('server-1', 'user-1', _seerrCreds);

      SharedPreferences.setMockInitialValues({
        'loginCredentialsKey': [
          jsonEncode(
              _account(id: 'user-1', serverId: 'server-1', token: '').toJson())
        ],
        'credentialsMigratedToSecureStorageKey': true,
        'seerrCredentialsMigratedToSecureStorageKey': true,
      });
      final helper = SharedHelper(
          sharedPreferences: await SharedPreferences.getInstance());
      await helper.getAccounts(); // marks it degraded

      await helper.removeAccount(_account(id: 'user-1', serverId: 'server-1'));

      expect(failing.values, isEmpty);
      expect(await helper.getAccounts(), isEmpty);
    });
  });
}
