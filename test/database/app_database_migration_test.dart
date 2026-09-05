import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fladder/models/syncing/database_item.dart';

import '../drift_generated/schema.dart';
import '../drift_generated/schema_v1.dart' as v1;

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
    test('v1 -> v2 arrives at the schema declared by AppDatabase today', () async {
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

    test('v1 -> v2 creates empty playback_queue, palette_cache and settings tables', () async {
      final connection = await verifier.startAt(1);
      final db = AppDatabase(_fakeRef(), connection);
      await verifier.migrateAndValidate(db, 2);

      expect(await db.select(db.playbackQueue).get(), isEmpty);
      expect(await db.select(db.paletteCache).get(), isEmpty);
      expect(await db.select(db.settings).get(), isEmpty);

      await db.close();
    });

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
      expect((await db.getSetting('brightness', scope: 'display-1'))?.value, '0.8');
      expect(await db.getSetting('brightness', scope: 'display-2'), isNull);
    });
  });
}
