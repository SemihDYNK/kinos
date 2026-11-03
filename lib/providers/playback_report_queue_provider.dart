import 'package:kinos/anilist/anilist_runtime.dart';
import 'dart:async';
import 'dart:developer';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:kinos/jellyfin/jellyfin_open_api.swagger.dart';
import 'package:kinos/models/playback/playback_report_conflict.dart';
import 'package:kinos/models/syncing/database_item.dart';
import 'package:kinos/providers/api_provider.dart';
import 'package:kinos/providers/connectivity_provider.dart';
import 'package:kinos/providers/database_provider.dart';
import 'package:kinos/providers/service_provider.dart';
import 'package:kinos/providers/user_provider.dart';

part 'playback_report_queue_provider.g.dart';

/// Drains `playback_queue`: playback start/progress/stop reports that were
/// written to the local database before being sent, so a network failure
/// loses nothing - see [JellyService.sessionsPlayingPost] and friends.
///
/// Activated once at app startup (see [BaseAppWrapperState]) and then runs
/// for the lifetime of the app: it retries pending entries on a timer with
/// per-entry exponential backoff, and immediately whenever connectivity
/// comes back after being offline.
@Riverpod(keepAlive: true)
class PlaybackReportQueueWorker extends _$PlaybackReportQueueWorker {
  Timer? _pollTimer;

  /// Backoff state is kept in memory only: it exists to space out retries
  /// within one running app session, not to survive restarts. `attempts` -
  /// which does survive restarts, since it's a column on the row - already
  /// makes the backoff start wherever it left off after a relaunch.
  final Map<int, DateTime> _nextAttemptAt = {};

  bool _draining = false;

  static const _pollInterval = Duration(seconds: 30);
  static const _baseBackoff = Duration(seconds: 5);
  static const _maxBackoff = Duration(minutes: 5);

  @override
  void build() {
    ref.listen<ConnectionState>(connectivityStatusProvider, (previous, next) {
      if (previous == ConnectionState.offline && next != ConnectionState.offline) {
        unawaited(drainQueue());
      }
    });

    _pollTimer = Timer.periodic(_pollInterval, (_) => unawaited(drainQueue()));
    ref.onDispose(() => _pollTimer?.cancel());

    // Catch up on anything a previous session left behind.
    unawaited(drainQueue());
  }

  /// Backoff applied after the [attempts]-th failure of a given entry.
  /// Exponential, capped at [_maxBackoff].
  static Duration backoffForAttempts(int attempts) {
    final factor = 1 << attempts.clamp(0, 10);
    final backoff = _baseBackoff * factor;
    return backoff > _maxBackoff ? _maxBackoff : backoff;
  }

  /// Sends every due entry in `playback_queue` for the current user.
  ///
  /// Safe to call as often as needed (a poll tick, a connectivity change, a
  /// fresh enqueue): entries still within their backoff window, or already
  /// being drained by a call in flight, are skipped rather than retried.
  Future<void> drainQueue() async {
    if (_draining) return;
    if (ref.read(offlineStateProvider)) return;
    if (ref.read(userProvider) == null) return;

    _draining = true;
    try {
      final db = ref.read(appDatabaseProvider);
      final service = ref.read(jellyApiProvider);
      final pending = await db.getPendingPlaybackEvents.get();
      if (pending.isEmpty) return;

      final now = DateTime.now();
      for (final entry in pending) {
        final nextAttempt = _nextAttemptAt[entry.id];
        if (nextAttempt != null && now.isBefore(nextAttempt)) continue;

        try {
          await _sendEntry(service, db, entry);
          _nextAttemptAt.remove(entry.id);
        } catch (error, stackTrace) {
          final attempts = entry.attempts + 1;
          log('playback_queue: entry ${entry.id} failed (attempt $attempts): $error\n$stackTrace');
          await db.incrementPlaybackEventAttempts(entry.id);
          await db.recordPlaybackEventFailure(entry.id, error.toString());
          _nextAttemptAt[entry.id] = now.add(backoffForAttempts(attempts));
        }

        // Connectivity may have dropped mid-drain; stop rather than fail
        // through the rest of the batch one by one.
        if (ref.read(offlineStateProvider)) break;
      }
    } finally {
      _draining = false;
    }
  }

  /// Reconciles [entry] with the server's current state for its item, then
  /// sends it (or drops it - see [PlaybackConflictResolver]) and removes it
  /// from the queue on success. Throws on failure, for [drainQueue] to
  /// record and back off on.
  ///
  /// Uses `service.api` (the raw Jellyfin client) rather than
  /// `service.sessionsPlayingXxxPost`, which would re-enqueue this same
  /// entry instead of actually sending it.
  Future<void> _sendEntry(JellyService service, AppDatabase db, PlaybackQueueEntry entry) async {
    final provenance = await db.getSetting(anilistPlaybackKey(entry.id), scope: anilistPlaybackScope);
    final capture = captureAnilistPlayback(ref, entry.eventType, entry.itemId);
    final currentProvenance = await capture?.provenance;
    final rememberAnilist = currentProvenance != null && provenance?.value == currentProvenance
        ? capture?.remember : null;
    final itemResponse = await service.usersUserIdItemsItemIdGet(itemId: entry.itemId);
    final serverUserData = itemResponse.body?.userData;

    final decision = PlaybackConflictResolver.resolve(
      queuedPositionTicks: entry.positionTicks,
      serverPositionTicks: serverUserData?.playbackPositionTicks,
      serverPlayed: serverUserData?.played ?? false,
    );

    if (!decision.shouldSend) {
      await rememberAnilist?.call();
      await db.deletePlaybackEvent(entry.id);
      await db.deleteSetting(anilistPlaybackKey(entry.id), scope: anilistPlaybackScope);
      return;
    }

    final response = switch (entry.eventType) {
      PlaybackQueueEventType.start => await service.api.sessionsPlayingPost(
          body: PlaybackStartInfo(
            itemId: entry.itemId,
            mediaSourceId: entry.itemId,
            playbackStartTimeTicks: decision.positionTicks,
            canSeek: true,
            isPaused: false,
            isMuted: false,
            volumeLevel: 100,
            playMethod: PlayMethod.directplay,
            repeatMode: RepeatMode.repeatall,
          ),
        ),
      PlaybackQueueEventType.progress => await service.api.sessionsPlayingProgressPost(
          body: PlaybackProgressInfo(
            itemId: entry.itemId,
            mediaSourceId: entry.itemId,
            positionTicks: decision.positionTicks,
            canSeek: true,
            isPaused: false,
            isMuted: false,
            volumeLevel: 100,
            playMethod: PlayMethod.directplay,
            repeatMode: RepeatMode.repeatall,
          ),
        ),
      PlaybackQueueEventType.stop => await service.api.sessionsPlayingStoppedPost(
          body: PlaybackStopInfo(
            itemId: entry.itemId,
            mediaSourceId: entry.itemId,
            positionTicks: decision.positionTicks,
          ),
        ),
    };

    if (!response.isSuccessful) {
      throw Exception('HTTP ${response.statusCode} while sending playback_queue entry ${entry.id}');
    }

    await rememberAnilist?.call();
    await db.deletePlaybackEvent(entry.id);
    await db.deleteSetting(anilistPlaybackKey(entry.id), scope: anilistPlaybackScope);
  }
}
