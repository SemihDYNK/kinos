import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinos/jellyfin/jellyfin_open_api.swagger.dart' as dto;
import 'package:kinos/models/syncing/database_item.dart';
import 'package:kinos/providers/api_provider.dart';
import 'package:kinos/providers/connectivity_provider.dart';
import 'package:kinos/providers/database_provider.dart';
import 'package:kinos/providers/incognito_mode_provider.dart';
import 'package:kinos/providers/user_provider.dart';
import 'anilist_account.dart';
import 'anilist_client.dart';
import 'anilist_progress.dart';
import 'anilist_providers.dart';
import 'anilist_store.dart';
import 'episode_mapping.dart';
import 'episode_store.dart';
import 'mapping.dart';

String? anilistScopeFor(Ref ref) {
  final user = ref.read(userProvider);
  return user == null
      ? null
      : anilistProfileScope(
          serverId: user.credentials.serverId,
          url: user.credentials.url,
          userId: user.id);
}

typedef AnilistClientFactory = AnilistClient Function({String? token});
final anilistClientFactoryProvider = Provider<AnilistClientFactory>(
    (ref) => ({String? token}) => AnilistClient(token: token));
final anilistAccountStoreProvider =
    Provider((ref) => const AnilistAccountStore());
final anilistConnectionProvider =
    FutureProvider<AnilistConnection?>((ref) async {
  ref.watch(userProvider
      .select((u) => (u?.id, u?.credentials.serverId, u?.credentials.url)));
  final scope = anilistScopeFor(ref);
  if (scope == null) return null;
  final db = ref.watch(appDatabaseProvider);
  final vault = ref.watch(anilistAccountStoreProvider);
  final configured = await db.getSetting('configured', scope: '$scope:account');
  if (configured == null) return null;
  return vault.read(scope);
});
final anilistSyncStatusProvider = StateProvider<String?>((ref) {
  ref.watch(userProvider
      .select((u) => (u?.id, u?.credentials.serverId, u?.credentials.url)));
  return null;
});
final anilistAccountUpdatingProvider = StateProvider<bool>((ref) {
  ref.watch(userProvider
      .select((u) => (u?.id, u?.credentials.serverId, u?.credentials.url)));
  return false;
});
const anilistPlaybackScope = 'anilist:playback-provenance:v1';
String anilistPlaybackKey(int id) => 'playback:$id';
final anilistRuntimeProvider = Provider<AnilistRuntime>((ref) {
  ref.watch(userProvider
      .select((u) => (u?.id, u?.credentials.serverId, u?.credentials.url)));
  ref.watch(incognitoProvider);
  ref.watch(anilistAccountUpdatingProvider);
  final future = ref.watch(anilistConnectionProvider.future);
  final runtime = AnilistRuntime(ref, anilistScopeFor(ref), future);
  ref.onDispose(runtime.dispose);
  return runtime;
});

class AnilistRuntime {
  final Ref ref;
  final String? scope;
  final Future<AnilistConnection?> connection;
  bool _alive = true;
  Future<void>? _running;
  AnilistProgressWorker? _worker;
  AnilistClient? _client;
  late final Timer _timer;
  AnilistRuntime(this.ref, this.scope, this.connection) {
    _timer =
        Timer.periodic(const Duration(seconds: 30), (_) => unawaited(drain()));
    unawaited(drain());
  }
  bool get current =>
      _alive &&
      scope != null &&
      anilistScopeFor(ref) == scope &&
      !ref.read(incognitoProvider) &&
      !ref.read(anilistAccountUpdatingProvider);
  void dispose() {
    _alive = false;
    _timer.cancel();
    _client?.close();
  }

  EpisodeStore get store => EpisodeStore(ref.read(appDatabaseProvider), scope!);
  Future<String?> provenance() async {
    if (!current) return null;
    final row = await ref
        .read(appDatabaseProvider)
        .getSetting('configured', scope: '$scope:account');
    if (!current || row == null) return null;
    try {
      final hint = jsonDecode(row.value);
      if (hint is! Map ||
          hint['enabled'] != true ||
          hint['generation'] is! String ||
          positiveId(hint['id']) == null) {
        return null;
      }
      return jsonEncode(
          [scope, positiveId(hint['id']), true, hint['generation']]);
    } on FormatException {
      return null;
    }
  }

  Future<void> Function() capture(String itemId, {String? expectedProvenance}) {
    return () async {
      if (!current) return;
      AnilistConnection? account;
      try {
        account = await connection;
      } on Exception {
        if (current) ref.invalidate(anilistConnectionProvider);
        rethrow;
      }
      if (!current || account == null || !account.enabled) return;
      if (expectedProvenance != null) {
        final expected = jsonDecode(expectedProvenance);
        if (expected is! List ||
            expected.length != 4 ||
            expected[1] != account.id ||
            await provenance() != expectedProvenance ||
            !current) {
          return;
        }
      }
      await store.enqueue(itemId, account.id, isCurrent: () => current);
      // The Jellyfin report is already acknowledged; local persistence is the only awaited work.
    };
  }

  Future<void> drain() =>
      _running ??= _drain().whenComplete(() => _running = null);
  Future<void> _drain() async {
    if (!current || ref.read(offlineStateProvider)) return;
    try {
      final account = await connection;
      if (!current || account == null || !account.enabled) return;
      if (_worker == null) {
        final client =
            ref.read(anilistClientFactoryProvider)(token: account.token);
        _client = client;
        _worker = AnilistProgressWorker(
            store: store,
            accountId: account.id,
            client: client,
            isCurrent: () => current,
            load: loadSnapshot,
            onStatus: (s) {
              if (current) {
                ref.read(anilistSyncStatusProvider.notifier).state = s;
              }
            });
      }
      await _worker!.drain();
    } on Exception {
      if (current) {
        ref.read(anilistSyncStatusProvider.notifier).state = 'network';
      }
    }
  }

  void check() {
    if (!current) throw const AnilistScopeChanged();
  }

  Future<dto.BaseItemDto> item(String id) async {
    check();
    final response = await ref
        .read(jellyApiProvider)
        .usersUserIdItemsItemIdGetBaseItem(itemId: id);
    check();
    if (!response.isSuccessful ||
        response.body == null ||
        response.body!.id != id) {
      throw const AnilistUnavailable();
    }
    return response.body!;
  }

  AnilistTarget seriesTarget(dto.BaseItemDto series) => AnilistTarget(
      itemId: series.id!,
      title: series.name ?? '',
      kind: AnilistTargetKind.series,
      ids: series.providerIds,
      seasonSource: series.displayOrder);
  Future<List<AnilistCandidate>> candidates(AnilistTarget target) async {
    final client = _client;
    if (client == null) throw const AnilistUnavailable();
    final lookup = <int, int>{};
    final mal = positiveId(target.ids.values['mal']);
    if (mal != null) {
      final result = await client.media(malId: mal);
      check();
      if (result == null) throw const AnilistMappingNeeded();
      lookup[mal] = result.id;
    }
    final index = await ref.read(anilistCatalogProvider).load();
    check();
    final match = resolveAnilistTarget(target, index, malLookup: lookup);
    if (match.reason == AnilistMatchReason.conflictingIds) {
      throw const AnilistMappingNeeded();
    }
    if (match.candidates.isEmpty) return [];
    final media = await client.mediaByIds(match.candidates.map((c) => c.id));
    check();
    return [
      for (final c in match.candidates)
        c.withMedia(media.where((m) => m.id == c.id).firstOrNull)
    ];
  }

  Future<ProgressSnapshot?> loadSnapshot(String id) async {
    final playing = await item(id);
    if (playing.userData?.played != true) return null;
    if (playing.type == dto.BaseItemKind.movie) {
      final target = AnilistTarget(
          itemId: id,
          title: playing.name ?? '',
          kind: AnilistTargetKind.movie,
          ids: playing.providerIds);
      final manual = await AnilistStore(ref.read(appDatabaseProvider), scope!)
          .read(target);
      check();
      if (manual != null && !manual.confirmed) {
        throw const AnilistMappingNeeded();
      }
      final values = manual?.confirmed == true
          ? [
              AnilistCandidate(manual!.id, {'manual'},
                  media: await _client!.media(id: manual.id))
            ]
          : await candidates(target);
      check();
      if (values.isEmpty) return null;
      if (values.length != 1 ||
          values.single.media == null ||
          (values.single.media!.format != 'MOVIE' &&
              values.single.media!.episodes != 1)) {
        throw const AnilistMappingNeeded();
      }
      return ProgressSnapshot(
          mediaId: values.single.id, watched: const {1}, total: 1);
    }
    if (playing.type != dto.BaseItemKind.episode) return null;
    final seriesId = playing.seriesId;
    if (seriesId == null ||
        playing.parentIndexNumber == null ||
        playing.indexNumber == null) {
      throw const AnilistMappingNeeded();
    }
    final series = await item(seriesId);
    final target = seriesTarget(series);
    final manual = await store.readPlan(seriesId, target.fingerprint);
    check();
    if (manual == null && await store.hasPlan(seriesId)) {
      throw const AnilistMappingNeeded();
    }
    check();
    List<AnilistCandidate> matches;
    try {
      matches = await candidates(target);
    } on AnilistUnavailable {
      if (manual == null) rethrow;
      matches = [];
    }
    check();
    if (matches.isEmpty && manual == null) return null;
    final plan = EpisodePlan.overlay(EpisodePlan.automatic(matches), manual);
    final destination = plan.resolve(
        playing.parentIndexNumber, playing.indexNumber,
        end: playing.indexNumberEnd);
    if (destination == null) throw const AnilistMappingNeeded();
    final metadata = await _client!.media(id: destination.mediaId);
    check();
    if (metadata == null ||
        plan.ranges.where((r) => r.mediaId == destination.mediaId).any((r) =>
            metadata.episodes != null && r.anilistLast > metadata.episodes!)) {
      throw const AnilistMappingNeeded();
    }
    final watched = <int>{};
    final currentFirst =
        plan.resolve(playing.parentIndexNumber, playing.indexNumber);
    if (currentFirst != null &&
        currentFirst.mediaId == destination.mediaId &&
        destination.episode - currentFirst.episode <= 20000) {
      for (var n = currentFirst.episode; n <= destination.episode; n++) {
        watched.add(n);
      }
    }
    final neededSeasons = plan.ranges
        .where((r) => r.mediaId == destination.mediaId)
        .map((r) => r.season)
        .toSet();
    var start = 0;
    while (true) {
      final response = await ref
          .read(jellyApiProvider)
          .showsSeriesIdEpisodesGet(
              seriesId: seriesId,
              startIndex: start,
              season: neededSeasons.length == 1 ? neededSeasons.single : null,
              limit: 200,
              enableImages: false,
              enableUserData: true);
      check();
      if (!response.isSuccessful || response.body?.items == null) {
        throw const AnilistUnavailable();
      }
      final episodes = response.body!.items!;
      for (final episode in episodes) {
        if (episode.userData?.played != true) continue;
        final first =
            plan.resolve(episode.parentIndexNumber, episode.indexNumber);
        final last = plan.resolve(
            episode.parentIndexNumber, episode.indexNumber,
            end: episode.indexNumberEnd);
        if (first == null ||
            last == null ||
            first.mediaId != destination.mediaId ||
            last.mediaId != first.mediaId ||
            last.episode - first.episode > 20000) {
          continue;
        }
        for (var n = first.episode; n <= last.episode; n++) {
          watched.add(n);
        }
      }
      start += episodes.length;
      final total = response.body!.totalRecordCount;
      if ((total != null && start >= total) ||
          (total == null && episodes.length < 200)) {
        break;
      }
      if (episodes.isEmpty || start >= 20000) throw const AnilistUnavailable();
    }
    return ProgressSnapshot(
        mediaId: destination.mediaId,
        watched: watched,
        total: metadata.episodes);
  }
}

class AnilistPlaybackCapture {
  final AnilistRuntime runtime;
  final String itemId;
  final Future<String?> provenance;
  AnilistPlaybackCapture(this.runtime, this.itemId)
      : provenance = runtime.provenance() {
    // Persistence below awaits this future after enqueueing the Jellyfin report.
    provenance.ignore();
  }
  Future<void> remember() async {
    final expected = await provenance;
    if (expected != null) {
      await runtime.capture(itemId, expectedProvenance: expected)();
    }
  }
}

AnilistPlaybackCapture? captureAnilistPlayback(
        Ref ref, PlaybackQueueEventType type, String itemId) =>
    type != PlaybackQueueEventType.stop
        ? null
        : AnilistPlaybackCapture(ref.read(anilistRuntimeProvider), itemId);

Future<void> captureAnilistMarkedPlayed(Ref ref, String? itemId,
    {required bool responseSuccessful}) async {
  if (!responseSuccessful || itemId == null || itemId.isEmpty) return;
  try {
    final runtime = ref.read(anilistRuntimeProvider);
    await runtime.capture(itemId)();
    unawaited(runtime.drain());
  } on Exception {
    // Marking an item in Jellyfin must not fail because AniList is unavailable.
  }
}
