import 'letterboxd_friends_parser.dart';

/// Une critique écrite sur Letterboxd, telle que la liste des critiques
/// d'un profil la montre : un extrait, le texte complet se lit à part.
class LetterboxdReview {
  const LetterboxdReview({
    required this.id,
    required this.slug,
    required this.excerpt,
    this.rating,
    this.date,
    this.likes = 0,
    this.spoilers = false,
    this.path,
  });

  /// Identifiant de la critique (`viewing:<id>` côté Letterboxd).
  final String id;
  final String slug;

  /// Début du texte, déjà débarrassé de son HTML.
  final String excerpt;

  /// Note sur 10 donnée avec la critique, si elle existe.
  final int? rating;
  final DateTime? date;
  final int likes;

  /// L'auteur l'a marquée « contient des spoilers ».
  final bool spoilers;

  /// Chemin de la critique sur letterboxd.com (`/pseudo/film/slug/`).
  final String? path;

  /// L'extrait est coupé : le texte complet se lit à part.
  bool get truncated => excerpt.endsWith('…') || excerpt.isEmpty;

  Map<String, Object?> toJson() => {
        'i': id,
        's': slug,
        'e': excerpt,
        if (rating != null) 'r': rating,
        if (date != null) 'd': date!.millisecondsSinceEpoch,
        if (likes > 0) 'l': likes,
        if (spoilers) 'x': true,
        if (path != null) 'p': path,
      };

  static LetterboxdReview? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['i'], slug = json['s'], excerpt = json['e'];
    if (id is! String || slug is! String || excerpt is! String) return null;
    final r = json['r'], d = json['d'], l = json['l'], p = json['p'];
    return LetterboxdReview(
        id: id,
        slug: slug,
        excerpt: excerpt,
        rating: r is int ? r : null,
        date: d is int ? DateTime.fromMillisecondsSinceEpoch(d) : null,
        likes: l is int ? l : 0,
        spoilers: json['x'] == true,
        path: p is String && p.startsWith('/') ? p : null);
  }
}

final _article = RegExp(
    r'<article[^>]*data-object-id="viewing:(\d+)"[^>]*data-object-name="review"[^>]*>(.*?)</article>',
    dotAll: true);
final _slug = RegExp(r'data-item-slug="([^"]+)"');
final _stars = RegExp(r'class="glyph -rating"[^>]*aria-label="([^"]*)"');
final _date = RegExp(r'<time class="timestamp" datetime="(\d{4}-\d{2}-\d{2})"');
final _likes = RegExp(r'data-format="count" data-count="(\d+)"');
final _link = RegExp(r'<h2 class="primaryname[^"]*"><a href="(/[^"]+)"');
// Jusqu'aux actions de la critique : le nombre de `</div>` varie (texte
// replié, critique à spoilers), les balises sont retirées ensuite.
final _body = RegExp(r'js-review-body[^>]*>(.*?)<div class="viewing-actions"',
    dotAll: true);

/// « ★★★½ » → 7 (sur 10), null sans note.
int? letterboxdStarsToRating(String stars) {
  final full = '★'.allMatches(stars).length;
  final half = stars.contains('½') ? 1 : 0;
  final value = full * 2 + half;
  return value == 0 ? null : value;
}

/// Texte lisible d'un fragment HTML de critique : un paragraphe par ligne
/// vide, sauts de ligne conservés, balises et entités retirées.
String letterboxdReviewText(String html) => decodeLetterboxdText(html
        .replaceAll(RegExp(r'<br\s*/?>'), '\n')
        .replaceAll(RegExp(r'</p>\s*<p[^>]*>'), '\n\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r' *\n *'), '\n'))
    .trim();

/// Une page de `<pseudo>/reviews/`, de la plus récente à la plus ancienne.
LetterboxdPage<List<LetterboxdReview>> parseReviewsPage(String html) {
  final reviews = <LetterboxdReview>[];
  for (final match in _article.allMatches(html)) {
    final id = match.group(1)!;
    final body = match.group(2)!;
    final slug = _slug.firstMatch(body)?.group(1);
    if (slug == null) continue;
    final text = _body.firstMatch(body)?.group(1);
    final stars = _stars.firstMatch(body)?.group(1);
    final date = _date.firstMatch(body)?.group(1);
    reviews.add(LetterboxdReview(
        id: id,
        slug: slug,
        excerpt: text == null ? '' : letterboxdReviewText(text),
        rating: stars == null ? null : letterboxdStarsToRating(stars),
        date: date == null ? null : DateTime.tryParse(date),
        likes: int.tryParse(_likes.firstMatch(body)?.group(1) ?? '') ?? 0,
        spoilers: body.contains('js-spoiler-container'),
        path: _link.firstMatch(body)?.group(1)));
  }
  return LetterboxdPage(reviews,
      hasNext: html.contains('<a class="next" href='));
}

/// Critiques d'un ami, slug → critique (la plus récente par film).
class FriendReviews {
  const FriendReviews(this.reviews, {this.fullAt});
  final Map<String, LetterboxdReview> reviews;
  final DateTime? fullAt;
}
