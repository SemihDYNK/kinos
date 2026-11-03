import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinos/models/item_base_model.dart';
import 'package:kinos/models/items/season_model.dart';
import 'package:kinos/providers/api_provider.dart';
import 'package:kinos/providers/database_provider.dart';
import 'package:kinos/providers/user_provider.dart';
import 'anilist_account.dart';
import 'anilist_client.dart';
import 'anilist_runtime.dart';
import 'anilist_store.dart';
import 'episode_mapping.dart';
import 'episode_store.dart';
import 'mapping.dart';

class AnilistAccountSaveFailed implements Exception {
  const AnilistAccountSaveFailed();
}

final anilistUiServiceProvider = Provider.autoDispose<AnilistUiService>((ref) {
  ref.watch(userProvider
      .select((u) => (u?.id, u?.credentials.serverId, u?.credentials.url)));
  final service =
      AnilistUiService(ref, anilistScopeFor(ref), () => ref.keepAlive().close);
  ref.onDispose(service.dispose);
  return service;
});

class AnilistUiService {
  final Ref ref;
  final String? scope;
  bool alive = true;
  final clients = <AnilistClient>{};
  final void Function() Function() retain;
  AnilistUiService(this.ref, this.scope, this.retain);
  bool get current => alive && scope != null && anilistScopeFor(ref) == scope;
  void check() {
    if (!current) throw const AnilistScopeChanged();
  }

  void dispose() {
    alive = false;
    for (final c in clients) {
      c.close();
    }
  }

  EpisodeStore get store => EpisodeStore(ref.read(appDatabaseProvider), scope!);
  Future<void> connect(String value) async {
    check();
    final token = value.trim();
    if (token.length < 20 ||
        token.length > 8192 ||
        token.contains(RegExp(r'\s'))) {
      throw const AnilistUnauthorized();
    }
    final client = ref.read(anilistClientFactoryProvider)(token: token);
    clients.add(client);
    var saving = false;
    try {
      final viewer = await client.viewer();
      check();
      saving = true;
      await _change(() async {
        final previous =
            await ref.read(anilistAccountStoreProvider).read(scope!);
        check();
        final hint = await ref
            .read(appDatabaseProvider)
            .getSetting('configured', scope: '$scope:account');
        check();
        if (previous != null && (previous.id != viewer.id || hint == null)) {
          await store.clearAccount(previous.id);
        }
        check();
        await ref.read(anilistAccountStoreProvider).save(
            scope!,
            AnilistConnection(
                id: viewer.id,
                name: viewer.name,
                token: token,
                enabled: false));
        check();
        await ref.read(appDatabaseProvider).setSetting(
            'configured',
            jsonEncode({
              'id': viewer.id,
              'enabled': false,
              'generation': DateTime.now().microsecondsSinceEpoch.toString()
            }),
            scope: '$scope:account');
      });
    } on Exception catch (error) {
      if (saving && error is! AnilistScopeChanged) {
        throw const AnilistAccountSaveFailed();
      }
      rethrow;
    } finally {
      clients.remove(client);
      client.close();
    }
  }

  Future<void> _change(Future<void> Function() action) async {
    check();
    if (ref.read(anilistAccountUpdatingProvider)) {
      throw const AnilistUnavailable();
    }
    final release = retain();
    ref.read(anilistAccountUpdatingProvider.notifier).state = true;
    ref.invalidate(anilistRuntimeProvider);
    try {
      await action();
      check();
      ref.invalidate(anilistConnectionProvider);
    } finally {
      if (current) {
        ref.invalidate(anilistConnectionProvider);
        ref.read(anilistAccountUpdatingProvider.notifier).state = false;
      }
      release();
    }
  }

  Future<void> _checkConnection(AnilistConnection? expected) async {
    final latest = await ref.read(anilistConnectionProvider.future);
    check();
    if (latest?.id != expected?.id || latest?.token != expected?.token) {
      throw const AnilistScopeChanged();
    }
  }

  Future<void> setEnabled(bool enabled) async {
    final account = await ref.read(anilistConnectionProvider.future);
    check();
    if (account == null) throw const AnilistUnauthorized();
    await _change(() async {
      await _checkConnection(account);
      final row = await ref
          .read(appDatabaseProvider)
          .getSetting('configured', scope: '$scope:account');
      check();
      if (row == null) throw const AnilistUnavailable();
      final hint = jsonDecode(row.value);
      if (hint is! Map ||
          hint['id'] != account.id ||
          hint['generation'] is! String) {
        throw const AnilistUnavailable();
      }
      await ref
          .read(anilistAccountStoreProvider)
          .save(scope!, account.withEnabled(enabled));
      check();
      await ref.read(appDatabaseProvider).setSetting(
          'configured',
          jsonEncode({
            'id': account.id,
            'enabled': enabled,
            'generation': hint['generation']
          }),
          scope: '$scope:account');
      check();
      if (enabled) await store.retryNow(account.id);
    });
  }

  Future<void> disconnect() async {
    final account = await ref.read(anilistConnectionProvider.future);
    check();
    await _change(() async {
      await _checkConnection(account);
      await ref
          .read(appDatabaseProvider)
          .deleteSetting('configured', scope: '$scope:account');
      check();
      if (account != null) await store.clearAccount(account.id);
      check();
      await ref.read(anilistAccountStoreProvider).delete(scope!);
    });
  }

  Future<({AnilistTarget target, List<EpisodeRange> ranges, bool changed})>
      ranges(ItemBaseModel item) async {
    check();
    final id = item is SeasonModel ? item.seriesId : item.id;
    final response = await ref
        .read(jellyApiProvider)
        .usersUserIdItemsItemIdGetBaseItem(itemId: id);
    check();
    final source = response.body;
    if (!response.isSuccessful || source == null || source.id != id) {
      throw const AnilistUnavailable();
    }
    final target = AnilistTarget(
        itemId: id,
        title: source.name ?? item.name,
        kind: AnilistTargetKind.series,
        ids: source.providerIds,
        seasonSource: source.displayOrder);
    final saved = await store.readPlan(id, target.fingerprint);
    check();
    final stale = saved == null
        ? await store.readPlan(id, target.fingerprint, allowStale: true)
        : null;
    check();
    return (
      target: target,
      ranges: saved?.ranges ?? stale?.ranges ?? [],
      changed: saved == null && await store.hasPlan(id)
    );
  }

  Future<void> saveRanges(
      AnilistTarget target, List<EpisodeRange> ranges) async {
    check();
    EpisodePlan.manual(ranges);
    final client = ref.read(anilistClientFactoryProvider)();
    clients.add(client);
    try {
      for (final id in ranges.map((r) => r.mediaId).toSet()) {
        final media = await client.media(id: id);
        check();
        if (media == null ||
            ranges.where((r) => r.mediaId == id).any((r) =>
                media.episodes != null && r.anilistLast > media.episodes!)) {
          throw ArgumentError('Invalid episode range');
        }
      }
      await store.savePlan(target.itemId, target.fingerprint, ranges,
          isCurrent: () => current);
      check();
      final account = await ref.read(anilistConnectionProvider.future);
      check();
      if (account != null) await store.retryNow(account.id);
      check();
      unawaitedDrain();
    } finally {
      clients.remove(client);
      client.close();
    }
  }

  void unawaitedDrain() {
    ref.read(anilistRuntimeProvider).drain();
  }
}
