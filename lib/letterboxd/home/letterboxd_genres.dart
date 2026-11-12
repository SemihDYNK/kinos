import 'package:kinos/letterboxd/friends/letterboxd_friends_parser.dart';
import 'package:kinos/providers/dashboard/genre_browse_provider.dart'
    show browseGenreLabel;

/// Genres de Letterboxd (adresse `/genre/<slug>/`) par libellé de genre
/// affiché dans Kinos, en minuscules. Un genre absent d'ici n'a pas de
/// rangées Letterboxd.
const _letterboxdGenreSlugs = {
  'action': 'action',
  'aventure': 'adventure',
  'animation': 'animation',
  'comédie': 'comedy',
  'crime': 'crime',
  'documentaire': 'documentary',
  'drame': 'drama',
  'familial': 'family',
  'fantastique': 'fantasy',
  'histoire': 'history',
  'horreur': 'horror',
  'musique': 'music',
  'mystère': 'mystery',
  'romance': 'romance',
  'science-fiction': 'science-fiction',
  'thriller': 'thriller',
  'téléfilm': 'tv-movie',
  'guerre': 'war',
  'western': 'western',
};

/// Slug Letterboxd du genre affiché [label], null s'il n'en a pas.
String? letterboxdGenreSlug(String label) =>
    _letterboxdGenreSlugs[label.toLowerCase()];

/// Vrai si la fiche Letterboxd [film] porte le genre affiché [label]
/// (« Comedy » ↔ « Comédie », « Science Fiction » ↔ « Science-fiction »).
bool filmInGenre(LetterboxdFilmPage film, String label) {
  final wanted = label.toLowerCase();
  return (film.genres ?? const <String>[])
      .any((genre) => browseGenreLabel(genre).toLowerCase() == wanted);
}
