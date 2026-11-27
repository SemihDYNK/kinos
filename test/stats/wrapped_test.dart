import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kinos/letterboxd/friends/letterboxd_friends_parser.dart';
import 'package:kinos/letterboxd/letterboxd_model.dart';
import 'package:kinos/models/syncing/database_item.dart';
import 'package:kinos/ratings/kinos_ratings.dart';
import 'package:kinos/stats/viewing_log.dart';
import 'package:kinos/stats/wrapped/film_facts.dart';
import 'package:kinos/stats/wrapped/wikiquote.dart';
import 'package:kinos/stats/wrapped/wrapped_audio.dart';
import 'package:kinos/stats/wrapped/wrapped_data.dart';
import 'package:kinos/stats/wrapped/wrapped_hook.dart';
import 'package:kinos/stats/wrapped/wrapped_providers.dart';

ViewingEvent film(int tmdb, DateTime at,
        {int? year,
        List<String> genres = const ['Drame'],
        List<String> directors = const []}) =>
    ViewingEvent(
        identity: 'tmdb:movie:$tmdb',
        kind: 'movie',
        title: 'Film $tmdb',
        at: at,
        runtimeSeconds: 7200,
        sources: const {ViewingSource.kinos},
        jellyfinId: 'j$tmdb',
        tmdbId: tmdb,
        year: year,
        genres: genres,
        directors: directors);

KinosRating rated(int value) =>
    KinosRating(value, at: DateTime(2026), source: RatingSource.kinos);

LetterboxdFriend friend(String name) =>
    LetterboxdFriend(username: name, name: name);

void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  test('Seerr facts: public rating, votes, language, year', () {
    final facts = FilmFacts.fromSeerr({
      'voteAverage': 7.9,
      'voteCount': 1200,
      'originalLanguage': 'ja',
      'releaseDate': '1952-10-09',
    });
    expect(facts.publicRating, 7.9);
    expect((facts.votes, facts.language, facts.year), (1200, 'ja', 1952));
    expect(FilmFacts.fromSeerr({'voteAverage': 0, 'voteCount': 0}).publicRating,
        isNull,
        reason: 'no vote, no rating');
    final back = FilmFacts.fromJson(facts.toJson());
    expect((back.publicRating, back.year), (7.9, 1952));
  });

  test('the facts cache keeps what Seerr said', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final db = AppDatabase(
        container.read(Provider<Ref>((r) => r)), NativeDatabase.memory());
    addTearDown(db.close);
    final store = FilmFactsStore(db, 'p');
    await store.saveAll({1: const FilmFacts(publicRating: 6, votes: 10)});
    expect((await store.all())[1]!.votes, 10);
  });

  test('a year: timeline, voyage, hot takes, friends and moods', () {
    final events = [
      film(1, DateTime(2026, 3, 1), year: 2020, genres: ['Thriller']),
      film(2, DateTime(2026, 1, 5), year: 1952, genres: ['Thriller']),
      film(3, DateTime(2026, 7, 9), year: 1999, genres: ['Comédie']),
      film(4, DateTime(2025, 7, 9), year: 2001),
    ];
    final data = computeWrapped(
      events,
      {
        'tmdb:movie:1': rated(2),
        'tmdb:movie:2': rated(10),
        'tmdb:movie:3': rated(6),
      },
      2026,
      facts: {
        1: const FilmFacts(publicRating: 8.2, votes: 9000),
        2: const FilmFacts(publicRating: 6.8, votes: 400),
        3: const FilmFacts(publicRating: 6.4, votes: 50),
      },
      friends: {
        'one': [
          (friend: friend('a'), rating: 9),
          (friend: friend('b'), rating: 8)
        ],
        'two': [
          (friend: friend('a'), rating: 10),
          (friend: friend('b'), rating: 9),
          (friend: friend('c'), rating: 10)
        ],
      },
      slugs: {'tmdb:movie:1': 'one', 'tmdb:movie:2': 'two'},
    );
    expect([for (final e in data.timeline) e.tmdbId], [2, 1, 3]);
    expect([for (final e in data.voyage) e.year], [2020, 1999, 1952]);
    expect(data.medianYear, 1999);
    expect(data.publicLoves!.film.tmdbId, 1, reason: '2/10 against 8.2');
    expect(data.youLove!.film.tmdbId, 2, reason: '10/10 against 6.8');
    expect(data.friendsDisagree!.film.tmdbId, 1);
    expect(data.friendsAgree!.film.tmdbId, 2);
    expect(data.filmOfYear!.event.tmdbId, 2);
    expect(data.moods, [
      WrappedMood.piano,
      WrappedMood.tension,
      WrappedMood.piano,
      WrappedMood.tension
    ]);
    expect(data.genreFilms.length, 2);
  });

  test('the hook picks the sharpest signal, with its numbers', () {
    expect(
        wrappedHook(const HookSignals(films: 20, year: 2026, obscureShare: .5))!
            .text,
        'La moitié de vos films ont moins de 5 000 votes. '
        'Vous creusez là où personne ne va.');
    final director = wrappedHook(const HookSignals(
        films: 94,
        year: 2026,
        obscureShare: .31,
        director: 'Steven Spielberg',
        directorFilms: 10))!;
    expect(director.signal, 'director');
    expect(
        director.text, startsWith('Un film sur neuf signé Steven Spielberg'));
    expect(
        wrappedHook(const HookSignals(
                films: 40, year: 2026, genre: 'Action', genreFilms: 38))!
            .text,
        '38 films d\'action : vous avez eu votre dose d\'adrénaline.');
    expect(
        wrappedHook(HookSignals(
                films: 40,
                year: 2026,
                streakDays: 19,
                streakStart: DateTime(2026, 7, 11)))!
            .text,
        '19 jours d\'affilée en juillet. Un été en salle de projection.');
    expect(wrappedHook(const HookSignals(films: 0, year: 2026)), isNull);
  });

  test('slugs come from the log, the import and resolved films', () {
    expect(letterboxdSlugOf('https://letterboxd.com/film/dune-2021/'),
        'dune-2021');
    expect(letterboxdSlugOf('https://boxd.it/jWEA'), isNull);
    final slugs = wrappedSlugs(
        [
          film(1, DateTime(2026)),
          film(2, DateTime(2026)),
          film(3, DateTime(2026)),
          ViewingEvent(
              identity: 'letterboxd:obscure',
              kind: 'movie',
              title: 'O',
              at: DateTime(2026)),
        ],
        snapshot: const LetterboxdSnapshot(records: [
          LetterboxdRecord(
              LetterboxdFilm(
                  uri: 'https://letterboxd.com/film/two/', title: 'Two'),
              work: LetterboxdWork(title: 'Two', tmdbId: 2, traits: [])),
        ]),
        resolved: {1: 'one'});
    expect(slugs, {
      'tmdb:movie:1': 'one',
      'tmdb:movie:2': 'two',
      'letterboxd:obscure': 'obscure',
    });
  });
  test('Wikiquote: a person\'s quote, a character\'s line', () {
    const person = '''
== Quotes ==
* Oh, torture.
* There is no such thing as science fiction, there is only science eventuality.
** Interview, 1999.
== Quotes about Spielberg ==
* Spielberg has been ridiculed for shooting his actors from below against impossibly skies.
''';
    expect(personQuote(person),
        'There is no such thing as science fiction, there is only science eventuality.');
    const french = '''
{{Citation
|citation=A. Ferenczi : Qu'est-ce que cela vous inspire ? Une longue réponse d'entretien qui ne compte pas.
|langue=en
}}
{{Citation
|citation=Je rêve pour gagner ma vie, et c'est le plus beau métier du monde.
|langue=en
}}
''';
    expect(personQuote(french),
        'Je rêve pour gagner ma vie, et c\'est le plus beau métier du monde.');
    const film = """
==James Bond==
* [''To Vesper''] You represent the Treasury.
* Ow.
==Dialogue==
:'''Vesper''': And you are?
:'''Bond''': The name's Bond. James Bond.
""";
    expect(bestLine(characterLines(film, 'James Bond'), 'James Bond'),
        'The name\'s Bond. James Bond.');
    const raiders = '''
{{citation|citation=<poem>{{Personnage|Le guide}} : Il n'y a rien à craindre, ici !
{{Personnage|Indiana Jones}} : C'est bien ce qui me fait peur.</poem>}}
{{citation|citation=<poem>{{Personnage|Indiana Jones}} : JE DÉTESTE LES SERPENTS, JOCK !</poem>}}
''';
    expect(bestLine(characterLines(raiders, 'Indiana Jones'), 'Indiana Jones'),
        'C\'est bien ce qui me fait peur.');
    expect(sameTitle('Casino Royale (2006 film)', 'Casino Royale'), isTrue);
    expect(sameTitle('James Bond', 'Casino Royale'), isFalse);
  });

  test('a marathon: one series, back to back', () {
    ViewingEvent episode(String series, DateTime at) => ViewingEvent(
        identity: 'ep:$series:$at',
        kind: 'episode',
        title: 'Épisode',
        seriesTitle: series,
        at: at,
        runtimeSeconds: 2400,
        completed: true,
        sources: const {ViewingSource.kinos});
    final series = [
      (
        name: 'A',
        episodes: [
          for (var h = 0; h < 5; h++)
            episode('A', DateTime(2026, 3, 3, 20 + h)),
          episode('A', DateTime(2026, 6, 1)),
        ]
      ),
      (
        name: 'B',
        episodes: [
          for (var d = 0; d < 4; d++) episode('B', DateTime(2026, 4, 1 + d)),
        ]
      ),
    ];
    final m = wrappedMarathon(series)!;
    expect((m.series, m.episodes), ('A', 5));
    expect(m.seconds, 5 * 2400);
    expect(
        wrappedMarathon([
          (name: 'C', episodes: [episode('C', DateTime(2026, 1, 1))])
        ]),
        isNull);
  });

  test('each slide plays the mood of its act', () {
    expect([
      for (final id in ['opening', 'time', 'rhythm']) wrappedActOf(id)
    ], [
      0,
      0,
      0
    ]);
    expect([
      for (final id in ['genre', 'director', 'ratings', 'friends', 'you-love'])
        wrappedActOf(id)
    ], [
      1,
      1,
      1,
      1,
      1
    ]);
    expect([
      for (final id in ['voyage', 'elsewhere']) wrappedActOf(id)
    ], [
      1,
      1
    ]);
    expect([
      for (final id in ['act3', 'series', 'marathon', 'pace', 'finished'])
        wrappedActOf(id)
    ], [
      2,
      2,
      2,
      2,
      2
    ]);
    expect([
      for (final id in ['profile', 'next-year', 'film-of-year', 'recap'])
        wrappedActOf(id)
    ], [
      3,
      3,
      3,
      3
    ]);
    expect(wrappedMoodAsset(WrappedMood.tension),
        'asset:///assets/sounds/wrapped_tension.ogg');
    // Chaque humeur a sa musique dans l'application.
    for (final mood in WrappedMood.values) {
      expect(
          File('assets/sounds/wrapped_${mood.name}.ogg').existsSync(), isTrue,
          reason: mood.name);
    }
  });
}
