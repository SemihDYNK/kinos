import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kinos/models/syncing/database_item.dart';

import '../drift_generated/schema.dart';
import '../drift_generated/schema_v1.dart' as v1;
import '../drift_generated/schema_v2.dart' as v2;
import '../drift_generated/schema_v3.dart' as v3;

/// Exposes the [Ref] backing a [ProviderContainer], since [AppDatabase]
/// takes a [Ref] (it reads the active user id off [userProvider] for its
/// query helpers, none of which are exercised by these migration tests).
final _refProvider = Provider<Ref>((ref) => ref);

Ref _fakeRef() {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  return container.read(_refProvider);
}

void main() {
  final verifier = SchemaVerifier(GeneratedHelper());

  group('AppDatabase migrations', () {
    test('v1 -> v2 arrives at the schema declared by AppDatabase today',
        () async {
      final connection = await verifier.startAt(1);
      final db = AppDatabase(_fakeRef(), connection);
      await verifier.migrateAndValidate(db, 2);
      await db.close();
    });

    test('v1 -> v2 preserves existing database_items rows', () async {
      // schemaAt(1).newConnection() hands out independent connections to the
      // same underlying (v1-shaped) database, so each GeneratedDatabase below
      // can be opened and closed in turn instead of sharing one live
      // instance - see https://drift.simonbinder.eu/docs/migrations/tests/.
      final schema = await verifier.schemaAt(1);

      final oldDb = v1.DatabaseAtV1(schema.newConnection());
      await oldDb.into(oldDb.databaseItems).insert(
            v1.DatabaseItemsCompanion.insert(
              userId: 'user-1',
              id: 'item-1',
            ),
          );
      await oldDb.close();

      final db = AppDatabase(_fakeRef(), schema.newConnection());
      await verifier.migrateAndValidate(db, 2);
      await db.close();

      final migratedDb = AppDatabase(_fakeRef(), schema.newConnection());
      final rows = await migratedDb.select(migratedDb.databaseItems).get();
      expect(rows, hasLength(1));
      expect(rows.single.id, 'item-1');
      expect(rows.single.userId, 'user-1');
      await migratedDb.close();
    });

    test(
        'v1 -> v2 creates empty playback_queue, palette_cache and settings tables',
        () async {
      final connection = await verifier.startAt(1);
      final db = AppDatabase(_fakeRef(), connection);
      await verifier.migrateAndValidate(db, 2);

      expect(await db.select(db.playbackQueue).get(), isEmpty);
      expect(await db.select(db.paletteCache).get(), isEmpty);
      expect(await db.select(db.settings).get(), isEmpty);

      await db.close();
    });

    test('v2 -> v3 arrives at the schema declared by AppDatabase today',
        () async {
      final connection = await verifier.startAt(2);
      final db = AppDatabase(_fakeRef(), connection);
      await verifier.migrateAndValidate(db, 3);
      await db.close();
    });

    test('v2 -> v3 creates an empty recommendation_cache_entries table',
        () async {
      final connection = await verifier.startAt(2);
      final db = AppDatabase(_fakeRef(), connection);
      await verifier.migrateAndValidate(db, 3);

      expect(await db.select(db.recommendationCacheEntries).get(), isEmpty);

      await db.close();
    });

    for (final version in [1, 2, 3]) {
      test('v$version -> v4 adds discovery cache and preserves existing data',
          () async {
        final schema = await verifier.schemaAt(version);
        final GeneratedDatabase old = switch (version) {
          1 => v1.DatabaseAtV1(schema.newConnection()),
          2 => v2.DatabaseAtV2(schema.newConnection()),
          _ => v3.DatabaseAtV3(schema.newConnection()),
        };
        await old.customStatement(
          'INSERT INTO database_items (user_id, id, sort_name) VALUES (?, ?, ?)',
          ['profile', 'existing', 'Preserved'],
        );
        await old.close();
        final db = AppDatabase(_fakeRef(), schema.newConnection());
        await verifier.migrateAndValidate(db, 4);
        expect(await db.select(db.discoveryCacheEntries).get(), isEmpty);
        final rows = await db.select(db.databaseItems).get();
        expect(rows.single.sortName, 'Preserved');
        await db.close();
      });
    }

    test('a fresh install (onCreate) can read/write all four tables', () async {
      final db = AppDatabase(_fakeRef(), NativeDatabase.memory());
      addTearDown(db.close);

      // Insert directly rather than via enqueuePlaybackEvent: that helper
      // stamps the row with AppDatabase.userId, which reads the logged-in
      // account off userProvider - unrelated plumbing this smoke test
      // shouldn't need to fake out.
      await db.into(db.playbackQueue).insert(
            PlaybackQueueCompanion.insert(
              userId: 'user-1',
              itemId: 'item-1',
              eventType: PlaybackQueueEventType.start,
            ),
          );
      final pending = await db.select(db.playbackQueue).get();
      expect(pending, hasLength(1));
      expect(pending.single.eventType, PlaybackQueueEventType.start);

      await db.savePalette('item-1', 0xFF112233);
      expect((await db.getPalette('item-1'))?.argb, 0xFF112233);

      await db.setSetting('brightness', '0.8', scope: 'display-1');
      expect((await db.getSetting('brightness', scope: 'display-1'))?.value,
          '0.8');
      expect(await db.getSetting('brightness', scope: 'display-2'), isNull);
    });
  });

  group('AppDatabase.recommendationCache', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(_fakeRef(), NativeDatabase.memory());
      addTearDown(db.close);
    });

    RecommendationCacheEntriesCompanion entry(String userId, int position,
            {String title = 'A film',
            RecommendationRowKind rowKind = RecommendationRowKind.forYou}) =>
        RecommendationCacheEntriesCompanion.insert(
          userId: userId,
          rowKind: rowKind,
          position: position,
          source: RecommendationEntrySource.jellyfin,
          jellyfinItemId: Value('item-$position'),
          title: title,
        );

    test('replaceRecommendationCache stores entries in position order',
        () async {
      await db.replaceRecommendationCache(
        userId: 'user-1',
        rowKind: RecommendationRowKind.forYou,
        entries: [entry('user-1', 1), entry('user-1', 0)],
      );

      final rows = await db
          .getRecommendationCache(
              userId: 'user-1', rowKind: RecommendationRowKind.forYou)
          .get();

      expect(rows.map((r) => r.position), [0, 1]);
    });

    test('replaceRecommendationCache replaces, never accumulates', () async {
      await db.replaceRecommendationCache(
        userId: 'user-1',
        rowKind: RecommendationRowKind.forYou,
        entries: [entry('user-1', 0, title: 'Old')],
      );
      await db.replaceRecommendationCache(
        userId: 'user-1',
        rowKind: RecommendationRowKind.forYou,
        entries: [entry('user-1', 0, title: 'New')],
      );

      final rows = await db
          .getRecommendationCache(
              userId: 'user-1', rowKind: RecommendationRowKind.forYou)
          .get();

      expect(rows, hasLength(1));
      expect(rows.single.title, 'New');
    });

    test(
        'a cache written for one Jellyfin user is never returned for another '
        '— the cross-profile leak this scoping exists to prevent', () async {
      await db.replaceRecommendationCache(
        userId: 'user-1',
        rowKind: RecommendationRowKind.forYou,
        entries: [entry('user-1', 0, title: 'User 1 pick')],
      );
      await db.replaceRecommendationCache(
        userId: 'user-2',
        rowKind: RecommendationRowKind.forYou,
        entries: [entry('user-2', 0, title: 'User 2 pick')],
      );

      final user1Rows = await db
          .getRecommendationCache(
              userId: 'user-1', rowKind: RecommendationRowKind.forYou)
          .get();
      final user2Rows = await db
          .getRecommendationCache(
              userId: 'user-2', rowKind: RecommendationRowKind.forYou)
          .get();

      expect(user1Rows.map((r) => r.title), ['User 1 pick']);
      expect(user2Rows.map((r) => r.title), ['User 2 pick']);
    });

    test('replacing one user\'s cache never touches another user\'s rows',
        () async {
      await db.replaceRecommendationCache(
        userId: 'user-1',
        rowKind: RecommendationRowKind.forYou,
        entries: [entry('user-1', 0)],
      );
      await db.replaceRecommendationCache(
        userId: 'user-2',
        rowKind: RecommendationRowKind.forYou,
        entries: [entry('user-2', 0)],
      );

      // Remplace le cache de user-1 par une liste vide (ex. calcul frais
      // sans candidat) — celui de user-2 doit rester intact.
      await db.replaceRecommendationCache(
        userId: 'user-1',
        rowKind: RecommendationRowKind.forYou,
        entries: [],
      );

      final user2Rows = await db
          .getRecommendationCache(
              userId: 'user-2', rowKind: RecommendationRowKind.forYou)
          .get();
      expect(user2Rows, hasLength(1));
    });

    test('a cache entry within maxAge is returned', () async {
      final now = DateTime(2025, 6, 15);
      await db.into(db.recommendationCacheEntries).insert(
            entry('user-1', 0).copyWith(
              capturedAt: Value(now.subtract(const Duration(days: 3))),
            ),
          );

      final rows = await db
          .getRecommendationCache(
            userId: 'user-1',
            rowKind: RecommendationRowKind.forYou,
            now: now,
          )
          .get();

      expect(rows, hasLength(1));
    });

    test(
        'a cache entry older than maxAge is not returned — a cache from '
        'three months ago is worth less than nothing', () async {
      final now = DateTime(2025, 6, 15);
      await db.into(db.recommendationCacheEntries).insert(
            entry('user-1', 0).copyWith(
              capturedAt: Value(now.subtract(const Duration(days: 90))),
            ),
          );

      final rows = await db
          .getRecommendationCache(
            userId: 'user-1',
            rowKind: RecommendationRowKind.forYou,
            now: now,
          )
          .get();

      expect(rows, isEmpty);
    });

    test('maxAge is configurable, not hardcoded to the default week', () async {
      final now = DateTime(2025, 6, 15);
      await db.into(db.recommendationCacheEntries).insert(
            entry('user-1', 0).copyWith(
              capturedAt: Value(now.subtract(const Duration(days: 3))),
            ),
          );

      final rows = await db
          .getRecommendationCache(
            userId: 'user-1',
            rowKind: RecommendationRowKind.forYou,
            maxAge: const Duration(days: 1),
            now: now,
          )
          .get();

      expect(rows, isEmpty,
          reason: 'un plafond d\'un jour doit rejeter une entrée de 3 jours');
    });

    test('an entry for a different row kind is never returned', () async {
      await db.replaceRecommendationCache(
        userId: 'user-1',
        rowKind: RecommendationRowKind.setAside,
        entries: [entry('user-1', 0, rowKind: RecommendationRowKind.setAside)],
      );

      final rows = await db
          .getRecommendationCache(
              userId: 'user-1', rowKind: RecommendationRowKind.forYou)
          .get();

      expect(rows, isEmpty);
    });
  });
}
