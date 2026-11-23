import 'package:kinos/letterboxd/friends/letterboxd_friends_store.dart'
    show FriendRating;
import 'package:kinos/ratings/kinos_ratings.dart';

import '../viewing_log.dart';
import '../viewing_stats.dart';
import 'film_facts.dart';
import 'wrapped_hook.dart';

/// L'ambiance musicale d'un acte, tirée des genres qui le portent.
enum WrappedMood { piano, tension, ampleur, melancolie, legerete }

const _moods = {
  WrappedMood.tension: [
    'thriller',
    'crime',
    'horreur',
    'horror',
    'mystère',
    'mystery',
    'guerre',
    'war',
  ],
  WrappedMood.ampleur: [
    'aventure',
    'adventure',
    'action',
    'science-fiction',
    'science fiction',
    'fantastique',
    'fantasy',
    'western',
    'histoire',
    'history',
  ],
  WrappedMood.melancolie: ['drame', 'drama', 'romance', 'musique', 'music'],
  WrappedMood.legerete: [
    'comédie',
    'comedy',
    'animation',
    'familial',
    'family',
  ],
};

/// L'humeur du premier genre reconnu de [genres], le piano sinon.
WrappedMood moodOfGenres(Iterable<String> genres) {
  for (final genre in genres) {
    final lower = genre.toLowerCase();
    for (final e in _moods.entries) {
      if (e.value.contains(lower)) return e.key;
    }
  }
  return WrappedMood.piano;
}

/// Un film où votre note s'écarte de celle du public (sur 10 toutes deux).
typedef HotTake = ({ViewingEvent film, int mine, double public});

/// Un film où votre note s'écarte de celle de vos amis Letterboxd (ou s'en
/// approche) : leur moyenne sur 10 et leurs notes.
typedef FriendTake = ({
  ViewingEvent film,
  int mine,
  double friends,
  List<FriendRating> ratings,
});

/// Un marathon : des épisodes d'une même série enchaînés sans pause de plus
/// d'une journée et demie.
typedef WrappedMarathon = ({
  String series,
  int episodes,
  DateTime start,
  DateTime end,
  int seconds,
});

/// Les épisodes en marathon : le plus long enchaînement d'une même série
/// (au moins quatre épisodes, aucun écart de plus de
/// 36 h entre deux), le plus d'épisodes d'abord, puis le plus court.
WrappedMarathon? wrappedMarathon(
    List<({String name, List<ViewingEvent> episodes})> series) {
  WrappedMarathon? best;
  for (final s in series) {
    final episodes = [...s.episodes]..sort((a, b) => a.at.compareTo(b.at));
    var start = 0;
    for (var i = 1; i <= episodes.length; i++) {
      if (i < episodes.length &&
          episodes[i].at.difference(episodes[i - 1].at).inHours <= 36) {
        continue;
      }
      final run = episodes.sublist(start, i);
      start = i;
      if (run.length < 4) continue;
      final candidate = (
        series: s.name,
        episodes: run.length,
        start: run.first.at,
        end: run.last.at,
        seconds: run.fold(0, (sum, e) => sum + e.seconds),
      );
      if (best == null ||
          candidate.episodes > best.episodes ||
          (candidate.episodes == best.episodes &&
              candidate.end.difference(candidate.start) <
                  best.end.difference(best.start))) {
        best = candidate;
      }
    }
  }
  return best;
}

/// Ce qu'il faut à toutes les diapos du Wrapped d'une année.
class WrappedData {
  const WrappedData({
    required this.year,
    required this.stats,
    required this.timeline,
    required this.voyage,
    required this.medianYear,
    required this.directorFilms,
    required this.actorFilms,
    required this.genreFilms,
    required this.filmOfYear,
    required this.runnersUp,
    required this.publicLoves,
    required this.youLove,
    required this.publicAgreement,
    required this.friendsDisagree,
    required this.friendsAgree,
    required this.moods,
    required this.hook,
    this.facts = const {},
    this.series = const [],
    this.marathon,
  });

  final int year;
  final ViewingStats stats;

  /// Les séances de films de l'année, dans l'ordre (la frise du temps).
  final List<ViewingEvent> timeline;

  /// Les films de l'année, une fois chacun, du plus récent au plus ancien
  /// par année de sortie (le voyage à rebours).
  final List<ViewingEvent> voyage;
  final int? medianYear;

  /// Les films du réalisateur, de l'acteur et du genre de l'année.
  final List<ViewingEvent> directorFilms;
  final List<ViewingEvent> actorFilms;
  final List<ViewingEvent> genreFilms;

  /// Le mieux noté de l'année, et les quatre suivants (le récap).
  final ({ViewingEvent event, int rating})? filmOfYear;
  final List<({ViewingEvent event, int rating})> runnersUp;

  /// Le public l'aime, vous non ; vous l'aimez, le public non.
  final HotTake? publicLoves;
  final HotTake? youLove;

  /// Sans hot take : l'écart moyen au public, en étoiles.
  final double? publicAgreement;
  final FriendTake? friendsDisagree;
  final FriendTake? friendsAgree;

  /// Les ambiances des trois actes : le temps, les goûts, les films.
  final List<WrappedMood> moods;
  final WrappedHook? hook;

  /// Les séries de l'année, de la plus regardée à la moins : leurs
  /// épisodes vus.
  final List<({String name, List<ViewingEvent> episodes})> series;

  /// Le plus long marathon de l'année, s'il y en a un.
  final WrappedMarathon? marathon;

  /// Les faits du public par film TMDB (images des films hors
  /// bibliothèque).
  final Map<int, FilmFacts> facts;

  bool get isEmpty => stats.isEmpty;
}

/// Votes TMDB en dessous desquels la note du public ne compte pas.
const _minPublicVotes = 200;

/// Écart minimum (sur 10) pour une diapo « à contre-courant ».
const hotTakeGap = 2.5;

/// Écart minimum (sur 10) avec la moyenne des amis pour un désaccord, et
/// maximum pour un accord.
const friendsGap = 3;
const friendsAccord = 1;

/// Calcule le Wrapped de [year]. [facts] donne la note du public par film
/// TMDB, [friends] les notes des amis par slug Letterboxd, [slugs] le slug
/// de chaque film (identité du journal → slug).
WrappedData computeWrapped(
  List<ViewingEvent> all,
  Map<String, KinosRating> ratings,
  int year, {
  Map<int, FilmFacts> facts = const {},
  Map<String, List<FriendRating>> friends = const {},
  Map<String, String> slugs = const {},
}) {
  final stats = computeStats(all, ratings, StatsPeriod(year: year));
  final timeline = [
    for (final e in all)
      if (e.isMovie && e.at.year == year) e
  ]..sort((a, b) => a.at.compareTo(b.at));

  // Un film une fois : sa dernière séance de l'année.
  final films = <String, ViewingEvent>{
    for (final e in timeline) e.identity: e,
  };
  int? releaseOf(ViewingEvent e) =>
      e.year ?? (e.tmdbId == null ? null : facts[e.tmdbId]?.year);
  final voyage = [
    for (final e in films.values)
      if (releaseOf(e) != null) e
  ]..sort((a, b) => releaseOf(b)!.compareTo(releaseOf(a)!));
  final releases = [for (final e in voyage) releaseOf(e)!]..sort();
  final medianYear = releases.isEmpty ? null : releases[releases.length ~/ 2];

  List<ViewingEvent> filmsWhere(bool Function(ViewingEvent e) test) => [
        for (final e in films.values.toList().reversed)
          if (test(e)) e
      ];
  final director = stats.directors.firstOrNull?.name;
  final actor = stats.actors.firstOrNull?.name;
  final genre = stats.genres.firstOrNull?.name;

  // Vos notes face au public et aux amis.
  int? ratingOf(ViewingEvent e) => (ratings[e.identity] ??
          (e.jellyfinId == null ? null : ratings['jellyfin:${e.jellyfinId}']))
      ?.value;
  final takes = <HotTake>[];
  final friendTakes = <FriendTake>[];
  for (final e in films.values) {
    final mine = ratingOf(e);
    if (mine == null) continue;
    final fact = e.tmdbId == null ? null : facts[e.tmdbId];
    if (fact?.publicRating case final public?
        when (fact!.votes ?? 0) >= _minPublicVotes) {
      takes.add((film: e, mine: mine, public: public));
    }
    final friendRatings = friends[slugs[e.identity]] ?? const [];
    if (friendRatings.isNotEmpty) {
      friendTakes.add((
        film: e,
        mine: mine,
        friends: friendRatings.fold(0, (a, f) => a + f.rating) /
            friendRatings.length,
        ratings: friendRatings,
      ));
    }
  }
  double gap(HotTake t) => t.mine - t.public;
  HotTake? extreme(
      bool Function(double) keep, int Function(double, double) by) {
    final kept = takes.where((t) => keep(gap(t))).toList()
      ..sort((a, b) => by(gap(a), gap(b)));
    return kept.firstOrNull;
  }

  final publicLoves =
      extreme((g) => g <= -hotTakeGap, (a, b) => a.compareTo(b));
  final youLove = extreme((g) => g >= hotTakeGap, (a, b) => b.compareTo(a));
  final meanGap = takes.length < 8
      ? null
      : takes.fold(0.0, (a, t) => a + gap(t)) / takes.length / 2;
  final publicAgreement = takes.length < 5
      ? null
      : takes.fold(0.0, (a, t) => a + gap(t).abs()) / takes.length / 2;

  double friendGap(FriendTake t) => t.mine - t.friends;
  final disagree = friendTakes
      .where((t) => friendGap(t).abs() >= friendsGap)
      .fold<FriendTake?>(
          null,
          (best, t) => best == null ||
                  friendGap(t).abs() > friendGap(best).abs() ||
                  (friendGap(t).abs() == friendGap(best).abs() &&
                      t.ratings.length > best.ratings.length)
              ? t
              : best);
  final agree = friendTakes
      .where(
          (t) => t.ratings.length >= 2 && friendGap(t).abs() <= friendsAccord)
      .fold<FriendTake?>(
          null,
          (best, t) => best == null || t.ratings.length > best.ratings.length
              ? t
              : best);

  // Les signaux de l'accroche.
  final withVotes = [
    for (final e in films.values)
      if (e.tmdbId != null && facts[e.tmdbId]?.votes != null) facts[e.tmdbId]!
  ];
  final withLanguage = [
    for (final e in films.values)
      if (e.tmdbId != null && facts[e.tmdbId]?.language != null)
        facts[e.tmdbId]!.language!
  ];
  final foreign = withLanguage.where((l) => l != 'en').toList();
  final languageCounts = <String, int>{};
  for (final l in foreign) {
    languageCounts[l] = (languageCounts[l] ?? 0) + 1;
  }
  final viewings = <String, int>{};
  for (final e in timeline) {
    viewings[e.identity] = (viewings[e.identity] ?? 0) + 1;
  }
  final hook = wrappedHook(HookSignals(
    films: stats.films,
    year: year,
    obscureShare: withVotes.length < 8
        ? null
        : withVotes.where((f) => f.votes! < obscureVotes).length /
            withVotes.length,
    medianYear: releases.length < 8 ? null : medianYear,
    foreignShare:
        withLanguage.length < 8 ? null : foreign.length / withLanguage.length,
    topLanguage: languageCounts.entries
        .fold<MapEntry<String, int>?>(
            null, (a, b) => a == null || b.value > a.value ? b : a)
        ?.key,
    director: director,
    directorFilms: stats.directors.firstOrNull?.count ?? 0,
    publicGap: meanGap,
    elsewhere: stats.elsewhere,
    rewatched: viewings.values.where((n) => n > 1).length +
        timeline.where((e) => e.rewatch && viewings[e.identity] == 1).length,
    streakDays: stats.streak?.days,
    streakStart: stats.streak?.start,
    genre: genre,
    genreFilms: stats.genres.firstOrNull?.count ?? 0,
  ));

  final bySeries = <String, List<ViewingEvent>>{};
  for (final e in all) {
    if (!e.isMovie && e.at.year == year) {
      (bySeries[e.seriesTitle ?? e.title] ??= []).add(e);
    }
  }
  final series = [
    for (final e in bySeries.entries) (name: e.key, episodes: e.value)
  ]..sort((a, b) => b.episodes.length.compareTo(a.episodes.length));

  final top = stats.topRated;
  return WrappedData(
    series: series.take(5).toList(),
    marathon: wrappedMarathon(series),
    year: year,
    stats: stats,
    timeline: timeline,
    voyage: voyage,
    medianYear: medianYear,
    directorFilms: director == null
        ? const []
        : filmsWhere((e) => e.directors.contains(director)),
    actorFilms:
        actor == null ? const [] : filmsWhere((e) => e.cast.contains(actor)),
    genreFilms:
        genre == null ? const [] : filmsWhere((e) => e.genres.contains(genre)),
    filmOfYear: top.firstOrNull,
    runnersUp: top.skip(1).take(4).toList(),
    publicLoves: publicLoves,
    youLove: youLove,
    publicAgreement:
        publicLoves == null && youLove == null ? publicAgreement : null,
    friendsDisagree: disagree,
    friendsAgree: agree == disagree ? null : agree,
    moods: [
      WrappedMood.piano,
      genre == null ? WrappedMood.piano : moodOfGenres([genre]),
      moodOfGenres(top.firstOrNull?.event.genres ?? const []),
    ],
    hook: hook,
    facts: facts,
  );
}
