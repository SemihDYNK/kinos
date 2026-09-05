import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fladder/models/account_model.dart';
import 'package:fladder/models/credentials_model.dart';
import 'package:fladder/providers/shared_provider.dart';
import 'package:fladder/services/secure_credentials_store.dart';

import '../support/fake_secure_storage_platform.dart';

AccountModel _account({
  required String id,
  required String serverId,
  String name = 'Alice',
  String token = 'super-secret-token',
  String url = 'https://jellyfin.example.com',
  String? localUrl = 'http://192.168.1.10:8096',
  String deviceId = 'device-1',
  DateTime? lastUsed,
}) =>
    AccountModel(
      name: name,
      id: id,
      avatar: '',
      lastUsed: lastUsed ?? DateTime(2024, 1, 1),
      credentials: CredentialsModel.internal(
        token: token,
        url: url,
        localUrl: localUrl,
        serverName: 'Home Server',
        serverId: serverId,
        deviceId: deviceId,
      ),
    );

/// Serializes [accounts] exactly as every version of the app before this
/// migration existed would have (full plaintext credentials nested inline) -
/// i.e. what SharedPreferences looks like right before a user upgrades.
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

  group('SharedHelper credentials migration', () {
    test('moves plaintext credentials to secure storage and strips them from SharedPreferences', () async {
      final legacyAccount = _account(id: 'user-1', serverId: 'server-1');
      final prefs = await _prefsWithLegacyAccounts([legacyAccount]);
      final helper = SharedHelper(sharedPreferences: prefs);

      final accounts = await helper.getAccounts();

      // The caller still gets the real credentials back...
      expect(accounts, hasLength(1));
      expect(accounts.single.credentials.token, 'super-secret-token');
      expect(accounts.single.credentials.url, 'https://jellyfin.example.com');
      expect(accounts.single.credentials.localUrl, 'http://192.168.1.10:8096');
      expect(accounts.single.credentials.deviceId, 'device-1');

      // ...but SharedPreferences no longer holds them in plaintext.
      final rawAfter = prefs.getStringList('loginCredentialsKey')!;
      final storedAccount = AccountModel.fromJson(jsonDecode(rawAfter.single));
      expect(storedAccount.credentials.token, isEmpty);
      expect(storedAccount.credentials.url, isEmpty);
      expect(storedAccount.credentials.localUrl, isNull);
      expect(storedAccount.credentials.deviceId, isEmpty);
      // serverId survives in plaintext: it's half of the lookup key needed
      // to find the real credentials back in secure storage.
      expect(storedAccount.credentials.serverId, 'server-1');

      // The real credentials actually live in the vault now, under the
      // server:user composite key.
      expect(fakePlatform.values.keys, ['server-1:user-1']);
    });

    test('marks migration done so a second read does not re-run it', () async {
      final prefs = await _prefsWithLegacyAccounts([_account(id: 'user-1', serverId: 'server-1')]);
      final helper = SharedHelper(sharedPreferences: prefs);

      await helper.getAccounts();
      expect(prefs.getBool('credentialsMigratedToSecureStorageKey'), isTrue);

      // Tamper with the vault entry directly, bypassing the store, the way
      // nothing in the app is expected to do - if getAccounts() re-ran the
      // migration, it would overwrite this with the now-blank
      // SharedPreferences placeholder instead of leaving it alone.
      const store = SecureCredentialsStore();
      await store.save(
        'server-1',
        'user-1',
        CredentialsModel.internal(token: 'rotated-token', serverId: 'server-1'),
      );

      final accounts = await helper.getAccounts();
      expect(accounts.single.credentials.token, 'rotated-token');
    });

    test('an empty account list is marked migrated without touching secure storage', () async {
      final prefs = await _prefsWithLegacyAccounts([]);
      final helper = SharedHelper(sharedPreferences: prefs);

      final accounts = await helper.getAccounts();

      expect(accounts, isEmpty);
      expect(prefs.getBool('credentialsMigratedToSecureStorageKey'), isTrue);
      expect(fakePlatform.values, isEmpty);
    });

    test('multiple accounts migrate independently under their own composite key (multi-profile)', () async {
      final onServerA = _account(id: 'user-1', serverId: 'server-a', token: 'token-a');
      final onServerB = _account(id: 'user-1', serverId: 'server-b', token: 'token-b');
      final prefs = await _prefsWithLegacyAccounts([onServerA, onServerB]);
      final helper = SharedHelper(sharedPreferences: prefs);

      final accounts = await helper.getAccounts();

      final tokensByServer = {for (final a in accounts) a.credentials.serverId: a.credentials.token};
      expect(tokensByServer, {'server-a': 'token-a', 'server-b': 'token-b'});
      expect(fakePlatform.values.keys.toSet(), {'server-a:user-1', 'server-b:user-1'});
    });
  });

  group('SharedHelper (post-migration behavior, no legacy data)', () {
    late SharedHelper helper;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      helper = SharedHelper(sharedPreferences: await SharedPreferences.getInstance());
    });

    test('addAccount writes credentials to secure storage, not SharedPreferences', () async {
      await helper.addAccount(_account(id: 'user-1', serverId: 'server-1', token: 'fresh-token'));

      final accounts = await helper.getAccounts();
      expect(accounts.single.credentials.token, 'fresh-token');
      expect(fakePlatform.values.keys, ['server-1:user-1']);
    });

    test('removeAccount deletes the vault entry, not just the SharedPreferences row', () async {
      await helper.addAccount(_account(id: 'user-1', serverId: 'server-1'));
      expect(fakePlatform.values, isNotEmpty);

      await helper.removeAccount(_account(id: 'user-1', serverId: 'server-1'));

      expect(await helper.getAccounts(), isEmpty);
      expect(fakePlatform.values, isEmpty);
    });

    test('getActiveAccount returns the most recently used auto-login account, fully hydrated', () async {
      await helper.addAccount(_account(
        id: 'user-1',
        serverId: 'server-1',
        token: 'older',
        lastUsed: DateTime(2024, 1, 1),
      ));
      await helper.addAccount(_account(
        id: 'user-2',
        serverId: 'server-1',
        token: 'newer',
        lastUsed: DateTime(2024, 6, 1),
      ));

      final active = await helper.getActiveAccount();
      expect(active?.id, 'user-2');
      expect(active?.credentials.token, 'newer');
    });
  });
}
