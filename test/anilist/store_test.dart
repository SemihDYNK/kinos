import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/models/syncing/database_item.dart';
import 'package:kinos/anilist/anilist_store.dart';
import 'package:kinos/anilist/mapping.dart';

void main() {
  late ProviderContainer container;
  late AppDatabase db;
  setUp(() {
    container = ProviderContainer();
    db = AppDatabase(
        container.read(Provider<Ref>((r) => r)), NativeDatabase.memory());
  });
  tearDown(() async {
    await db.close();
    container.dispose();
  });
  final target = AnilistTarget(
      itemId: 'same',
      title: 'Movie',
      kind: AnilistTargetKind.movie,
      ids: {'Tmdb': 128});
  test('choices survive a new store and stay isolated by scope and item',
      () async {
    final a = AnilistStore(db, 'server-A:user-A');
    await a.save(target, 164);
    expect((await AnilistStore(db, 'server-A:user-A').read(target))!.confirmed,
        isTrue);
    expect(await AnilistStore(db, 'server-A:user-B').read(target), isNull);
    expect(await AnilistStore(db, 'server-B:user-A').read(target), isNull);
    expect(
        await a.read(AnilistTarget(
            itemId: 'season', title: 'A', kind: AnilistTargetKind.season)),
        isNull);
    await a.remove(target);
    expect(await a.read(target), isNull);
  });
  test(
      'changed source IDs invalidate confirmation but retain the previous choice',
      () async {
    final store = AnilistStore(db, 'scope');
    await store.save(target, 164);
    final changed = AnilistTarget(
        itemId: 'same',
        title: 'Renamed',
        kind: AnilistTargetKind.movie,
        ids: {'Tmdb': 100});
    final stored = await store.read(changed);
    expect(stored!.id, 164);
    expect(stored.confirmed, isFalse);
  });
  test('a confirmed choice survives closing and reopening the database',
      () async {
    final directory = await Directory.systemTemp.createTemp('kinos-anilist-');
    final file = File('${directory.path}/settings.sqlite');
    final ref = container.read(Provider<Ref>((r) => r));
    final first = AppDatabase(ref, NativeDatabase(file));
    try {
      await AnilistStore(first, 'scope').save(target, 164);
    } finally {
      await first.close();
    }
    final reopened = AppDatabase(ref, NativeDatabase(file));
    try {
      final saved = await AnilistStore(reopened, 'scope').read(target);
      expect(saved!.id, 164);
      expect(saved.confirmed, isTrue);
    } finally {
      await reopened.close();
      await directory.delete(recursive: true);
    }
  });
  test('scope does not persist URL credentials or query secrets', () {
    final scope = anilistProfileScope(
        serverId: '',
        url: 'https://secret:password@server.test/jellyfin?token=private#x',
        userId: 'user');
    expect(scope, contains('server.test/jellyfin'));
    expect(scope, isNot(contains('password')));
    expect(scope, isNot(contains('private')));
  });
}
