import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/anilist/episode_mapping.dart';
import 'package:kinos/anilist/episode_store.dart';
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
  test('manual plans are scoped, fingerprinted and retain all parts', () async {
    final store = EpisodeStore(db, 'p');
    final range = EpisodeRange(
        season: 2, first: 25, last: 48, mediaId: 2, anilistFirst: 1);
    await store.savePlan('series', 'ids', [range]);
    expect((await store.readPlan('series', 'ids'))!.ranges.single.first, 25);
    expect(await store.readPlan('series', 'changed'), isNull);
    expect(await store.hasPlan('series'), isTrue);
    expect(
        (await store.readPlan('series', 'changed', allowStale: true))!.ranges,
        hasLength(1));
    expect(await EpisodeStore(db, 'other').readPlan('series', 'ids'), isNull);
  });
  test('outbox coalesces but an old acknowledgement cannot erase new work',
      () async {
    final store = EpisodeStore(db, 'p');
    await store.enqueue('item', 1);
    final first = (await store.pending()).single;
    await store.enqueue('item', 1);
    await store.acknowledge(first);
    final current = (await store.pending()).single;
    expect(current.revision, greaterThan(first.revision));
    await store.defer(
        current, DateTime.now().add(const Duration(minutes: 1)), 'network');
    expect((await store.pending()).single.attempts, 1);
    expect((await store.pending()).single.error, 'network');
    await store.clearAccount(1);
    expect(await store.pending(), isEmpty);
  });
}
