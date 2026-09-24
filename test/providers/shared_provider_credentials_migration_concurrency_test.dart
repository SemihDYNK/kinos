import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kinos/models/account_model.dart';
import 'package:kinos/models/credentials_model.dart';
import 'package:kinos/models/seerr_credentials_model.dart';
import 'package:kinos/providers/shared_provider.dart';

import '../support/fake_secure_storage_platform.dart';

AccountModel _account({
  required String id,
  required String serverId,
  String name = 'Alice',
  String token = 'super-secret-token',
  SeerrCredentialsModel? seerrCredentials,
}) =>
    AccountModel(
      name: name,
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

  group('concurrent getAccounts() calls at startup', () {
    test('two concurrent calls run the Jellyfin migration only once', () async {
      final legacyAccount = _account(id: 'user-1', serverId: 'server-1');
      final prefs = await _prefsWithLegacyAccounts([legacyAccount]);
      final helper = SharedHelper(sharedPreferences: prefs);

      final results = await Future.wait([helper.getAccounts(), helper.getAccounts()]);

      // Both callers see the real credentials...
      expect(results[0].single.credentials.token, 'super-secret-token');
      expect(results[1].single.credentials.token, 'super-secret-token');
      // ...but the vault was only written to once, not twice - an
      // un-memoized migration would run the whole read-modify-write pass
      // for each concurrent call.
      expect(fakePlatform.writeLog.where((k) => k == 'server-1:user-1'), hasLength(1));
    });

    test('two concurrent calls run the Seerr migration only once', () async {
      final legacyAccount = _account(id: 'user-1', serverId: 'server-1', seerrCredentials: _seerrCreds);
      final prefs = await _prefsWithLegacyAccounts([legacyAccount]);
      final helper = SharedHelper(sharedPreferences: prefs);

      final results = await Future.wait([helper.getAccounts(), helper.getAccounts()]);

      expect(results[0].single.seerrCredentials?.apiKey, 'super-secret-api-key');
      expect(results[1].single.seerrCredentials?.apiKey, 'super-secret-api-key');
      expect(fakePlatform.writeLog.where((k) => k == 'seerr:server-1:user-1'), hasLength(1));
    });

    test('an account added concurrently with the initial migration is not lost', () async {
      final legacyAccount = _account(id: 'user-1', serverId: 'server-1');
      final prefs = await _prefsWithLegacyAccounts([legacyAccount]);
      final helper = SharedHelper(sharedPreferences: prefs);

      // `addAccount` itself calls `getAccounts()` first (awaiting the same
      // memoized migration future as the direct `getAccounts()` call
      // below), so its `saveAccounts` write can only land after migration
      // has fully finished writing its own conclusions - never racing it.
      await Future.wait([
        helper.getAccounts(),
        helper.addAccount(_account(id: 'user-2', serverId: 'server-1', token: 'fresh-token')),
      ]);

      final accounts = await helper.getAccounts();
      final ids = accounts.map((a) => a.id).toSet();
      expect(ids, {'user-1', 'user-2'});
      expect(accounts.firstWhere((a) => a.id == 'user-1').credentials.token, 'super-secret-token');
      expect(accounts.firstWhere((a) => a.id == 'user-2').credentials.token, 'fresh-token');
    });
  });

  group('a durably failing vault is only attempted once per session', () {
    test('Jellyfin migration: three sequential getAccounts() calls, one write attempt', () async {
      fakePlatform.failWrites = true;
      final legacyAccount = _account(id: 'user-1', serverId: 'server-1');
      final prefs = await _prefsWithLegacyAccounts([legacyAccount]);
      final helper = SharedHelper(sharedPreferences: prefs);

      await helper.getAccounts();
      await helper.getAccounts();
      await helper.getAccounts();

      expect(fakePlatform.writeAttempts, 1);
      // Still never marked done - a real relaunch (fresh SharedHelper)
      // must retry.
      expect(prefs.getBool('credentialsMigratedToSecureStorageKey'), isNot(isTrue));
    });

    test('Seerr migration: three sequential getAccounts() calls, one write attempt', () async {
      fakePlatform.failWrites = true;
      final legacyAccount = _account(id: 'user-1', serverId: 'server-1', seerrCredentials: _seerrCreds);
      final prefs = await _prefsWithLegacyAccounts([legacyAccount]);
      final helper = SharedHelper(sharedPreferences: prefs);

      await helper.getAccounts();
      await helper.getAccounts();
      await helper.getAccounts();

      // One attempt for the Jellyfin store, one for the Seerr store - not
      // three of each.
      expect(fakePlatform.writeAttempts, 2);
      expect(prefs.getBool('seerrCredentialsMigratedToSecureStorageKey'), isNot(isTrue));
    });

    test('a fresh SharedHelper (new launch) retries after a failed session', () async {
      fakePlatform.failWrites = true;
      final legacyAccount = _account(id: 'user-1', serverId: 'server-1');
      final prefs = await _prefsWithLegacyAccounts([legacyAccount]);
      final firstLaunch = SharedHelper(sharedPreferences: prefs);
      await firstLaunch.getAccounts();
      expect(fakePlatform.writeAttempts, 1);

      fakePlatform.failWrites = false;
      final secondLaunch = SharedHelper(sharedPreferences: prefs);
      final accounts = await secondLaunch.getAccounts();

      expect(accounts.single.credentials.token, 'super-secret-token');
      expect(prefs.getBool('credentialsMigratedToSecureStorageKey'), isTrue);
    });
  });
}
