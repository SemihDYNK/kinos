import 'dart:convert';
import 'package:kinos/models/syncing/database_item.dart';
import 'anilist_store.dart';
import 'episode_mapping.dart';

class AnilistJob {
  final String key, raw, itemId;
  final int revision, accountId, attempts;
  final DateTime nextAt;
  final String? error;
  const AnilistJob(this.key, this.raw, this.itemId, this.revision,
      this.accountId, this.attempts, this.nextAt, this.error);
}

class EpisodeStore {
  final AppDatabase db;
  final String scope;
  EpisodeStore(this.db, String profileScope)
      : scope = '$profileScope:episodes:v1';
  Future<EpisodePlan?> readPlan(String seriesId, String fingerprint,
      {bool allowStale = false}) async {
    final row = await db.getSetting('ranges:$seriesId', scope: scope);
    if (row == null) return null;
    try {
      final j = jsonDecode(row.value) as Map<String, dynamic>;
      if ((!allowStale && j['fingerprint'] != fingerprint) ||
          j['version'] != 1) {
        return null;
      }
      return EpisodePlan.manual([
        for (final r in j['ranges'] as List)
          EpisodeRange.fromJson(r as Map<String, dynamic>)
      ]);
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    } on ArgumentError {
      return null;
    }
  }

  Future<bool> hasPlan(String seriesId) async =>
      await db.getSetting('ranges:$seriesId', scope: scope) != null;
  Future<void> savePlan(
      String seriesId, String fingerprint, List<EpisodeRange> ranges,
      {bool Function()? isCurrent}) async {
    EpisodePlan.manual(ranges);
    await db.transaction(() async {
      _check(isCurrent);
      await db.setSetting(
          'ranges:$seriesId',
          jsonEncode({
            'version': 1,
            'fingerprint': fingerprint,
            'ranges': [for (final r in ranges) r.toJson()]
          }),
          scope: scope);
      _check(isCurrent);
    });
  }

  void _check(bool Function()? current) {
    if (current != null && !current()) throw const AnilistScopeChanged();
  }

  Future<void> enqueue(String itemId, int accountId,
      {bool Function()? isCurrent}) async {
    if (itemId.isEmpty || accountId <= 0) throw ArgumentError('Invalid job');
    await db.transaction(() async {
      _check(isCurrent);
      final key = 'job:$accountId:$itemId';
      final previous = await db.getSetting(key, scope: scope);
      final revision = previous == null
          ? 0
          : (jsonDecode(previous.value) as Map)['revision'] as int;
      await db.setSetting(
          key,
          jsonEncode({
            'itemId': itemId,
            'accountId': accountId,
            'revision': revision + 1,
            'attempts': 0,
            'nextAt': DateTime.now().toUtc().toIso8601String()
          }),
          scope: scope);
      _check(isCurrent);
    });
  }

  Future<List<AnilistJob>> pending() async {
    final rows = await db.getSettingsForScope(scope).get();
    final result = <AnilistJob>[];
    for (final row in rows.where((r) => r.key.startsWith('job:'))) {
      try {
        final j = jsonDecode(row.value) as Map<String, dynamic>;
        result.add(AnilistJob(
            row.key,
            row.value,
            j['itemId'] as String,
            j['revision'] as int,
            j['accountId'] as int,
            j['attempts'] as int,
            DateTime.parse(j['nextAt'] as String),
            j['error'] as String?));
      } on FormatException {
        continue;
      } on TypeError {
        continue;
      }
    }
    return result;
  }

  Future<void> acknowledge(AnilistJob job) => db.transaction(() async {
        if ((await db.getSetting(job.key, scope: scope))?.value == job.raw) {
          await db.deleteSetting(job.key, scope: scope);
        }
      });
  Future<void> defer(AnilistJob job, DateTime until, String error) =>
      db.transaction(() async {
        if ((await db.getSetting(job.key, scope: scope))?.value != job.raw) {
          return;
        }
        final j = jsonDecode(job.raw) as Map<String, dynamic>;
        j.addAll({
          'attempts': job.attempts + 1,
          'nextAt': until.toUtc().toIso8601String(),
          'error': error
        });
        await db.setSetting(job.key, jsonEncode(j), scope: scope);
      });
  Future<void> retryNow(int accountId) => db.transaction(() async {
        for (final job in await pending()) {
          if (job.accountId != accountId) continue;
          final j = jsonDecode(job.raw) as Map<String, dynamic>;
          j['nextAt'] = DateTime.now().toUtc().toIso8601String();
          await db.setSetting(job.key, jsonEncode(j), scope: scope);
        }
      });
  Future<void> clearAccount(int accountId) => db.transaction(() async {
        for (final job in await pending()) {
          if (job.accountId == accountId) {
            await db.deleteSetting(job.key, scope: scope);
          }
        }
      });
}
