import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/l10n/generated/app_localizations.dart';
import 'package:kinos/models/syncing/database_item.dart';
import 'package:kinos/letterboxd/letterboxd_import_controller.dart';
import 'package:kinos/letterboxd/letterboxd_import_dialog.dart';
import 'package:kinos/letterboxd/letterboxd_model.dart';
import 'package:kinos/letterboxd/letterboxd_providers.dart';
import 'package:kinos/letterboxd/letterboxd_store.dart';
import 'package:kinos/theme/app_theme.dart';

class PreviewController extends LetterboxdImportController {
  bool committed = false;
  PreviewController(LetterboxdStore store)
      : super(store: store, loadLibrary: () async => [], isCurrent: () => true);
  @override
  Future<void> prepare(Uint8List bytes) async {
    state = const LetterboxdImportState(ready: true, records: [
      LetterboxdRecord(LetterboxdFilm(
          uri: 'https://boxd.it/a', title: 'Film test', year: 2000, rating: 5))
    ]);
  }

  @override
  Future<void> commit() async {
    committed = true;
    state = const LetterboxdImportState(saved: true);
  }
}

void main() {
  testWidgets(
      'picker previews without committing, keyboard reaches actions, confirmation saves',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1100, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = ProviderContainer();
    final db = AppDatabase(
        container.read(Provider<Ref>((r) => r)), NativeDatabase.memory());
    final controller = PreviewController(LetterboxdStore(db, 'test'));
    await tester.pumpWidget(ProviderScope(
        overrides: [
          letterboxdScopeProvider.overrideWithValue('test'),
          letterboxdSnapshotProvider
              .overrideWithValue(const AsyncData(LetterboxdSnapshot())),
          letterboxdImportProvider.overrideWith((ref) => controller),
          letterboxdPickExportProvider
              .overrideWithValue(() async => Uint8List(0)),
        ],
        child: MaterialApp(
            locale: const Locale('fr'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: buildAppTheme(),
            home: const Scaffold(body: LetterboxdImportDialog()))));
    await tester.tap(find.text('Choisir le ZIP exporté'));
    await tester.pumpAndSettle();
    expect(
        find.text('1 films · 0 identifiés · 1 non identifiés'), findsOneWidget);
    expect(controller.committed, isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    expect(FocusManager.instance.primaryFocus, isNotNull);
    await tester.tap(find.text('Confirmer l’import'));
    await tester.pumpAndSettle();
    expect(controller.committed, isTrue);
    expect(find.text('Import enregistré pour ce profil.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(db.close);
    container.dispose();
  });
}
