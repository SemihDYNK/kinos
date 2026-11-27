import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kinos/letterboxd/letterboxd_import_controller.dart';
import 'package:kinos/letterboxd/letterboxd_matching.dart';
import 'package:kinos/letterboxd/letterboxd_model.dart';
import 'package:kinos/letterboxd/letterboxd_store.dart';
import 'package:kinos/models/syncing/database_item.dart';
import 'package:kinos/recommendations/models/trait.dart';

LetterboxdWork work(String title, int year,
        {String? jellyfinId, int? tmdbId, List<String> aliases = const []}) =>
    LetterboxdWork(
        title: title,
        year: year,
        jellyfinId: jellyfinId,
        tmdbId: tmdbId,
        aliases: aliases,
        traits: [trait(TraitKind.genre, 'Drama')]);

void main() {
  const film = LetterboxdFilm(
      uri: 'https://boxd.it/a', title: 'Perfect Blue', year: 1997);

  test('a film dated differently is matched to the closest same title', () {
    // Un an d'écart.
    expect(
        closeLetterboxdMatch(film, [work('Perfect Blue', 1998, tmdbId: 1)])
            ?.tmdbId,
        1);
    // Deux ans d'écart : encore toléré (sorties selon les pays).
    expect(
        closeLetterboxdMatch(film, [work('Perfect Blue', 1999, tmdbId: 1)])
            ?.tmdbId,
        1);
    // Trois ans : trop loin.
    expect(closeLetterboxdMatch(film, [work('Perfect Blue', 2000, tmdbId: 1)]),
        isNull);
    // Le plus proche l'emporte, puis le premier (le plus populaire).
    expect(
        closeLetterboxdMatch(film, [
          work('Perfect Blue', 1999, tmdbId: 1),
          work('Perfect Blue', 1998, tmdbId: 2),
          work('Perfect Blue', 1996, tmdbId: 3),
        ])?.tmdbId,
        2);
    // L'année exacte l'emporte toujours…
    expect(
        closeLetterboxdMatch(film, [
          work('Perfect Blue', 1997, tmdbId: 3),
          work('Perfect Blue', 1998, tmdbId: 1),
        ])?.tmdbId,
        3);
    // …mais deux titres identiques à la bonne année : on ne devine pas.
    expect(
        closeLetterboxdMatch(film, [
          work('Perfect Blue', 1997, tmdbId: 3),
          work('Perfect Blue', 1997, tmdbId: 4),
        ]),
        isNull);
  });

  test('a series keeps its own identity and survives a save', () {
    const series = LetterboxdWork(
        title: 'Chernobyl',
        year: 2019,
        tmdbId: 87108,
        mediaType: 'tv',
        traits: []);
    expect(series.identity, 'tmdb:tv:87108');
    final back = LetterboxdWork.fromJson(series.toJson());
    expect(back.isSeries, isTrue);
    expect(back.identity, 'tmdb:tv:87108');
    // Les imports enregistrés avant : des films.
    final legacy = Map<String, dynamic>.from(series.toJson())
      ..remove('mediaType');
    expect(LetterboxdWork.fromJson(legacy).identity, 'tmdb:movie:87108');
  });

  test('the library is searched by title or original title', () {
    final library = [
      work('Les Évadés', 1994,
          jellyfinId: 'a', aliases: ['The Shawshank Redemption']),
      work('Perfect Blue', 1997, jellyfinId: 'b'),
    ];
    expect(
        searchLetterboxdLibrary(library, 'shawshank').single.jellyfinId, 'a');
    expect(searchLetterboxdLibrary(library, 'evades').single.jellyfinId, 'a');
    expect(searchLetterboxdLibrary(library, ''), isEmpty);
  });

  test('a manual identification is saved into the stored import', () async {
    final container = ProviderContainer();
    final db = AppDatabase(
        container.read(Provider<Ref>((r) => r)), NativeDatabase.memory());
    addTearDown(() async {
      await db.close();
      container.dispose();
    });
    final store = LetterboxdStore(db, 'a');
    await store.save(const LetterboxdSnapshot(records: [
      LetterboxdRecord(film),
      LetterboxdRecord(
          LetterboxdFilm(uri: 'https://boxd.it/b', title: 'Other', year: 2000)),
    ]));
    var saved = 0;
    final library = [work('Perfect Blue', 1997, jellyfinId: 'pb')];
    final c = LetterboxdImportController(
        store: store,
        loadLibrary: () async => library,
        isCurrent: () => true,
        onSaved: () => saved++);
    addTearDown(c.dispose);

    final found = await c.searchWorks('perfect');
    expect(found.single.jellyfinId, 'pb');
    expect(await c.identify(film.uri, found.single), isTrue);

    final records = (await store.read()).records;
    expect(records.first.work?.jellyfinId, 'pb');
    expect(records.last.work, isNull);
    expect(saved, 1);

    // « Ne pas utiliser » défait l'identification.
    expect(await c.identify(film.uri, null), isTrue);
    expect((await store.read()).records.first.work, isNull);
  });
}
