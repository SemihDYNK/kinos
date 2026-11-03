import 'dart:async';
import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kinos/anilist/anilist_client.dart';
import 'package:kinos/anilist/anilist_catalog.dart';
import 'package:kinos/anilist/anilist_providers.dart';
import 'package:kinos/anilist/anilist_store.dart';
import 'package:kinos/anilist/mapping.dart';
import 'package:kinos/models/syncing/database_item.dart';

void main() {
  late ProviderContainer c;
  late AppDatabase db;
  setUp(() {
    c = ProviderContainer();
    db = AppDatabase(c.read(Provider<Ref>((r) => r)), NativeDatabase.memory());
  });
  tearDown(() async {
    await db.close();
    c.dispose();
  });
  final t = AnilistTarget(
      itemId: 'm',
      title: 'Movie',
      kind: AnilistTargetKind.movie,
      ids: {'Anilist': '164'});
  AnilistCatalog catalog() => AnilistCatalog(
      read: () async => null,
      write: (_) async {},
      fetch: () async => '[{"anilist_id":164}]');
  AnilistClient client({Completer<void>? gate}) => AnilistClient(
      interval: Duration.zero,
      client: MockClient((r) async {
        if (gate != null) await gate.future;
        final body = jsonDecode(r.body);
        final id = body['variables']['id'] ?? 164;
        return http.Response(
            jsonEncode({
              'data': {
                'Media': {
                  'id': id,
                  'type': 'ANIME',
                  'title': {'english': 'Anime'}
                }
              }
            }),
            200);
      }));
  test('direct metadata is verified without fetching the catalog', () async {
    var downloads = 0;
    final index = AnilistCatalog(
        read: () async => null,
        write: (_) async {},
        fetch: () async {
          downloads++;
          return '[{"anilist_id":164}]';
        });
    final controller = AnilistMappingController(
        target: t,
        client: client(),
        catalog: index,
        store: AnilistStore(db, 'a'),
        isCurrent: () => true);
    addTearDown(controller.dispose);
    await controller.resolve();
    expect(controller.state.match.status, AnilistMatchStatus.exact);
    expect(downloads, 0);
  });
  test('closing while resolving cannot update disposed state', () async {
    final gate = Completer<void>();
    final controller = AnilistMappingController(
        target: t,
        client: client(gate: gate),
        catalog: catalog(),
        store: AnilistStore(db, 'a'),
        isCurrent: () => true);
    final pending = controller.resolve();
    controller.dispose();
    gate.complete();
    await pending;
  });
  test('a profile switch prevents confirmation and old-profile persistence',
      () async {
    var active = true;
    final store = AnilistStore(db, 'a');
    final gate = Completer<void>();
    final controller = AnilistMappingController(
        target: t,
        client: client(gate: gate),
        catalog: catalog(),
        store: store,
        isCurrent: () => active);
    addTearDown(controller.dispose);
    controller.select(164);
    final pending = controller.confirm(164);
    active = false;
    gate.complete();
    await pending;
    expect(await store.read(t), isNull);
  });
  test('successful search cannot confirm an invisible prior selection',
      () async {
    var fail = false;
    final controller = AnilistMappingController(
        target: t,
        client: AnilistClient(
            interval: Duration.zero,
            client: MockClient((_) async => fail
                ? http.Response('', 500)
                : http.Response('{"data":{"Page":{"media":[]}}}', 200))),
        catalog: catalog(),
        store: AnilistStore(db, 'a'),
        isCurrent: () => true);
    addTearDown(controller.dispose);
    controller.select(164);
    fail = true;
    await controller.search('Unknown');
    expect(controller.state.selectedId, 164);
    fail = false;
    await controller.search('Unknown');
    expect(controller.state.selectedId, isNull);
  });
  test('a changed manual choice needs confirmation instead of silently winning',
      () async {
    final store = AnilistStore(db, 'a');
    await store.save(
        AnilistTarget(
            itemId: 'm',
            title: 'Old',
            kind: AnilistTargetKind.movie,
            ids: {'Anilist': '100'}),
        100);
    final controller = AnilistMappingController(
        target: t,
        client: client(),
        catalog: catalog(),
        store: store,
        isCurrent: () => true);
    addTearDown(controller.dispose);
    await controller.resolve();
    expect(controller.state.match.status, AnilistMatchStatus.needsConfirmation);
    expect(controller.state.match.reason, AnilistMatchReason.changedIds);
  });
}
