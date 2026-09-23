import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kinos/models/account_model.dart';
import 'package:kinos/models/credentials_model.dart';
import 'package:kinos/models/last_seen_notifications_model.dart';
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

  /// Guards [_migrateCredentialsIfNeeded] within this instance's lifetime.
  /// The real, cross-launch guard is the persisted
  /// [SharedKeys._credentialsMigratedToSecureStorageKey] flag - this just
  /// avoids re-checking that flag on every single call once we know it's set.
  bool _migrationChecked = false;

  SharedHelper({
    this.ref,
    required this.sharedPreferences,
    this.secureCredentials = const SecureCredentialsStore(),
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
    return (await saveAccounts(savedAccounts));
  }

  /// Reads the saved account list, with each account's real [CredentialsModel]
  /// (server URL, token, deviceId, ...) rehydrated from secure storage.
  ///
  /// SharedPreferences only ever holds the non-sensitive rest of the account
  /// (name, avatar, filters, ...) plus the `serverId` needed to look the
  /// credentials up - see [saveAccounts].
  Future<List<AccountModel>> getAccounts() async {
    await _migrateCredentialsIfNeeded();

    final savedAccounts = sharedPreferences.getStringList(SharedKeys._loginCredentialsKey);
    if (savedAccounts == null) return [];

    try {
      final accounts = savedAccounts.map((e) => AccountModel.fromJson(jsonDecode(e))).toList();
      return Future.wait(accounts.map(_hydrateCredentials));
    } catch (_, stacktrace) {
      log(stacktrace.toString());
      return [];
    }
  }

  Future<AccountModel> _hydrateCredentials(AccountModel account) async {
    final storedCredentials = await secureCredentials.read(account.credentials.serverId, account.id);
    // No vault entry (e.g. it was cleared outside the app) leaves the
    // account's placeholder credentials as-is rather than dropping it -
    // failing to log in with an empty token is easier to recover from than
    // an account silently disappearing from the list.
    return storedCredentials == null ? account : account.copyWith(credentials: storedCredentials);
  }

  /// One-time, idempotent move of every account's [CredentialsModel] out of
  /// the plaintext SharedPreferences blob and into [secureCredentials].
  ///
  /// Runs at most once per install (guarded by a persisted flag, checked
  /// once per process by [_migrationChecked]); a failure isn't recorded as
  /// done, so it's retried on the next call instead of stranding plaintext
  /// credentials permanently.
  Future<void> _migrateCredentialsIfNeeded() async {
    if (_migrationChecked) return;
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
      _migrationChecked = true;
    } catch (e, stacktrace) {
      log('Failed to migrate stored credentials to secure storage, will retry: $e\n$stacktrace');
    }
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
  /// [secureCredentials] (keyed by `serverId:userId`), while SharedPreferences
  /// only ever gets [_stripCredentials]'s placeholder in their place.
  Future<bool?> saveAccounts(List<AccountModel> accounts) async {
    for (final account in accounts) {
      await secureCredentials.save(account.credentials.serverId, account.id, account.credentials);
    }
    return sharedPreferences.setStringList(
      SharedKeys._loginCredentialsKey,
      accounts.map((e) => jsonEncode(_stripCredentials(e))).toList(),
    );
  }

  /// Keeps only `serverId` (needed to look credentials back up in
  /// [secureCredentials]) and blanks out everything else - token, both URLs,
  /// serverName, deviceId - before an account is written to SharedPreferences.
  AccountModel _stripCredentials(AccountModel account) => account.copyWith(
        credentials: CredentialsModel.internal(serverId: account.credentials.serverId),
      );

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
