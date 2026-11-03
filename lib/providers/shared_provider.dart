import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kinos/models/account_model.dart';
import 'package:kinos/models/credentials_model.dart';
import 'package:kinos/models/last_seen_notifications_model.dart';
import 'package:kinos/models/seerr_credentials_model.dart';
import 'package:kinos/models/settings/client_settings_model.dart';
import 'package:kinos/models/settings/home_settings_model.dart';
import 'package:kinos/models/settings/subtitle_settings_model.dart';
import 'package:kinos/models/settings/video_player_settings.dart';
import 'package:kinos/providers/api_provider.dart';
import 'package:kinos/providers/service_provider.dart';
import 'package:kinos/providers/settings/book_viewer_settings_provider.dart';
import 'package:kinos/providers/settings/client_settings_provider.dart';
import 'package:kinos/providers/settings/home_settings_provider.dart';
import 'package:kinos/providers/settings/photo_view_settings_provider.dart';
import 'package:kinos/providers/settings/pigeon_player_settings_provider.dart';
import 'package:kinos/providers/settings/subtitle_settings_provider.dart';
import 'package:kinos/providers/settings/video_player_settings_provider.dart';
import 'package:kinos/providers/update_notifications_provider.dart';
import 'package:kinos/providers/user_provider.dart';
import 'package:kinos/services/secure_credentials_store.dart';
import 'package:kinos/services/seerr_credentials_store.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

final sharedUtilityProvider = Provider<SharedUtility>((ref) {
  final sharedPrefs = ref.watch(sharedPreferencesProvider);

  ref.read(pigeonPlayerSettingsSyncProvider);

  return SharedUtility(ref: ref, sharedPreferences: sharedPrefs)..init();
});

SharedHelper get sharedHelper => SharedHelper(sharedPreferences: SharedPreferences.getInstance() as SharedPreferences);

class SharedUtility extends SharedHelper {
  SharedUtility({
    required Ref ref,
    required super.sharedPreferences,
  }) : _ref = ref;

  final Ref _ref;

  late final JellyService api = _ref.read(jellyApiProvider);

  void init() {
    SharedKeys.instance.onKeyChanged.listen((key) async {
      await Future.delayed(const Duration(milliseconds: 500));
      switch (key) {
        case SharedKeys.lastSeenNotificationsKey:
          _ref.read(notificationsProvider.notifier).state = lastSeenNotifications;
          break;
      }
    });
  }

  Future<bool?> loadSettings() async {
    try {
      _ref.read(clientSettingsProvider.notifier).initialize(clientSettings);
      _ref.read(homeSettingsProvider.notifier).state = homeSettings;
      _ref
          .read(videoPlayerSettingsProvider.notifier)
          .restoreFromPersisted(videoPlayerSettings, lastNonZeroVideoVolume);
      _ref.read(subtitleSettingsProvider.notifier).state = subtitleSettings;
      _ref.read(bookViewerSettingsProvider.notifier).state = bookViewSettings;
      _ref.read(photoViewSettingsProvider.notifier).state = photoViewSettings;
      _ref.read(notificationsProvider.notifier).state = lastSeenNotifications;
      return true;
    } catch (e) {
      return false;
    }
  }
}

class SharedKeys {
  SharedKeys._();

  //Singleton
  static final SharedKeys instance = SharedKeys._();

  static const String _loginCredentialsKey = 'loginCredentialsKey';
  static const String _credentialsMigratedToSecureStorageKey = 'credentialsMigratedToSecureStorageKey';
  static const String _seerrCredentialsMigratedToSecureStorageKey = 'seerrCredentialsMigratedToSecureStorageKey';
  static const String _clientSettingsKey = 'clientSettings';
  static const String _homeSettingsKey = 'homeSettings';
  static const String _videoPlayerSettingsKey = 'videoPlayerSettings';
  static const String _lastNonZeroVideoVolumeKey = 'lastNonZeroVideoVolume';
  static const String _subtitleSettingsKey = 'subtitleSettings';
  static const String _bookViewSettingsKey = 'bookViewSettings';
  static const String _photoViewSettingsKey = 'photoViewSettings';
  static const String lastSeenNotificationsKey = 'lastSeenNotifications';

  final _keyChanged = StreamController<String>.broadcast();

  Stream<String> get onKeyChanged => _keyChanged.stream;
}

class SharedHelper {
  final Ref? ref;
  final SharedPreferences sharedPreferences;
  final SecureCredentialsStore secureCredentials;
  final SeerrCredentialsStore seerrCredentials;

  /// Guards [_migrateCredentialsIfNeeded] within this instance's lifetime -
  /// set after exactly ONE attempt this session, success or failure (a
  /// failed attempt is retried on the next app launch, via the persisted
  /// [SharedKeys._credentialsMigratedToSecureStorageKey] flag staying
  /// unset, never on the next call within the same session - a vault
  /// that's durably unavailable would otherwise fail the same `save` and
  /// rewrite SharedPreferences on every single [getAccounts] call).
  bool _migrationChecked = false;

  /// Same role as [_migrationChecked], for [_migrateSeerrCredentialsIfNeeded]
  /// / [SharedKeys._seerrCredentialsMigratedToSecureStorageKey] - kept
  /// separate so a Seerr-migration failure never blocks the Jellyfin one
  /// (and vice versa) from being marked done.
  bool _seerrMigrationChecked = false;

  /// Memoizes an in-flight [_migrateCredentialsIfNeeded] run so that two
  /// [getAccounts] calls racing at startup (a very real scenario: the
  /// account list can be read from more than one place while the app is
  /// still initializing) await the SAME migration attempt instead of each
  /// running their own full read-modify-write pass over
  /// [SharedKeys._loginCredentialsKey] - the second pass would otherwise
  /// read the list before the first pass's write landed, then overwrite
  /// that write with its own conclusions once it finished. Cleared once
  /// [_migrationChecked] is set, since every call after that short-circuits
  /// before ever consulting this field again.
  Future<void>? _migrationFuture;

  /// Same role as [_migrationFuture], for [_migrateSeerrCredentialsIfNeeded].
  Future<void>? _seerrMigrationFuture;

  /// Accounts (by [_accountKey]) whose last [_hydrateAccount] attempt hit a
  /// vault read error - a locked/absent keyring, a native backend crash,
  /// anything short of "no entry" (which is the normal, expected case for
  /// e.g. an account with no Seerr configured, and never lands here).
  ///
  /// [saveAccounts] must treat these as untouchable: the in-memory
  /// [AccountModel] for a key in this set is missing its real credentials
  /// (still the SharedPreferences placeholder), so writing it to the vault
  /// would overwrite the real Jellyfin token with that placeholder, and
  /// `seerrCredentials == null` would read as "disconnected" and delete the
  /// real Seerr entry - destroying both on a merely-unavailable vault. An
  /// account is dropped from this set the next time [_hydrateAccount]
  /// succeeds for it (both reads), so it heals itself on the next
  /// successful [getAccounts] once the vault is back.
  final Set<String> _unhydratedAccountKeys = {};

  static String _accountKey(AccountModel account) => '${account.credentials.serverId}:${account.id}';

  SharedHelper({
    this.ref,
    required this.sharedPreferences,
    this.secureCredentials = const SecureCredentialsStore(),
    this.seerrCredentials = const SeerrCredentialsStore(),
  });

  Future<bool?> addAccount(AccountModel account) async {
    final newAccount = account.copyWith(
      lastUsed: DateTime.now(),
    );

    List<AccountModel> accounts = await getAccounts();
    if (accounts.any((element) => element.sameIdentity(newAccount))) {
      accounts = accounts
          .map(
            (e) => e.sameIdentity(newAccount)
                ? e.copyWith(
                    credentials: newAccount.credentials,
                    lastUsed: newAccount.lastUsed,
                  )
                : e,
          )
          .toList();
    } else {
      accounts = [
        ...accounts,
        newAccount,
      ];
    }

    return await saveAccounts(accounts);
  }

  Future<bool?> removeAccount(AccountModel? account) async {
    if (account == null) return null;

    try {
      //Try to logout user
      await ref?.read(userProvider.notifier).forceLogoutUser(account);
    } catch (e) {
      log('Unable to log-out user forcing anyway $e');
    }

    //Remove from local database
    final savedAccounts = await getAccounts();
    savedAccounts.removeWhere((element) {
      return element.sameIdentity(account);
    });
    await secureCredentials.delete(account.credentials.serverId, account.id);
    await seerrCredentials.delete(account.credentials.serverId, account.id);
    _unhydratedAccountKeys.remove(_accountKey(account));
    return (await saveAccounts(savedAccounts));
  }

  /// Reads the saved account list, with each account's real [CredentialsModel]
  /// (server URL, token, deviceId, ...) and [SeerrCredentialsModel] (apiKey,
  /// sessionCookie) rehydrated from secure storage.
  ///
  /// SharedPreferences only ever holds the non-sensitive rest of the account
  /// (name, avatar, filters, ...) plus the `serverId` needed to look the
  /// credentials up - see [saveAccounts].
  Future<List<AccountModel>> getAccounts() async {
    await _migrateCredentialsIfNeeded();
    await _migrateSeerrCredentialsIfNeeded();

    final savedAccounts = sharedPreferences.getStringList(SharedKeys._loginCredentialsKey);
    if (savedAccounts == null) return [];

    try {
      final accounts = savedAccounts.map((e) => AccountModel.fromJson(jsonDecode(e))).toList();
      return await Future.wait(accounts.map(_hydrateAccount));
    } catch (_, stacktrace) {
      log(stacktrace.toString());
      return [];
    }
  }

  /// Rehydrates one account's [CredentialsModel] and [SeerrCredentialsModel]
  /// from their respective vaults, each read isolated in its own try/catch
  /// so a Jellyfin vault error never prevents attempting the Seerr read (or
  /// vice versa), and neither ever propagates out to fail the whole
  /// [getAccounts] batch - a degraded account stays in the returned list
  /// (without its secrets) instead of silently vanishing from it, so the UI
  /// can offer reconnecting it rather than the account just disappearing.
  ///
  /// Tracks success/failure in [_unhydratedAccountKeys] - see its doc for
  /// why [saveAccounts] needs that.
  Future<AccountModel> _hydrateAccount(AccountModel account) async {
    final key = _accountKey(account);
    var hydrated = account;
    var fullyHydrated = true;

    try {
      final storedCredentials = await secureCredentials.read(account.credentials.serverId, account.id);
      // No vault entry (e.g. it was cleared outside the app) leaves the
      // account's placeholder credentials as-is rather than dropping it -
      // failing to log in with an empty token is easier to recover from
      // than an account silently disappearing from the list.
      if (storedCredentials != null) hydrated = hydrated.copyWith(credentials: storedCredentials);
    } catch (e, stacktrace) {
      fullyHydrated = false;
      // Never interpolate `storedCredentials`/`e`'s payload here - only
      // the account's non-secret `key` and the platform exception message,
      // which describes the failure (locked keyring, backend crash, ...),
      // not the value that failed to be read.
      log('Failed to read Jellyfin credentials from secure storage for $key, '
          'keeping the account without them: $e\n$stacktrace');
    }

    try {
      final storedSeerrCredentials = await seerrCredentials.read(account.credentials.serverId, account.id);
      if (storedSeerrCredentials != null) {
        hydrated = hydrated.copyWith(seerrCredentials: storedSeerrCredentials);
      }
    } catch (e, stacktrace) {
      fullyHydrated = false;
      log('Failed to read Seerr credentials from secure storage for $key, '
          'keeping the account without them: $e\n$stacktrace');
    }

    if (fullyHydrated) {
      _unhydratedAccountKeys.remove(key);
    } else {
      _unhydratedAccountKeys.add(key);
    }
    return hydrated;
  }

  /// One-time, idempotent move of every account's [CredentialsModel] out of
  /// the plaintext SharedPreferences blob and into [secureCredentials].
  ///
  /// Runs at most once per install (guarded by a persisted flag) AND at
  /// most once per session regardless of outcome (guarded by
  /// [_migrationChecked], set after this one attempt whether it succeeded
  /// or not - see its doc). Concurrent callers within that one attempt
  /// share [_migrationFuture] rather than each starting their own
  /// read-modify-write pass over [SharedKeys._loginCredentialsKey].
  Future<void> _migrateCredentialsIfNeeded() {
    if (_migrationChecked) return Future.value();
    return _migrationFuture ??= _runCredentialsMigration();
  }

  Future<void> _runCredentialsMigration() async {
    if (sharedPreferences.getBool(SharedKeys._credentialsMigratedToSecureStorageKey) ?? false) {
      _migrationChecked = true;
      return;
    }

    final rawAccounts = sharedPreferences.getStringList(SharedKeys._loginCredentialsKey);
    if (rawAccounts == null || rawAccounts.isEmpty) {
      await sharedPreferences.setBool(SharedKeys._credentialsMigratedToSecureStorageKey, true);
      _migrationChecked = true;
      return;
    }

    try {
      // At this point credentials are still the old plaintext payload, as
      // written by every version of the app before this migration existed.
      final accounts = rawAccounts.map((e) => AccountModel.fromJson(jsonDecode(e))).toList();

      for (final account in accounts) {
        await secureCredentials.save(account.credentials.serverId, account.id, account.credentials);
      }

      await sharedPreferences.setStringList(
        SharedKeys._loginCredentialsKey,
        accounts.map((e) => jsonEncode(_stripCredentials(e))).toList(),
      );
      await sharedPreferences.setBool(SharedKeys._credentialsMigratedToSecureStorageKey, true);
    } catch (e, stacktrace) {
      log('Failed to migrate stored credentials to secure storage, will retry next launch: $e\n$stacktrace');
    } finally {
      // Set on failure too: this session's one attempt is spent either way
      // - the persisted flag staying unset is what triggers a retry, on
      // the next launch, not on the next call in this session.
      _migrationChecked = true;
    }
  }

  /// One-time, idempotent move of every account's [SeerrCredentialsModel]
  /// (apiKey, sessionCookie, customHeaders) out of the plaintext
  /// SharedPreferences blob and into [seerrCredentials] - same policy as
  /// [_migrateCredentialsIfNeeded] for Jellyfin (one attempt per install,
  /// one attempt per session regardless of outcome, concurrent callers
  /// share [_seerrMigrationFuture]), with one addition: order matters per
  /// account. `save` then an immediate `read`-back is required to match
  /// before that account's plaintext is stripped; a save that silently
  /// didn't durably persist (vault unavailable, keyring locked, ...) is
  /// caught by the mismatch/exception instead of being trusted blindly, so
  /// a failure on one account never drops its credentials - they're left
  /// untouched in SharedPreferences and retried on the next app launch.
  /// Accounts without Seerr configured are left alone entirely.
  ///
  /// Deliberately does not touch [AccountModel.credentials] (the Jellyfin
  /// side, already handled by [_migrateCredentialsIfNeeded]) or reuse
  /// [_stripCredentials] for the write-back: composing the two independent
  /// strips (Jellyfin here already-stripped-or-not, Seerr via
  /// [_stripSeerrCredentials]) keeps this migration correct regardless of
  /// which of the two happens to run first in [getAccounts].
  Future<void> _migrateSeerrCredentialsIfNeeded() {
    if (_seerrMigrationChecked) return Future.value();
    return _seerrMigrationFuture ??= _runSeerrCredentialsMigration();
  }

  Future<void> _runSeerrCredentialsMigration() async {
    if (sharedPreferences.getBool(SharedKeys._seerrCredentialsMigratedToSecureStorageKey) ?? false) {
      _seerrMigrationChecked = true;
      return;
    }

    final rawAccounts = sharedPreferences.getStringList(SharedKeys._loginCredentialsKey);
    if (rawAccounts == null || rawAccounts.isEmpty) {
      await sharedPreferences.setBool(SharedKeys._seerrCredentialsMigratedToSecureStorageKey, true);
      _seerrMigrationChecked = true;
      return;
    }

    List<AccountModel> accounts;
    try {
      accounts = rawAccounts.map((e) => AccountModel.fromJson(jsonDecode(e))).toList();
    } catch (e, stacktrace) {
      log('Failed to decode stored accounts for Seerr credentials migration, will retry next launch: $e\n$stacktrace');
      _seerrMigrationChecked = true;
      return;
    }

    var allMigrated = true;
    final updatedAccounts = <AccountModel>[];
    for (final account in accounts) {
      final seerr = account.seerrCredentials;
      if (seerr == null || !seerr.isConfigured) {
        updatedAccounts.add(account);
        continue;
      }

      try {
        await seerrCredentials.save(account.credentials.serverId, account.id, seerr);
        final readBack = await seerrCredentials.read(account.credentials.serverId, account.id);
        // Freezed equality is disabled project-wide (`build.yaml`,
        // `freezed: equal: false`) - `readBack != seerr` would always be
        // true (identity comparison) even for identical data, so the
        // round-trip is checked via its JSON form instead.
        if (readBack == null || jsonEncode(readBack.toJson()) != jsonEncode(seerr.toJson())) {
          throw StateError('Vault read-back did not match what was just written.');
        }
        updatedAccounts.add(_stripSeerrCredentials(account));
      } catch (e, stacktrace) {
        log('Failed to migrate Seerr credentials to secure storage for account '
            '${account.credentials.serverId}:${account.id}, will retry next launch: $e\n$stacktrace');
        allMigrated = false;
        updatedAccounts.add(account);
      }
    }

    await sharedPreferences.setStringList(
      SharedKeys._loginCredentialsKey,
      updatedAccounts.map((e) => jsonEncode(e)).toList(),
    );

    if (allMigrated) {
      await sharedPreferences.setBool(SharedKeys._seerrCredentialsMigratedToSecureStorageKey, true);
    }
    // Set regardless of `allMigrated`: this session's one attempt is spent
    // either way - a partial/total failure is retried on the next app
    // launch (the persisted flag stays unset), not on the next call here.
    _seerrMigrationChecked = true;
  }

  Future<AccountModel?> getActiveAccount() async {
    try {
      final accounts = await getAccounts();
      AccountModel recentUsedAccount = accounts.reduce((lastLoggedIn, element) {
        return (element.lastUsed.compareTo(lastLoggedIn.lastUsed)) > 0 ? element : lastLoggedIn;
      });

      if (recentUsedAccount.authMethod == Authentication.autoLogin) return recentUsedAccount;
      return null;
    } catch (e) {
      log(e.toString());
      return null;
    }
  }

  /// Persists [accounts]: each one's real credentials go to
  /// [secureCredentials] (keyed by `serverId:userId`) and, when Seerr is
  /// configured, its real [SeerrCredentialsModel] goes to [seerrCredentials]
  /// (keyed by `seerr:serverId:userId`) - while SharedPreferences only ever
  /// gets [_stripCredentials]'s and [_stripSeerrCredentials]'s placeholders
  /// in their place. An account whose Seerr credentials are no longer
  /// configured (disconnected, or never set up) has its vault entry deleted
  /// rather than an empty value written - nothing left to protect there.
  ///
  /// An account in [_unhydratedAccountKeys] skips ALL vault writes (both
  /// save and delete) for this call - its in-memory credentials are the
  /// SharedPreferences placeholder, not the real thing, because the last
  /// read from the vault failed. Writing that placeholder to the vault
  /// would overwrite the real Jellyfin token with it, and treat a merely
  /// unreadable Seerr entry as "disconnected" and delete it - turning a
  /// temporary vault outage into permanent data loss the moment any routine
  /// update (last-used timestamp, avatar, ...) calls this. Only the
  /// SharedPreferences write (with the usual placeholders) still happens,
  /// so the rest of the account list stays in sync.
  Future<bool?> saveAccounts(List<AccountModel> accounts) async {
    for (final account in accounts) {
      if (_unhydratedAccountKeys.contains(_accountKey(account))) continue;
      await secureCredentials.save(account.credentials.serverId, account.id, account.credentials);
      if (account.seerrCredentials?.isConfigured == true) {
        await seerrCredentials.save(account.credentials.serverId, account.id, account.seerrCredentials!);
      } else {
        await seerrCredentials.delete(account.credentials.serverId, account.id);
      }
    }
    return sharedPreferences.setStringList(
      SharedKeys._loginCredentialsKey,
      accounts.map((e) => jsonEncode(_stripSeerrCredentials(_stripCredentials(e)))).toList(),
    );
  }

  /// Keeps only `serverId` (needed to look credentials back up in
  /// [secureCredentials]) and blanks out everything else - token, both URLs,
  /// serverName, deviceId - before an account is written to SharedPreferences.
  AccountModel _stripCredentials(AccountModel account) => account.copyWith(
        credentials: CredentialsModel.internal(serverId: account.credentials.serverId),
      );

  /// Blanks [AccountModel.seerrCredentials] entirely before an account is
  /// written to SharedPreferences - unlike Jellyfin's [CredentialsModel],
  /// nothing about it is needed to look the real value back up in
  /// [seerrCredentials]: that lookup key comes from `credentials.serverId`
  /// and `id`, both independent of this field.
  AccountModel _stripSeerrCredentials(AccountModel account) =>
      account.seerrCredentials == null ? account : account.copyWith(seerrCredentials: null);

  ClientSettingsModel get clientSettings {
    try {
      return ClientSettingsModel.fromJson(jsonDecode(sharedPreferences.getString(SharedKeys._clientSettingsKey) ?? ""));
    } catch (e) {
      log(e.toString());
      return ClientSettingsModel.defaultModel();
    }
  }

  set clientSettings(ClientSettingsModel settings) =>
      sharedPreferences.setString(SharedKeys._clientSettingsKey, jsonEncode(settings.toJson()));

  HomeSettingsModel get homeSettings {
    try {
      return HomeSettingsModel.fromJson(jsonDecode(sharedPreferences.getString(SharedKeys._homeSettingsKey) ?? ""));
    } catch (e) {
      log(e.toString());
      return HomeSettingsModel.defaultModel();
    }
  }

  set homeSettings(HomeSettingsModel settings) =>
      sharedPreferences.setString(SharedKeys._homeSettingsKey, jsonEncode(settings.toJson()));

  BookViewerSettingsModel get bookViewSettings {
    try {
      return BookViewerSettingsModel.fromJson(sharedPreferences.getString(SharedKeys._bookViewSettingsKey) ?? "");
    } catch (e) {
      log(e.toString());
      return BookViewerSettingsModel();
    }
  }

  set bookViewSettings(BookViewerSettingsModel settings) {
    sharedPreferences.setString(SharedKeys._bookViewSettingsKey, settings.toJson());
  }

  Future<void> updateAccountInfo(AccountModel account) async {
    final accounts = await getAccounts();
    await Future.microtask(() async {
      await saveAccounts(accounts.map((e) {
        if (e.sameIdentity(account)) {
          return account.copyWith(
            lastUsed: DateTime.now(),
          );
        } else {
          return e;
        }
      }).toList());
    });
  }

  LastSeenNotificationsModel get lastSeenNotifications {
    try {
      return LastSeenNotificationsModel.fromJson(
          jsonDecode(sharedPreferences.getString(SharedKeys.lastSeenNotificationsKey) ?? ""));
    } catch (e) {
      log(e.toString());
      return const LastSeenNotificationsModel();
    }
  }

  Future<void> setLastSeenNotifications(LastSeenNotificationsModel serverLastSeen) async {
    await sharedPreferences.setString(SharedKeys.lastSeenNotificationsKey, jsonEncode(serverLastSeen.toJson()));
    SharedKeys.instance._keyChanged.add(SharedKeys.lastSeenNotificationsKey);
  }

  SubtitleSettingsModel get subtitleSettings {
    try {
      return SubtitleSettingsModel.fromJson(sharedPreferences.getString(SharedKeys._subtitleSettingsKey) ?? "");
    } catch (e) {
      log(e.toString());
      return const SubtitleSettingsModel();
    }
  }

  set subtitleSettings(SubtitleSettingsModel settings) {
    sharedPreferences.setString(SharedKeys._subtitleSettingsKey, settings.toJson());
  }

  VideoPlayerSettingsModel get videoPlayerSettings {
    try {
      return VideoPlayerSettingsModel.fromJson(
          jsonDecode(sharedPreferences.getString(SharedKeys._videoPlayerSettingsKey) ?? ""));
    } catch (e) {
      log(e.toString());
      return VideoPlayerSettingsModel();
    }
  }

  set videoPlayerSettings(VideoPlayerSettingsModel settings) {
    sharedPreferences.setString(SharedKeys._videoPlayerSettingsKey, jsonEncode(settings.toJson()));
  }

  /// Dernier volume non nul connu (`VideoPlayerSettingsProviderNotifier
  /// ._setVolume`, jamais écrasé par un volume à 0) — ce que
  /// `restoreFromPersisted` restaure quand le volume persisté est 0,
  /// pour ne jamais relancer l'app en silence après une session muette.
  double get lastNonZeroVideoVolume =>
      sharedPreferences.getDouble(SharedKeys._lastNonZeroVideoVolumeKey) ?? 100;

  set lastNonZeroVideoVolume(double value) {
    sharedPreferences.setDouble(SharedKeys._lastNonZeroVideoVolumeKey, value);
  }

  PhotoViewSettingsModel get photoViewSettings {
    try {
      return PhotoViewSettingsModel.fromJson(sharedPreferences.getString(SharedKeys._photoViewSettingsKey) ?? "");
    } catch (e) {
      log(e.toString());
      return PhotoViewSettingsModel();
    }
  }

  set photoViewSettings(PhotoViewSettingsModel settings) {
    sharedPreferences.setString(SharedKeys._photoViewSettingsKey, settings.toJson());
  }
}
