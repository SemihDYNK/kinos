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
    // La fenêtre est ouverte : l'aperçu attend sa confirmation.
    c.attachView();
    await c.prepare(bytes);
    expect(c.state.ready, isTrue);
    expect(c.state.records.length, 1);
    expect(c.state.records.single.work, isNull);
    expect((await store.read()).records, isEmpty);
    await c.commit();
    expect((await store.read()).records.length, 1);
  });
  test('closed window: the import goes on and saves itself', () async {
    final c = LetterboxdImportController(
        store: store, loadLibrary: () async => [], isCurrent: () => true);
    addTearDown(c.dispose);
    c.attachView();
    final job = c.prepare(bytes);
    c.detachView();
    await job;
    expect(c.state.saved, isTrue);
    expect(c.state.total, 1);
    expect((await store.read()).records.length, 1);
  });
  test('optionally marks library films played at their last viewing', () async {
    final marked = <(String, DateTime)>[];
    final c = LetterboxdImportController(
        store: store,
        loadLibrary: () async => [
              const LetterboxdWork(
                  title: 'A', year: 2000, jellyfinId: 'j1', traits: [])
            ],
        isCurrent: () => true,
        markPlayed: (films) async {
          marked.addAll(films);
          return films.length;
        });
    addTearDown(c.dispose);
    c.attachView();
    await c.prepare(exportZip({
      'diary.csv':
          'Date,Name,Year,Letterboxd URI,Rating,Rewatch,Tags,Watched Date\n'
              '2026-01-02,A,2000,https://boxd.it/a,4,,,2026-01-01\n'
    }));
    await c.commit();
    expect(marked, isEmpty, reason: 'off by default');
    c.markPlayedInJellyfin = true;
    await c.prepare(exportZip({
      'diary.csv':
          'Date,Name,Year,Letterboxd URI,Rating,Rewatch,Tags,Watched Date\n'
              '2026-01-02,A,2000,https://boxd.it/a,4,,,2026-01-01\n'
    }));
    await c.commit();
    expect(marked, [('j1', DateTime(2026, 1, 1))]);
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
