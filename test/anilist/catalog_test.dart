import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/anilist/anilist_catalog.dart';
import 'package:kinos/anilist/mapping.dart';

const valid = '[{"anilist_id":164,"themoviedb_id":{"movie":[128]}}]';
void main() {
  test('shares a single load and serves a fresh cache', () async {
    var downloads = 0;
    String? stored;
    DateTime? date;
    final now = DateTime(2026);
    final c = AnilistCatalog(
        read: () async =>
            stored == null ? null : CatalogSnapshot(stored!, date!),
        write: (s) async {
          stored = s.json;
          date = s.fetchedAt;
        },
        fetch: () async {
          downloads++;
          return valid;
        },
        clock: () => now);
    final result = await Future.wait([c.load(), c.load()]);
    expect(identical(result[0], result[1]), isTrue);
    expect(downloads, 1);
    await c.load();
    expect(downloads, 1);
  });
  test('an invalid refresh preserves last valid data and is never written',
      () async {
    var writes = 0;
    final c = AnilistCatalog(
        read: () async => CatalogSnapshot(valid, DateTime(2000)),
        write: (_) async {
          writes++;
        },
        fetch: () async => '{}');
    final index = await c.load();
    expect(writes, 0);
    expect(
        resolveAnilistTarget(
                AnilistTarget(
                    itemId: 'a',
                    title: 'A',
                    kind: AnilistTargetKind.movie,
                    ids: {'Tmdb': 128}),
                index)
            .candidates
            .single
            .id,
        164);
  });
  test('missing and corrupt data are errors, not an empty successful index',
      () async {
    final c = AnilistCatalog(
        read: () async => null, write: (_) async {}, fetch: () async => '{}');
    await expectLater(c.load(), throwsA(isA<Exception>()));
  });
  test('an oversized catalog is rejected before parsing or writing', () async {
    var writes = 0;
    final catalog = AnilistCatalog(
        read: () async => null,
        write: (_) async {
          writes++;
        },
        fetch: () async => ' ' * (32 * 1024 * 1024 + 1));
    await expectLater(
        catalog.load(),
        throwsA(isA<FormatException>()
            .having((e) => e.message, 'message', contains('too large'))));
    expect(writes, 0);
  });
}
