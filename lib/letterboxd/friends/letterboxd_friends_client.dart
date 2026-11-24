import 'dart:async';
import 'dart:collection';

import 'package:http/http.dart' as http;

import 'letterboxd_friends_parser.dart';
import 'letterboxd_reviews.dart';

/// Erreur réseau ou réponse inattendue de letterboxd.com.
class LetterboxdUnavailable implements Exception {
  const LetterboxdUnavailable(this.status);
  final int? status;
  @override
  String toString() => 'LetterboxdUnavailable($status)';
}

/// Letterboxd a refusé une requête (403, 429) : trop de pages lues trop
/// vite. Plus aucune requête ne part avant [until].
class LetterboxdPaused extends LetterboxdUnavailable {
  const LetterboxdPaused(super.status, this.until, {this.path, this.challenge});
  final DateTime until;

  /// Page refusée, et l'en-tête `cf-mitigated` de Cloudflare s'il y en a
  /// un (`challenge` : vérification anti-robots, pas une limite de débit).
  final String? path;
  final String? challenge;
  @override
  String toString() =>
      'LetterboxdPaused($status, ${path ?? '?'}, ${challenge ?? '-'}, '
      'jusqu\'à $until)';
}

/// Accès en lecture aux pages publiques de letterboxd.com, une requête à la
/// fois et espacées : on reste un visiteur discret.
class LetterboxdFriendsClient {
  LetterboxdFriendsClient(
      {http.Client? client,
      this.spacing = const Duration(seconds: 1),
      this.backgroundSpacing = const Duration(seconds: 2),
      this.pause = const Duration(minutes: 30),
      this.challengePause = const Duration(hours: 24),
      this.timeout = const Duration(seconds: 20)})
      : _client = client ?? http.Client();

  static final base = Uri.parse('https://letterboxd.com/');
  static const _headers = {
    'User-Agent':
        'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Kinos',
    'Accept': 'text/html',
    'Accept-Language': 'en',
  };

  final http.Client _client;

  /// Écart minimal avant une requête attendue à l'écran.
  final Duration spacing;

  /// Écart minimal avant une requête de fond (synchronisation, rangées) :
  /// plus lent, pour ne pas déclencher la limite de débit.
  final Duration backgroundSpacing;

  /// Pause après un refus de Letterboxd (403, 429), sauf `Retry-After`.
  final Duration pause;

  /// Pause après une vérification anti-robots de Cloudflare.
  final Duration challengePause;
  final Duration timeout;
  DateTime? _pausedUntil;

  /// Fin de la pause en cours, ou null.
  DateTime? get pausedUntil {
    final until = _pausedUntil;
    return until != null && until.isAfter(DateTime.now()) ? until : null;
  }

  final _urgent = Queue<_Request>();
  final _background = Queue<_Request>();
  bool _draining = false;
  DateTime? _last;

  /// Lève la pause : un nouvel essai demandé par l'utilisateur. Un nouveau
  /// refus la remet aussitôt.
  void resume() => _pausedUntil = null;

  void close() => _client.close();

  /// Une requête après l'autre, avec au moins [spacing] entre deux départs.
  /// Les requêtes [urgent] (ce que l'utilisateur attend à l'écran) passent
  /// devant celles de fond (synchronisation, listes).
  Future<http.Response> _get(Uri url, {bool urgent = false}) {
    final request = _Request(url);
    (urgent ? _urgent : _background).add(request);
    _drain();
    return request.done.future;
  }

  Future<void> _drain() async {
    if (_draining) return;
    _draining = true;
    while (_urgent.isNotEmpty || _background.isNotEmpty) {
      final urgent = _urgent.isNotEmpty;
      final next = urgent ? _urgent.removeFirst() : _background.removeFirst();
      // En pause après un refus : rien ne part, la file se vide aussitôt.
      if (pausedUntil case final until?) {
        next.done.completeError(LetterboxdPaused(null, until));
        continue;
      }
      final last = _last;
      if (last != null) {
        final wait = (urgent ? spacing : backgroundSpacing) -
            DateTime.now().difference(last);
        if (wait > Duration.zero) await Future<void>.delayed(wait);
      }
      _last = DateTime.now();
      try {
        final request = http.Request('GET', next.url)
          ..headers.addAll(_headers)
          ..followRedirects = true;
        final streamed = await _client.send(request).timeout(timeout);
        next.done.complete(
            await http.Response.fromStream(streamed).timeout(timeout));
      } catch (error, stack) {
        next.done.completeError(error, stack);
      }
    }
    _draining = false;
  }

  Future<String?> _page(String path, {bool urgent = false}) async {
    final response = await _get(base.resolve(path), urgent: urgent);
    if (response.statusCode == 404) return null;
    if (response.statusCode == 403 || response.statusCode == 429) {
      final retry = int.tryParse(response.headers['retry-after'] ?? '');
      final challenge = response.headers['cf-mitigated'] == 'challenge';
      // Une vérification anti-robots (Cloudflare) ne se lève pas en
      // insistant : Kinos ne la contourne pas et attend une journée.
      final until = DateTime.now().add(retry != null && retry > 0
          ? Duration(seconds: retry)
          : challenge
              ? challengePause
              : pause);
      _pausedUntil = until;
      throw LetterboxdPaused(response.statusCode, until,
          path: path, challenge: response.headers['cf-mitigated']);
    }
    if (response.statusCode != 200) {
      throw LetterboxdUnavailable(response.statusCode);
    }
    return response.body;
  }

  String _paged(String path, int page) =>
      page <= 1 ? path : '${path}page/$page/';

  /// Comptes suivis par [username], toutes pages, null si le profil
  /// n'existe pas.
  Future<List<LetterboxdFriend>?> following(String username,
      {int maxPages = 40, bool Function()? cancelled}) async {
    final friends = <LetterboxdFriend>[];
    for (var page = 1; page <= maxPages; page++) {
      if (cancelled?.call() ?? false) break;
      final html = await _page(_paged('$username/following/', page));
      if (html == null) return page == 1 ? null : friends;
      final parsed = parseFollowingPage(html);
      friends.addAll(parsed.items);
      if (!parsed.hasNext) break;
    }
    return friends;
  }

  /// Une page des notes de [username], des plus récentes aux plus
  /// anciennes.
  Future<LetterboxdPage<Map<String, int>>> ratings(
      String username, int page) async {
    final html =
        await _page(_paged('$username/films/rated/.5-5/by/rated-date/', page));
    if (html == null) return const LetterboxdPage({}, hasNext: false);
    return parseRatingsPage(html);
  }

  /// Slug Letterboxd du film TMDB [tmdbId], null si Letterboxd ne le
  /// connaît pas.
  Future<String?> filmSlug(String tmdbId) async {
    final html = await _page('tmdb/$tmdbId/', urgent: true);
    return html == null ? null : filmSlugFromPage(html);
  }

  /// Une page des critiques de [username], des plus récentes aux plus
  /// anciennes.
  Future<LetterboxdPage<List<LetterboxdReview>>> reviews(
      String username, int page) async {
    final html = await _page(_paged('$username/reviews/', page));
    if (html == null) return const LetterboxdPage([], hasNext: false);
    return parseReviewsPage(html);
  }

  /// Texte complet de la critique [id], lu à son ouverture.
  Future<String?> reviewText(String id) async {
    final html = await _page('s/full-text/viewing:$id/', urgent: true);
    return html == null ? null : letterboxdReviewText(html);
  }

  /// Flux RSS du journal de [username] (les ~50 dernières entrées), null
  /// si le profil n'existe pas.
  Future<String?> diary(String username) => _page('$username/rss/');

  /// Photo de profil de [username], null s'il n'en a pas.
  Future<String?> profileAvatar(String username) async {
    final html = await _page('$username/', urgent: true);
    return html == null ? null : parseProfileAvatar(html);
  }

  /// Une page d'une liste de jaquettes : `<pseudo>/watchlist/`,
  /// `<pseudo>/films/by/date/`, `official/list/<liste>/`…
  Future<LetterboxdPage<List<String>>> slugList(String path, int page,
      {bool urgent = false}) async {
    final html = await _page(_paged(path, page), urgent: urgent);
    if (html == null) return const LetterboxdPage([], hasNext: false);
    return parseSlugListPage(html);
  }

  /// Fiche du film [slug], null si elle n'existe pas ou n'a pas
  /// d'identifiant TMDB.
  Future<LetterboxdFilmPage?> film(String slug, {bool urgent = false}) async {
    final html = await _page('film/$slug/', urgent: urgent);
    return html == null ? null : parseFilmPage(html, slug: slug);
  }
}

class _Request {
  _Request(this.url);
  final Uri url;
  final done = Completer<http.Response>();
}
