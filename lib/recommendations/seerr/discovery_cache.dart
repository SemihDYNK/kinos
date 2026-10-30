import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:kinos/models/syncing/database_item.dart';

class DiscoveryCache {
  final AppDatabase db;
  final String scope;
  final Duration maxAge;
  final DateTime Function() now;
  DiscoveryCache(this.db, this.scope, this.maxAge, {DateTime Function()? clock})
      : now = clock ?? DateTime.now;

  Future<Map<String, dynamic>?> read(String key) async {
    final time = now();
    final row = await (db.select(db.discoveryCacheEntries)
          ..where((t) =>
              t.scope.equals(scope) &
              t.cacheKey.equals(key) &
              t.expiresAt.isBiggerThanValue(time) &
              t.capturedAt.isBiggerThanValue(time.subtract(maxAge))))
        .getSingleOrNull();
    if (row == null) return null;
    try {
      return jsonDecode(row.payload) as Map<String, dynamic>;
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  Future<void> write(String key, Map<String, dynamic> payload,
      {Duration? ttl}) async {
    final time = now();
    await db.into(db.discoveryCacheEntries).insertOnConflictUpdate(
        DiscoveryCacheEntriesCompanion.insert(
            scope: scope,
            cacheKey: key,
            payload: jsonEncode(payload),
            capturedAt: time,
            expiresAt: time.add(ttl ?? maxAge)));
  }

  Future<void> prune() async {
    await (db.delete(db.discoveryCacheEntries)
          ..where((t) =>
              t.scope.equals(scope) & t.expiresAt.isSmallerThanValue(now())))
        .go();
  }
}
