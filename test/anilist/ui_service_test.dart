import 'dart:convert';
import 'dart:async';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kinos/anilist/anilist_account.dart';
import 'package:kinos/anilist/anilist_client.dart';
import 'package:kinos/anilist/episode_mapping.dart';
import 'package:kinos/anilist/mapping.dart';
import 'package:kinos/anilist/anilist_runtime.dart';
import 'package:kinos/anilist/anilist_ui_service.dart';
import 'package:kinos/models/syncing/database_item.dart';
import 'package:kinos/providers/database_provider.dart';
import 'package:kinos/providers/user_provider.dart';
import '../widgets/seerr_discovery_section_test.dart' show TestUser;

class _PendingVault extends AnilistAccountStore {
  final entered = Completer<void>(), resume = Completer<void>();
  @override
  Future<void> save(String profile, AnilistConnection value) async {
    entered.complete();
    await resume.future;
  }
}

class _UnavailableVault extends AnilistAccountStore {
  @override
  Future<AnilistConnection?> read(String profile) async => null;
  @override
  Future<void> save(String profile, AnilistConnection value) async {
    throw Exception('private storage details');
  }
}

void main() {
  test('connection distinguishes API failure from secure account save failure',
      () async {
    for (final apiFails in [true, false]) {
      late AppDatabase db;
      final c = ProviderContainer(overrides: [
        userProvider.overrideWith(TestUser.new),
        appDatabaseProvider.overrideWith(
            (ref) => db = AppDatabase(ref, NativeDatabase.memory())),
        anilistAccountStoreProvider.overrideWithValue(_UnavailableVault()),
        anilistClientFactoryProvider.overrideWithValue(({String? token}) =>
            AnilistClient(
                token: token,
                interval: Duration.zero,
                client: MockClient((_) async => apiFails
                    ? http.Response('private server details', 502)
                    : http.Response(
                        '{"data":{"Viewer":{"id":1,"name":"Viewer"}}}', 200)))),
      ]);
      final listener = c.listen(anilistUiServiceProvider, (_, __) {});
      final service = c.read(anilistUiServiceProvider);
      await expectLater(
          service.connect('synthetic-token-for-testing'),
          throwsA(apiFails
              ? isA<AnilistUnavailable>()
                  .having((e) => e.statusCode, 'HTTP status', 502)
              : isA<AnilistAccountSaveFailed>()));
      expect(c.read(anilistAccountUpdatingProvider), isFalse);
      expect(
          await c
              .read(appDatabaseProvider)
              .getSetting('configured', scope: '${service.scope}:account'),
          isNull);
      listener.close();
      c.dispose();
      await db.close();
    }
  });

  test(
      'closing the dialog during a secure write cannot leave sync paused forever',
      () async {
    final vault = _PendingVault();
    late AppDatabase db;
    final c = ProviderContainer(overrides: [
      userProvider.overrideWith(TestUser.new),
      appDatabaseProvider.overrideWith(
          (ref) => db = AppDatabase(ref, NativeDatabase.memory())),
      anilistAccountStoreProvider.overrideWithValue(vault),
      anilistConnectionProvider.overrideWith((ref) async =>
          const AnilistConnection(
              id: 1, name: 'User', token: 'private', enabled: true)),
    ]);
    final listener = c.listen(anilistUiServiceProvider, (_, __) {});
    final service = c.read(anilistUiServiceProvider);
    final scope = anilistScopeFor(c.read(Provider<Ref>((ref) => ref)))!;
    await c.read(appDatabaseProvider).setSetting('configured',
        jsonEncode({'id': 1, 'enabled': true, 'generation': 'one'}),
        scope: '$scope:account');
    final operation = service.setEnabled(false);
    await vault.entered.future;
    expect(c.read(anilistAccountUpdatingProvider), isTrue);
    listener.close();
    await c.pump();
    vault.resume.complete();
    await operation;
    await c.pump();
    expect(c.read(anilistAccountUpdatingProvider), isFalse);
    c.dispose();
    await db.close();
  });

  test('manual episode ranges save without a second AniList lookup', () async {
    late AppDatabase db;
    final c = ProviderContainer(overrides: [
      userProvider.overrideWith(TestUser.new),
      appDatabaseProvider.overrideWith(
          (ref) => db = AppDatabase(ref, NativeDatabase.memory())),
      anilistClientFactoryProvider.overrideWithValue(({String? token}) =>
          AnilistClient(
              token: token,
              interval: Duration.zero,
              client: MockClient((_) async => http.Response('', 500)))),
    ]);
    final listener = c.listen(anilistUiServiceProvider, (_, __) {});
    final service = c.read(anilistUiServiceProvider);
    final target = AnilistTarget(
        itemId: 'series',
        title: 'THE GHOST IN THE SHELL',
        kind: AnilistTargetKind.series,
        ids: {'Tmdb': '255358'});

    await service.saveRanges(target, [
      EpisodeRange(
          season: 1, first: 1, last: 10, mediaId: 177699, anilistFirst: 1)
    ]);

    final plan = await service.store.readPlan('series', target.fingerprint);
    expect(plan?.resolve(1, 10), (mediaId: 177699, episode: 10));
    listener.close();
    c.dispose();
    await db.close();
  });
}
