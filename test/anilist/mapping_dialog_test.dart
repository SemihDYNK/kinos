import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kinos/anilist/anilist_mapping_dialog.dart';
import 'package:kinos/anilist/anilist_providers.dart';
import 'package:kinos/anilist/anilist_client.dart';
import 'package:kinos/anilist/anilist_catalog.dart';
import 'package:kinos/anilist/anilist_store.dart';
import 'package:kinos/anilist/mapping.dart';
import 'package:kinos/jellyfin/jellyfin_open_api.swagger.dart' as dto;
import 'package:kinos/models/items/movie_model.dart';
import 'package:kinos/models/syncing/database_item.dart';
import 'package:kinos/l10n/generated/app_localizations.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/widgets/shared/frosted_surface.dart';

void main() {
  testWidgets('explicit selection confirms a local link and allows removal',
      (tester) async {
    final fixture = await mount(tester);
    final store = fixture.store;
    final target = fixture.target;
    expect(find.text('Mononoke'), findsOneWidget);
    expect(await store.read(target), isNull);
    await tester.ensureVisible(find.text('Mononoke'));
    await tester.tap(find.text('Mononoke'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Search AniList'));
    await tester.tap(find.text('Search AniList'));
    await tester.pumpAndSettle();
    expect(find.text('Mononoke'), findsOneWidget);
    await tester.ensureVisible(find.text('Confirm link'));
    await tester.tap(find.text('Confirm link'));
    await tester.pumpAndSettle();
    expect((await store.read(target))!.id, 164);
    expect(find.text('Remove link'), findsOneWidget);
    await tester.ensureVisible(find.text('Remove link'));
    await tester.tap(find.text('Remove link'));
    await tester.pumpAndSettle();
    expect(await store.read(target), isNull);
    expect(tester.takeException(), isNull);
  });
  testWidgets('keyboard traversal can confirm and Escape closes the panel',
      (tester) async {
    final fixture = await mount(tester);
    await tester.ensureVisible(find.text('Mononoke'));
    await tester.tap(find.text('Mononoke'));
    await tester.pumpAndSettle();
    final confirm = Focus.of(tester.element(find.text('Confirm link')));
    var reached = false;
    for (var i = 0; i < 20; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      if (confirm.hasFocus) {
        reached = true;
        break;
      }
    }
    expect(reached, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(Focus.of(tester.element(find.text('Close'))).hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(confirm.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect((await fixture.store.read(fixture.target))!.id, 164);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(GlassDialog), findsNothing);
  });
  testWidgets('network error retains the selection and offers retry',
      (tester) async {
    var fail = false;
    await mount(tester, failing: () => fail);
    await tester.ensureVisible(find.text('Mononoke'));
    await tester.tap(find.text('Mononoke'));
    await tester.enterText(find.byType(TextField), 'Missing');
    fail = true;
    await tester.ensureVisible(find.text('Search AniList'));
    await tester.tap(find.text('Search AniList'));
    await tester.pumpAndSettle();
    expect(find.text('Mononoke'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull);
    fail = false;
    await tester.ensureVisible(find.text('Search AniList'));
    await tester.tap(find.text('Search AniList'));
    await tester.pumpAndSettle();
    expect(find.text('No results'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    expect(tester.takeException(), isNull);
  });
  testWidgets('initial network failure is not presented as no match',
      (tester) async {
    await mount(tester, failing: () => true);
    expect(find.text('No match found'), findsNothing);
    expect(find.text('AniList is unavailable. Your saved link is unchanged.'),
        findsOneWidget);
  });
  testWidgets('long titles and large text stay inside the dialog',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await mount(tester,
        title: List.filled(30, 'Very long anime title').join(' '), scale: 2);
    expect(tester.takeException(), isNull);
  });
}

Future<({AnilistStore store, AnilistTarget target})> mount(WidgetTester tester,
    {String title = 'Movie',
    double scale = 1,
    bool Function()? failing}) async {
  final fail = failing ?? () => false;
  final container = ProviderContainer();
  final db = AppDatabase(
      container.read(Provider<Ref>((r) => r)), NativeDatabase.memory());
  addTearDown(() => container.dispose());
  addTearDown(db.close);
  final item = MovieModel.fromBaseDto(
      dto.BaseItemDto(id: 'm', name: title, providerIds: {'AniList': '164'}),
      null);
  final target = AnilistTarget(
      itemId: 'm',
      title: title,
      kind: AnilistTargetKind.movie,
      ids: {'AniList': '164'});
  final store = AnilistStore(db, 'test');
  final client = AnilistClient(
      interval: Duration.zero,
      client: MockClient((r) async {
        if (fail()) return http.Response('', 500);
        final q = jsonDecode(r.body)['query'] as String;
        return http.Response(
            q.contains('Page(')
                ? '{"data":{"Page":{"media":[]}}}'
                : '{"data":{"Media":{"id":164,"type":"ANIME","title":{"english":"Mononoke"},"format":"MOVIE"}}}',
            200);
      }));
  await tester.pumpWidget(ProviderScope(
      overrides: [
        anilistMappingProvider(item).overrideWith((ref) =>
            AnilistMappingController(
                target: target,
                client: client,
                catalog: AnilistCatalog(
                    read: () async => null,
                    write: (_) async {},
                    fetch: () async => '[]'),
                store: store,
                isCurrent: () => true))
      ],
      child: MaterialApp(
          theme: buildAppTheme(),
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
              builder: (context) => Scaffold(
                  body: TextButton(
                      onPressed: () => showAnilistMappingDialog(context, item),
                      child: const Text('Open')))))));
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  return (store: store, target: target);
}
