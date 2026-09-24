import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kinos/models/account_model.dart';
import 'package:kinos/models/credentials_model.dart';
import 'package:kinos/models/seerr_credentials_model.dart';
import 'package:kinos/providers/shared_provider.dart';
import 'package:kinos/services/seerr_credentials_store.dart';

import '../support/fake_secure_storage_platform.dart';

AccountModel _account({
  required String id,
  required String serverId,
  String name = 'Alice',
  SeerrCredentialsModel? seerrCredentials,
}) =>
    AccountModel(
      name: name,
      id: id,
      avatar: '',
      lastUsed: DateTime(2024, 1, 1),
      credentials: CredentialsModel.internal(serverId: serverId),
      seerrCredentials: seerrCredentials,
    );

const _seerrCreds = SeerrCredentialsModel(
  serverUrl: 'https://seerr.example.com',
  apiKey: 'super-secret-api-key',
  sessionCookie: 'connect.sid=super-secret-cookie',
);

/// [FakeSecureStoragePlatform] is shared with [SecureCredentialsStore]
/// (Jellyfin), which unconditionally writes its own `serverId:userId` entry
/// on every `saveAccounts` call - filters that out so assertions here only
/// look at the `seerr:` namespace they're actually about.
Set<String> _seerrVaultKeys(FakeSecureStoragePlatform platform) =>
    platform.values.keys.where((key) => key.startsWith('seerr:')).toSet();

/// Serializes [accounts] exactly as every version of the app before this
/// migration existed would have (Seerr credentials nested inline in
/// plaintext) - i.e. what SharedPreferences looks like right before a user
/// upgrades.
Future<SharedPreferences> _prefsWithLegacyAccounts(List<AccountModel> accounts) async {
  SharedPreferences.setMockInitialValues({
    'loginCredentialsKey': accounts.map((e) => jsonEncode(e.toJson())).toList(),
  });
  return SharedPreferences.getInstance();
}

void main() {
  late FakeSecureStoragePlatform fakePlatform;

  setUp(() {
    fakePlatform = FakeSecureStoragePlatform.install();
  });

  group('SharedHelper Seerr credentials migration', () {
    test('moves plaintext Seerr credentials to secure storage and strips them from SharedPreferences', () async {
      final legacyAccount = _account(id: 'user-1', serverId: 'server-1', seerrCredentials: _seerrCreds);
      final prefs = await _prefsWithLegacyAccounts([legacyAccount]);
      final helper = SharedHelper(sharedPreferences: prefs);

      final accounts = await helper.getAccounts();

      // The caller still gets the real Seerr credentials back...
      expect(accounts, hasLength(1));
      expect(accounts.single.seerrCredentials?.apiKey, 'super-secret-api-key');
      expect(accounts.single.seerrCredentials?.sessionCookie, 'connect.sid=super-secret-cookie');
      expect(accounts.single.seerrCredentials?.serverUrl, 'https://seerr.example.com');

      // ...but the raw SharedPreferences payload no longer holds them
      // anywhere, in any field - not just on the typed model.
      final rawAfter = prefs.getStringList('loginCredentialsKey')!;
      expect(rawAfter.single, isNot(contains('super-secret-api-key')));
      expect(rawAfter.single, isNot(contains('connect.sid=super-secret-cookie')));

      final storedAccount = AccountModel.fromJson(jsonDecode(rawAfter.single));
      expect(storedAccount.seerrCredentials, isNull);

      // The real credentials actually live in the vault now, under the
      // seerr:server:user composite key - disjoint from the Jellyfin
      // credentials namespace.
      expect(_seerrVaultKeys(fakePlatform), {'seerr:server-1:user-1'});
    });

    test('accounts without Seerr configured are left untouched', () async {
      final legacyAccount = _account(id: 'user-1', serverId: 'server-1');
      final prefs = await _prefsWithLegacyAccounts([legacyAccount]);
      final helper = SharedHelper(sharedPreferences: prefs);

      final accounts = await helper.getAccounts();

      expect(accounts.single.seerrCredentials, isNull);
      expect(_seerrVaultKeys(fakePlatform), isEmpty);
      expect(prefs.getBool('seerrCredentialsMigratedToSecureStorageKey'), isTrue);
    });

    test('a vault write failure loses nothing and erases nothing', () async {
      fakePlatform.failWrites = true;
      final legacyAccount = _account(id: 'user-1', serverId: 'server-1', seerrCredentials: _seerrCreds);
      final prefs = await _prefsWithLegacyAccounts([legacyAccount]);
      final helper = SharedHelper(sharedPreferences: prefs);

      final accounts = await helper.getAccounts();

      // Nothing made it to the vault...
      expect(fakePlatform.values, isEmpty);
      // ...but the caller still sees the real credentials, and they're
      // still sitting in SharedPreferences in plaintext rather than lost -
      // recoverable on the next launch once the vault is back.
      expect(accounts.single.seerrCredentials?.apiKey, 'super-secret-api-key');
      final rawAfter = prefs.getStringList('loginCredentialsKey')!;
      expect(rawAfter.single, contains('super-secret-api-key'));
      // Never marked done, so it retries instead of stranding plaintext.
      expect(prefs.getBool('seerrCredentialsMigratedToSecureStorageKey'), isNot(isTrue));
    });

    test('retrying after a failure succeeds once the vault is available again', () async {
      fakePlatform.failWrites = true;
      final legacyAccount = _account(id: 'user-1', serverId: 'server-1', seerrCredentials: _seerrCreds);
      final prefs = await _prefsWithLegacyAccounts([legacyAccount]);
      final helper = SharedHelper(sharedPreferences: prefs);

      await helper.getAccounts();
      expect(fakePlatform.values, isEmpty);

      fakePlatform.failWrites = false;
      // A fresh SharedHelper instance, exactly like a new app launch would
      // create - `_seerrMigrationChecked` never survives past one instance.
      final retriedHelper = SharedHelper(sharedPreferences: prefs);
      final accounts = await retriedHelper.getAccounts();

      expect(_seerrVaultKeys(fakePlatform), {'seerr:server-1:user-1'});
      expect(accounts.single.seerrCredentials?.apiKey, 'super-secret-api-key');
      final rawAfter = prefs.getStringList('loginCredentialsKey')!;
      expect(rawAfter.single, isNot(contains('super-secret-api-key')));
    });

    test('running the migration twice is idempotent', () async {
      final legacyAccount = _account(id: 'user-1', serverId: 'server-1', seerrCredentials: _seerrCreds);
      final prefs = await _prefsWithLegacyAccounts([legacyAccount]);
      final helper = SharedHelper(sharedPreferences: prefs);

      final firstRun = await helper.getAccounts();
      final secondRun = await helper.getAccounts();

      expect(_seerrVaultKeys(fakePlatform), {'seerr:server-1:user-1'});
      expect(firstRun.single.seerrCredentials?.apiKey, secondRun.single.seerrCredentials?.apiKey);
      expect(secondRun.single.seerrCredentials?.apiKey, 'super-secret-api-key');
    });

    test('two profiles on the same server keep independent Seerr credentials (isolation)', () async {
      final userOne = _account(
        id: 'user-1',
        serverId: 'server-1',
        seerrCredentials: _seerrCreds.copyWith(apiKey: 'key-for-user-1'),
      );
      final userTwo = _account(
        id: 'user-2',
        serverId: 'server-1',
        seerrCredentials: _seerrCreds.copyWith(apiKey: 'key-for-user-2'),
      );
      final prefs = await _prefsWithLegacyAccounts([userOne, userTwo]);
      final helper = SharedHelper(sharedPreferences: prefs);

      final accounts = await helper.getAccounts();

      final keysById = {for (final a in accounts) a.id: a.seerrCredentials?.apiKey};
      expect(keysById, {'user-1': 'key-for-user-1', 'user-2': 'key-for-user-2'});
      expect(_seerrVaultKeys(fakePlatform), {'seerr:server-1:user-1', 'seerr:server-1:user-2'});

      // Neither profile's credentials are reachable under the other's key.
      const store = SeerrCredentialsStore();
      final crossRead = await store.read('server-1', 'user-1');
      expect(crossRead?.apiKey, 'key-for-user-1');
      expect(crossRead?.apiKey, isNot('key-for-user-2'));
    });
  });

  group('SharedHelper (post-migration Seerr behavior, no legacy data)', () {
    late SharedHelper helper;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      helper = SharedHelper(sharedPreferences: await SharedPreferences.getInstance());
    });

    test('saveAccounts writes Seerr credentials to secure storage, never to SharedPreferences', () async {
      await helper.addAccount(_account(id: 'user-1', serverId: 'server-1', seerrCredentials: _seerrCreds));

      final accounts = await helper.getAccounts();
      expect(accounts.single.seerrCredentials?.apiKey, 'super-secret-api-key');
      expect(_seerrVaultKeys(fakePlatform), {'seerr:server-1:user-1'});

      final raw = SharedPreferences.getInstance();
      final prefs = await raw;
      final rawAfter = prefs.getStringList('loginCredentialsKey')!;
      expect(rawAfter.single, isNot(contains('super-secret-api-key')));
    });

    test('saving an account with no Seerr configured writes nothing to the vault', () async {
      await helper.addAccount(_account(id: 'user-1', serverId: 'server-1'));

      expect(_seerrVaultKeys(fakePlatform), isEmpty);
    });

    test('changing Seerr credentials replaces the vault entry', () async {
      // `addAccount` deliberately merges only `credentials`/`lastUsed` on an
      // existing identity (pre-existing behavior, out of scope here) - real
      // Seerr credential edits go through `UserNotifier`'s setters
      // (`setSeerrApiKey`/`logoutSeerr`/...), which persist via
      // `updateAccountInfo` instead. Mirrored here directly, without
      // depending on the `userProvider` notifier.
      await helper.addAccount(_account(id: 'user-1', serverId: 'server-1', seerrCredentials: _seerrCreds));
      expect(_seerrVaultKeys(fakePlatform), {'seerr:server-1:user-1'});

      await helper.updateAccountInfo(_account(
        id: 'user-1',
        serverId: 'server-1',
        seerrCredentials: _seerrCreds.copyWith(apiKey: 'rotated-key'),
      ));

      final accounts = await helper.getAccounts();
      expect(accounts.single.seerrCredentials?.apiKey, 'rotated-key');
      expect(_seerrVaultKeys(fakePlatform), {'seerr:server-1:user-1'});
    });

    test('disconnecting Seerr (credentials no longer configured) deletes the vault entry', () async {
      await helper.addAccount(_account(id: 'user-1', serverId: 'server-1', seerrCredentials: _seerrCreds));
      expect(_seerrVaultKeys(fakePlatform), isNotEmpty);

      // Mirrors `UserNotifier.logoutSeerr()`: clears apiKey/sessionCookie
      // but keeps serverUrl, which is exactly what `isConfigured` is for.
      // Persisted via `updateAccountInfo`, same as the real setter - see the
      // comment on the test above.
      await helper.updateAccountInfo(_account(
        id: 'user-1',
        serverId: 'server-1',
        seerrCredentials: _seerrCreds.copyWith(apiKey: '', sessionCookie: ''),
      ));

      expect(_seerrVaultKeys(fakePlatform), isEmpty);
    });

    test('removeAccount deletes the Seerr vault entry, not just the Jellyfin one', () async {
      await helper.addAccount(_account(id: 'user-1', serverId: 'server-1', seerrCredentials: _seerrCreds));
      expect(fakePlatform.values, isNotEmpty);

      await helper.removeAccount(_account(id: 'user-1', serverId: 'server-1'));

      expect(await helper.getAccounts(), isEmpty);
      expect(fakePlatform.values, isEmpty);
    });
  });

  group('SeerrCredentialsModel', () {
    test('toString never prints the real apiKey or sessionCookie', () {
      final text = _seerrCreds.toString();
      expect(text, isNot(contains('super-secret-api-key')));
      expect(text, isNot(contains('connect.sid=super-secret-cookie')));
      expect(text, contains('serverUrl: https://seerr.example.com'));
    });

    test('toString on empty credentials mentions nothing redacted', () {
      const empty = SeerrCredentialsModel();
      expect(empty.toString(), isNot(contains('<redacted>')));
    });
  });
}
