import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kinos/models/syncing/database_item.dart';

/// See app_database_migration_test.dart: AppDatabase takes a [Ref] only to
/// read the logged-in account's id for its query helpers - not exercised by
/// these tests, which insert rows directly instead.
Ref _fakeRef() {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  return container.read(Provider<Ref>((ref) => ref));
}

void main() {
  group('playback_queue DAO', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase(_fakeRef(), NativeDatabase.memory()));
    tearDown(() => db.close());

    test('a failed send records attempts and lastError without deleting the entry', () async {
      final id = await db.into(db.playbackQueue).insert(
            PlaybackQueueCompanion.insert(
              userId: 'user-1',
              itemId: 'item-1',
              eventType: PlaybackQueueEventType.progress,
              positionTicks: const Value(120000),
            ),
          );

      await db.incrementPlaybackEventAttempts(id);
      await db.recordPlaybackEventFailure(id, 'SocketException: Connection refused');

      final row = await (db.select(db.playbackQueue)..where((tbl) => tbl.id.equals(id))).getSingle();
      expect(row.attempts, 1);
      expect(row.lastError, 'SocketException: Connection refused');
      // A failure only records why it failed - it never touches the
      // position that still needs to be reported.
      expect(row.positionTicks, 120000);
    });

    test('repeated failures accumulate attempts', () async {
      final id = await db.into(db.playbackQueue).insert(
            PlaybackQueueCompanion.insert(
              userId: 'user-1',
              itemId: 'item-1',
              eventType: PlaybackQueueEventType.stop,
            ),
          );

      await db.incrementPlaybackEventAttempts(id);
      await db.incrementPlaybackEventAttempts(id);
      await db.incrementPlaybackEventAttempts(id);

      final row = await (db.select(db.playbackQueue)..where((tbl) => tbl.id.equals(id))).getSingle();
      expect(row.attempts, 3);
    });

    test('a successful send deletes the entry', () async {
      final id = await db.into(db.playbackQueue).insert(
            PlaybackQueueCompanion.insert(
              userId: 'user-1',
              itemId: 'item-1',
              eventType: PlaybackQueueEventType.start,
            ),
          );

      await db.deletePlaybackEvent(id);

      expect(await db.select(db.playbackQueue).get(), isEmpty);
    });

    test('incrementing or recording a failure for a since-deleted entry is a no-op, not an error', () async {
      final id = await db.into(db.playbackQueue).insert(
            PlaybackQueueCompanion.insert(
              userId: 'user-1',
              itemId: 'item-1',
              eventType: PlaybackQueueEventType.start,
            ),
          );
      await db.deletePlaybackEvent(id);

      await db.incrementPlaybackEventAttempts(id);
      await db.recordPlaybackEventFailure(id, 'should not resurrect the row');

      expect(await db.select(db.playbackQueue).get(), isEmpty);
    });
  });
}
