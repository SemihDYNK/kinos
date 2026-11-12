/// Lecture des pages publiques de Letterboxd (aucune API ouverte) : comptes
/// suivis, notes d'un membre, film pointé par un identifiant TMDB.
///
/// Isolé ici pour être remplacé par l'API officielle si l'accès est un jour
/// accordé. Tout dépend du HTML du site : un changement de structure se
/// traduit par des listes vides, jamais par une erreur.
library;

import 'dart:convert';

/// Un compte suivi.
class LetterboxdFriend {
  const LetterboxdFriend(
      {required this.username, required this.name, this.avatarUrl});
  final String username;
  final String name;
  final String? avatarUrl;

  Map<String, Object?> toJson() =>
      {'u': username, 'n': name, if (avatarUrl != null) 'a': avatarUrl};

  static LetterboxdFriend? fromJson(Object? json) {
    if (json is! Map) return null;
    final username = json['u'], name = json['n'], avatar = json['a'];
    if (username is! String || username.isEmpty) return null;
    return LetterboxdFriend(
        username: username,
        name: name is String && name.isNotEmpty ? name : username,
        avatarUrl: avatar is String ? avatar : null);
  }

  @override
  bool operator ==(Object other) =>
      other is LetterboxdFriend &&
      other.username == username &&
      other.name == name &&
      other.avatarUrl == avatarUrl;

  @override
  int get hashCode => Object.hash(username, name, avatarUrl);
}

/// Une page d'une liste paginée.
class LetterboxdPage<T> {
  const LetterboxdPage(this.items, {required this.hasNext});
  final T items;
  final bool hasNext;
}

final _username = RegExp(r'^[A-Za-z0-9_]{2,30}$');

/// Pseudo Letterboxd valide (lettres, chiffres, souligné), ou null.
String? normalizeLetterboxdUsername(String raw) {
  var value = raw.trim();
  final fromUrl =
      RegExp(r'letterboxd\.com/([^/?#\s]+)').firstMatch(value)?.group(1);
  if (fromUrl != null) value = fromUrl;
  if (value.startsWith('@')) value = value.substring(1);
  return _username.hasMatch(value) ? value.toLowerCase() : null;
}

String _decode(String text) => text
    .replaceAll('&amp;', '&')
    .replaceAll('&quot;', '"')
    .replaceAll('&#039;', "'")
    .replaceAll('&#39;', "'")
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&nbsp;', ' ')
    .trim();

bool _hasNext(String html) => html.contains('<a class="next" href=');

final _person = RegExp(
    r'<a class="avatar[^"]*" href="/([^/"]+)/"\s*>\s*<img src="([^"]+)" alt="([^"]*)"');

/// Page « following » d'un membre.
LetterboxdPage<List<LetterboxdFriend>> parseFollowingPage(String html) {
  final friends = <LetterboxdFriend>[];
  final seen = <String>{};
  // Seulement le tableau des comptes suivis : l'en-tête de page montre
  // aussi l'avatar du propriétaire du profil.
  final start = html.indexOf('<tbody');
  final end = start < 0 ? -1 : html.indexOf('</tbody>', start);
  final table = start < 0 || end < 0 ? html : html.substring(start, end);
  for (final match in _person.allMatches(table)) {
    final username = match.group(1)!.toLowerCase();
    if (!_username.hasMatch(username) || !seen.add(username)) continue;
    final avatar = match.group(2)!;
    final name = _decode(match.group(3)!);
    friends.add(LetterboxdFriend(
      username: username,
      name: name.isEmpty ? username : name,
      // L'avatar par défaut du site n'apprend rien : initiale à la place.
      avatarUrl: avatar.contains('/static/img/avatar') ? null : avatar,
    ));
  }
  return LetterboxdPage(friends, hasNext: _hasNext(html));
}

final _ratedItem = RegExp(
    r'data-item-slug="([^"]+)".*?<p class="poster-viewingdata[^"]*"[^>]*>(.*?)</p>',
    dotAll: true);
final _rating = RegExp(r'rated-(\d{1,2})\b');

/// Page de notes d'un membre : slug du film → note sur 10 (demi-étoiles).
LetterboxdPage<Map<String, int>> parseRatingsPage(String html) {
  final ratings = <String, int>{};
  for (final match in _ratedItem.allMatches(html)) {
    final value =
        int.tryParse(_rating.firstMatch(match.group(2)!)?.group(1) ?? '');
    if (value == null || value < 1 || value > 10) continue;
    ratings[match.group(1)!] = value;
  }
  return LetterboxdPage(ratings, hasNext: _hasNext(html));
}

/// Slug d'une fiche film d'après son adresse (« …/film/ikiru/ » → ikiru).
String? filmSlugFromUrl(Uri url) {
  final segments = url.pathSegments.where((s) => s.isNotEmpty).toList();
  if (segments.length < 2 || segments.first != 'film') return null;
  return segments[1];
}

final _ogUrl = RegExp(r'<meta property="og:url" content="([^"]+)"');

/// Slug de la fiche film affichée, d'après sa balise `og:url`.
String? filmSlugFromPage(String html) {
  final url = _ogUrl.firstMatch(html)?.group(1);
  final parsed = url == null ? null : Uri.tryParse(url);
  return parsed == null ? null : filmSlugFromUrl(parsed);
}

/// Note sur 10 en étoiles (7 → ★★★½).
String letterboxdStars(int rating) =>
    '${'★' * (rating ~/ 2)}${rating.isOdd ? '½' : ''}';

final _slug = RegExp(r'data-item-slug="([^"]+)"');

/// Page d'une liste de jaquettes (watchlist, films vus, liste publique) :
/// slugs dans l'ordre de la page.
LetterboxdPage<List<String>> parseSlugListPage(String html) {
  final seen = <String>{};
  final slugs = [
    for (final match in _slug.allMatches(html))
      if (seen.add(match.group(1)!)) match.group(1)!
  ];
  return LetterboxdPage(slugs, hasNext: _hasNext(html));
}

/// Fiche d'un film Letterboxd, réduite à ce que l'accueil affiche.
class LetterboxdFilmPage {
  const LetterboxdFilmPage(
      {required this.slug,
      required this.tmdbId,
      required this.isMovie,
      required this.title,
      this.year,
      this.posterUrl,
      this.genres});
  final String slug;
  final String tmdbId;
  final bool isMovie;
  final String title;
  final int? year;
  final String? posterUrl;

  /// Genres de la fiche (noms anglais de Letterboxd) ; null pour une fiche
  /// enregistrée avant que Kinos les lise, à relire quand on en a besoin.
  final List<String>? genres;

  Map<String, Object?> toJson() => {
        's': slug,
        'id': tmdbId,
        'm': isMovie,
        't': title,
        if (year != null) 'y': year,
        if (posterUrl != null) 'p': posterUrl,
        if (genres != null) 'g': genres,
      };

  static LetterboxdFilmPage? fromJson(Object? json) {
    if (json is! Map) return null;
    final slug = json['s'], id = json['id'], title = json['t'];
    if (slug is! String || id is! String || title is! String) return null;
    final year = json['y'], poster = json['p'], genres = json['g'];
    return LetterboxdFilmPage(
        slug: slug,
        tmdbId: id,
        isMovie: json['m'] != false,
        title: title,
        year: year is int ? year : null,
        posterUrl: poster is String ? poster : null,
        genres: genres is List ? genres.whereType<String>().toList() : null);
  }
}

final _tmdbId = RegExp(r'data-tmdb-id="(\d+)"');
final _tmdbType = RegExp(r'data-tmdb-type="([a-z]+)"');
final _ldJson = RegExp(
    r'<script type="application/ld\+json">\s*(?:/\*.*?\*/)?\s*(\{.*?\})\s*(?:/\*.*?\*/)?\s*</script>',
    dotAll: true);
final _ogTitle = RegExp(r'<meta property="og:title" content="([^"]+)"');

/// Fiche film : identifiant TMDB, type, titre, année et affiche. Null si
/// la page n'expose pas d'identifiant TMDB.
LetterboxdFilmPage? parseFilmPage(String html, {String? slug}) {
  final tmdbId = _tmdbId.firstMatch(html)?.group(1);
  final filmSlug = slug ?? filmSlugFromPage(html);
  if (tmdbId == null || filmSlug == null) return null;
  String? title;
  int? year;
  String? poster;
  List<String>? genres;
  // Champs de premier niveau seulement : le bloc imbrique aussi les
  // réalisateurs, qui ont eux aussi un « name ».
  final ld = _ldJson.firstMatch(html)?.group(1);
  if (ld != null) {
    try {
      final json = jsonDecode(ld);
      if (json is Map) {
        if (json['name'] case final String name) title = name;
        if (json['image'] case final String image) poster = image;
        if (json['genre'] case final List list) {
          genres = list.whereType<String>().toList();
        } else if (json['genre'] case final String one) {
          genres = [one];
        }
        if (json['dateCreated'] case final String date) {
          year = int.tryParse(date.split('-').first);
        }
      }
    } on FormatException {
      // Bloc illisible : repli sur la balise og:title ci-dessous.
    }
  }
  if (title == null) {
    final og = _ogTitle.firstMatch(html)?.group(1);
    final match = og == null
        ? null
        : RegExp(r'^(.*) \((\d{4})\)$').firstMatch(_decode(og));
    title = match?.group(1) ?? (og == null ? null : _decode(og));
    year ??= int.tryParse(match?.group(2) ?? '');
  }
  if (title == null) return null;
  return LetterboxdFilmPage(
      slug: filmSlug,
      tmdbId: tmdbId,
      isMovie: _tmdbType.firstMatch(html)?.group(1) != 'tv',
      title: _decode(title),
      year: year,
      posterUrl: poster,
      // Une fiche lue sans genre n'est pas à relire : liste vide.
      genres: genres ?? const []);
}
