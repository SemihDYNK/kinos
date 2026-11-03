import 'dart:async';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/models/syncing/database_item.dart';
import 'package:kinos/letterboxd/letterboxd_model.dart';
import 'package:kinos/letterboxd/letterboxd_store.dart';
import 'package:kinos/letterboxd/letterboxd_import_controller.dart';
import 'parser_test.dart' show exportZip;

void main() {
  late ProviderContainer container;
  late AppDatabase db;
  late LetterboxdStore store;
  setUp(() {
    container = ProviderContainer();
    db = AppDatabase(
        container.read(Provider<Ref>((r) => r)), NativeDatabase.memory());
    store = LetterboxdStore(db, 'a');
  });
  tearDown(() async {
    await db.close();
    container.dispose();
  });
  final bytes = exportZip({
    'watched.csv':
        'Date,Name,Year,Letterboxd URI\n2026-01-01,A,2000,https://boxd.it/a\n'
  });
  test('a preview never writes until confirmed; offline records remain visible',
      () async {
    final c = LetterboxdImportController(
        store: store, loadLibrary: () async => [], isCurrent: () => true);
    addTearDown(c.dispose);
    await c.prepare(bytes);
    expect(c.state.ready, isTrue);
    expect(c.state.records.length, 1);
    expect(c.state.records.single.work, isNull);
    expect((await store.read()).records, isEmpty);
    await c.commit();
    expect((await store.read()).records.length, 1);
  });
  test('cancelled library request cannot install a late preview or save',
      () async {
    final request = Completer<List<LetterboxdWork>>();
    final c = LetterboxdImportController(
        store: store, loadLibrary: () => request.future, isCurrent: () => true);
    addTearDown(c.dispose);
    final job = c.prepare(bytes);
    while (!c.state.matching) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    c.cancel();
    request.complete([]);
    await job;
    expect(c.state.ready, isFalse);
    await c.commit();
    expect((await store.read()).records, isEmpty);
  });
  test('failed archive preserves the previous import', () async {
    await store.save(
        LetterboxdSnapshot(updatedAt: DateTime.now(), records: const [
      LetterboxdRecord(LetterboxdFilm(uri: 'https://boxd.it/old', title: 'Old'))
    ]));
    final c = LetterboxdImportController(
        store: store, loadLibrary: () async => [], isCurrent: () => true);
    addTearDown(c.dispose);
    await c.prepare(exportZip({'watchlist.csv': 'ignored'}));
    expect(c.state.error, 'file');
    expect((await store.read()).records.single.film.title, 'Old');
  });
}
