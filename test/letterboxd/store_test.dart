import 'dart:async';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/models/syncing/database_item.dart';
import 'package:kinos/letterboxd/letterboxd_model.dart';
import 'package:kinos/letterboxd/letterboxd_store.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  setUp(() {
    container = ProviderContainer();
    db = AppDatabase(
        container.read(Provider<Ref>((r) => r)), NativeDatabase.memory());
  });
  tearDown(() async {
    await db.close();
    container.dispose();
  });
  final snapshot =
      LetterboxdSnapshot(updatedAt: DateTime.utc(2026), records: const [
    LetterboxdRecord(LetterboxdFilm(
        uri: 'https://boxd.it/a', title: 'A', year: 2000, rating: 4))
  ]);
  test('import is durable, scoped, atomically replaced and removable',
      () async {
    final a = LetterboxdStore(db, 'A');
    await a.save(snapshot);
    expect((await LetterboxdStore(db, 'A').read()).records.length, 1);
    expect((await LetterboxdStore(db, 'B').read()).records, isEmpty);
    await a.save(snapshot);
    expect((await a.read()).records.length, 1);
    await a.clear();
    expect((await a.read()).records, isEmpty);
    expect((await a.read()).updatedAt, isNotNull);
  });
  test('late profile change rolls back the transaction', () async {
    final a = LetterboxdStore(db, 'A');
    await a.save(snapshot);
    var calls = 0;
    await expectLater(
        a.save(const LetterboxdSnapshot(), isCurrent: () => ++calls == 1),
        throwsA(isA<LetterboxdCancelled>()));
    expect((await a.read()).records.length, 1);
  });
  test(
      'unchanged import does not emit on recommendation or other-profile writes',
      () async {
    final store = LetterboxdStore(db, 'A');
    await store.save(snapshot);
    final first = Completer<void>();
    final events = <LetterboxdSnapshot>[];
    final changed = Completer<void>();
    final sub = store.watch().listen((value) {
      events.add(value);
      if (!first.isCompleted) first.complete();
      if (events.length == 2 && !changed.isCompleted) changed.complete();
    });
    try {
      await first.future;
      await db.setSetting('recommendation_last_computed_at_v2', 'now',
          scope: 'recommendations:A');
      await db.setSetting('snapshot', '{}', scope: 'B');
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(events.length, 1);
      await store.clear();
      await changed.future.timeout(const Duration(seconds: 2));
      expect(events.last.records, isEmpty);
    } finally {
      await sub.cancel();
    }
  });
  test('profile scope never includes URL secrets', () {
    final scope = letterboxdProfileScope(
        serverId: '', url: 'https://u:secret@test/?token=secret', userId: 'A');
    expect(scope, contains('test'));
    expect(scope, isNot(contains('secret')));
  });
}
