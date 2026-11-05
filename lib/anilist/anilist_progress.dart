import 'anilist_client.dart';
import 'episode_mapping.dart';
import 'episode_store.dart';

class AnilistMappingNeeded implements Exception {
  const AnilistMappingNeeded();
}

class ProgressSnapshot {
  final int mediaId;
  final Set<int> watched;
  final int? total;
  const ProgressSnapshot(
      {required this.mediaId, required this.watched, this.total});
}

class AnilistProgressWorker {
  final EpisodeStore store;
  final int accountId;
  final AnilistClient client;
  final bool Function() isCurrent;
  final Future<ProgressSnapshot?> Function(String itemId) load;
  final void Function(String?)? onStatus;
  bool _draining = false;
  AnilistProgressWorker(
      {required this.store,
      required this.accountId,
      required this.client,
      required this.isCurrent,
      required this.load,
      this.onStatus});
  Future<void> drain() async {
    if (_draining || !isCurrent()) return;
    _draining = true;
    try {
      final jobs = await store.pending();
      for (final job in jobs) {
        if (!isCurrent()) return;
        if (job.accountId != accountId || job.nextAt.isAfter(DateTime.now())) {
          continue;
        }
        try {
          final snapshot = await load(job.itemId);
          if (!isCurrent()) return;
          if (snapshot != null) {
            final existing =
                await client.listEntry(snapshot.mediaId, accountId);
            if (!isCurrent()) return;
            final current = existing?.progress ?? 0;
            final next = contiguousProgress(current, snapshot.watched);
            // Rewatch cycles use a different progress meaning; leave them untouched.
            if (next > current &&
                existing?.status != 'REPEATING' &&
                existing?.status != 'COMPLETED') {
              final progress = snapshot.total == null
                  ? next
                  : next.clamp(0, snapshot.total!);
              final ordinary = existing == null || existing.status == 'CURRENT';
              final status = ordinary
                  ? (snapshot.total != null && progress == snapshot.total
                      ? 'COMPLETED'
                      : 'CURRENT')
                  : null;
              if (progress > current) {
                if (!isCurrent()) return;
                await client.saveProgress(snapshot.mediaId, progress,
                    status: status);
              }
            }
          }
          if (!isCurrent()) return;
          await store.acknowledge(job);
        } on Exception catch (error) {
          if (!isCurrent()) return;
          final reason = error is AnilistUnauthorized
              ? 'auth'
              : error is AnilistMappingNeeded
                  ? 'mapping'
                  : 'network';
          final delay = reason == 'auth'
              ? const Duration(days: 1)
              : reason == 'mapping'
                  // An unmapped title cannot heal by retrying hourly: back off
                  // once the user has had a few chances to answer.
                  ? (job.attempts >= 3
                      ? const Duration(days: 7)
                      : const Duration(hours: 1))
                  : Duration(
                      seconds:
                          (5 * (1 << job.attempts.clamp(0, 8))).clamp(5, 900));
          var until = DateTime.now().add(delay);
          if (error is AnilistUnavailable &&
              error.retryAt != null &&
              error.retryAt!.isAfter(until)) {
            until = error.retryAt!;
          }
          await store.defer(job, until, reason);
          onStatus?.call(reason);
        }
      }
      final remaining = (await store.pending())
          .where((job) => job.accountId == accountId)
          .map((job) => job.error)
          .toSet();
      if (isCurrent()) {
        onStatus?.call(remaining.contains('auth')
            ? 'auth'
            : remaining.contains('mapping')
                ? 'mapping'
                : remaining.contains('network')
                    ? 'network'
                    : null);
      }
    } on Exception {
      if (isCurrent()) onStatus?.call('network');
    } finally {
      _draining = false;
    }
  }
}
