import 'package:kinos/letterboxd/letterboxd_model.dart';
import 'package:kinos/letterboxd/letterboxd_store.dart';

import 'letterboxd_friends_parser.dart';
import 'letterboxd_friends_store.dart';
import 'letterboxd_friends_sync.dart' show LetterboxdProfileNotFound;

/// Une entrée du journal Letterboxd, lue dans le flux RSS public du profil.
class LetterboxdDiaryEntry {
  const LetterboxdDiaryEntry(
      {required this.id,
      required this.slug,
      required this.title,
      required this.watchedOn,
      this.year,
      this.tmdbId,
      this.rating,
      this.rewatch = false});

  /// Identifiant de l'entrée dans le flux (`guid`), stable.
  final String id;
  final String slug;
  final String title;
  final int? year;
  final int? tmdbId;
  final DateTime watchedOn;

  /// Note sur 5, par demi-points.
  final double? rating;
  final bool rewatch;

  String get uri => 'https://letterboxd.com/film/$slug/';
}

final _item = RegExp(r'<item>(.*?)</item>', dotAll: true);
final _slug = RegExp(r'/film/([a-z0-9-]+)/');
final _date = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

String? _tag(String item, String name) {
  final match = RegExp('<$name(?:\\s[^>]*)?>([^<]*)</$name>').firstMatch(item);
  final value = match?.group(1)?.trim();
  return value == null || value.isEmpty ? null : value;
}

/// Entrées du journal du flux RSS d'un profil, de la plus récente à la plus
/// ancienne. Les autres éléments du flux (listes) sont ignorés.
List<LetterboxdDiaryEntry> parseLetterboxdDiary(String xml) {
  final entries = <LetterboxdDiaryEntry>[];
  for (final match in _item.allMatches(xml)) {
    final item = match.group(1)!;
    final id = _tag(item, 'guid');
    final slug = _slug.firstMatch(_tag(item, 'link') ?? '')?.group(1);
    final title = _tag(item, 'letterboxd:filmTitle');
    final date = _date.firstMatch(_tag(item, 'letterboxd:watchedDate') ?? '');
    if (id == null || slug == null || title == null || date == null) continue;
    final year = int.tryParse(_tag(item, 'letterboxd:filmYear') ?? '');
    final tmdbId = int.tryParse(_tag(item, 'tmdb:movieId') ?? '');
    final rating = double.tryParse(_tag(item, 'letterboxd:memberRating') ?? '');
    entries.add(LetterboxdDiaryEntry(
        id: id,
        slug: slug,
        title: decodeLetterboxdText(title),
        year: year != null && year >= 1850 && year <= 2200 ? year : null,
        tmdbId: tmdbId != null && tmdbId > 0 ? tmdbId : null,
        watchedOn: DateTime(int.parse(date.group(1)!),
            int.parse(date.group(2)!), int.parse(date.group(3)!)),
        rating: rating != null &&
                rating >= .5 &&
                rating <= 5 &&
                rating * 2 == (rating * 2).roundToDouble()
            ? rating
            : null,
        rewatch: _tag(item, 'letterboxd:rewatch') == 'Yes'));
  }
  return entries;
}

/// Ajoute les nouvelles entrées du journal ([entries], de la plus ancienne
/// à la plus récente) à l'import Letterboxd. Un film déjà connu gagne un
/// visionnage, sauf si l'import le comptait déjà (date pas plus récente).
LetterboxdSnapshot mergeLetterboxdDiary(LetterboxdSnapshot snapshot,
    List<LetterboxdDiaryEntry> entries, Map<int, LetterboxdWork> works,
    {required DateTime now}) {
  final records = [...snapshot.records];
  final index = {for (final (i, r) in records.indexed) r.film.uri: i};
  for (final entry in entries) {
    final work = entry.tmdbId == null ? null : works[entry.tmdbId];
    final at = index[entry.uri];
    if (at == null) {
      index[entry.uri] = records.length;
      records.add(LetterboxdRecord(
          LetterboxdFilm(
              uri: entry.uri,
              title: entry.title,
              year: entry.year,
              rating: entry.rating,
              ratedAt: entry.rating == null ? null : entry.watchedOn,
              watchedAt: entry.watchedOn),
          work: work));
      continue;
    }
    final record = records[at];
    final film = record.film;
    final counted =
        film.watchedAt != null && !entry.watchedOn.isAfter(film.watchedAt!);
    records[at] = LetterboxdRecord(
        LetterboxdFilm(
            uri: film.uri,
            title: film.title,
            year: film.year,
            rating: entry.rating ?? film.rating,
            ratedAt: entry.rating == null ? film.ratedAt : entry.watchedOn,
            watchedAt: counted ? film.watchedAt : entry.watchedOn,
            watches: counted ? film.watches : film.watches + 1),
        work: record.work ?? work);
  }
  return LetterboxdSnapshot(updatedAt: now.toUtc(), records: records);
}

/// Un film de la bibliothèque Jellyfin, retrouvé par son identifiant TMDB.
typedef LetterboxdLibraryMovie = ({String id, bool played});

/// Ce dont la synchronisation du journal a besoin côté Jellyfin.
abstract class LetterboxdDiaryLibrary {
  /// Films de la bibliothèque parmi [tmdbIds].
  Future<Map<int, LetterboxdLibraryMovie>> movies(Set<int> tmdbIds);

  /// Fiches (avec leurs traits, pour le profil de goût) des films [ids].
  Future<List<LetterboxdWork>> works(List<String> ids);

  Future<void> markPlayed(String id, DateTime watchedOn);
}

/// Reprend les films vus depuis la dernière fois (au cinéma, ailleurs) :
/// marqués vus dans Jellyfin s'ils sont dans la bibliothèque, et ajoutés à
/// l'import Letterboxd pour le profil de goût.
///
/// Le flux ne garde que les ~50 dernières entrées : au-delà, entre deux
/// synchronisations, l'import par fichier rattrape le reste.
class LetterboxdDiarySync {
  LetterboxdDiarySync(
      {required this.fetch,
      required this.friends,
      required this.snapshots,
      required this.library,
      this.resolve});

  final Future<String?> Function(String username) fetch;
  final LetterboxdFriendsStore friends;
  final LetterboxdStore snapshots;
  final LetterboxdDiaryLibrary library;

  /// Fiche d'un film hors bibliothèque (Seerr), si un service est relié.
  final Future<LetterboxdWork?> Function(int tmdbId)? resolve;

  /// Garde-fou de la liste des entrées déjà reprises.
  static const _keep = 500;

  /// Nombre de films marqués vus dans Jellyfin.
  Future<int> run(String username,
      {required bool Function() cancelled, DateTime? now}) async {
    final xml = await fetch(username);
    if (xml == null) throw const LetterboxdProfileNotFound();
    final entries = parseLetterboxdDiary(xml);
    final known = await friends.diary();
    final fresh =
        entries.where((e) => !known.seen.contains(e.id)).toList().reversed;
    final at = now ?? DateTime.now();
    if (cancelled()) return 0;
    var marked = 0;
    if (fresh.isNotEmpty) {
      final ids = {
        for (final e in fresh)
          if (e.tmdbId != null) e.tmdbId!
      };
      final movies = ids.isEmpty
          ? const <int, LetterboxdLibraryMovie>{}
          : await library.movies(ids);
      final done = <String>{};
      for (final entry in fresh) {
        if (cancelled()) return marked;
        final movie = movies[entry.tmdbId];
        if (movie == null || movie.played || !done.add(movie.id)) continue;
        await library.markPlayed(movie.id, entry.watchedOn);
        marked++;
      }
      final works = <int, LetterboxdWork>{};
      if (movies.isNotEmpty) {
        for (final work
            in await library.works([for (final m in movies.values) m.id])) {
          if (work.tmdbId != null) works[work.tmdbId!] = work;
        }
      }
      for (final id in ids.where((id) => !works.containsKey(id))) {
        if (cancelled() || resolve == null) break;
        try {
          final work = await resolve!(id);
          if (work != null) works[id] = work;
        } catch (_) {
          // Sans fiche : le film compte quand même, rapproché plus tard.
        }
      }
      if (cancelled()) return marked;
      await snapshots.save(mergeLetterboxdDiary(
          await snapshots.read(), fresh.toList(), works,
          now: at));
    }
    final current = {for (final e in entries) e.id};
    await friends.saveDiary(
        [
          ...current,
          ...known.seen.where((g) => !current.contains(g)),
        ].take(_keep),
        at);
    return marked;
  }
}
