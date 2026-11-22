import 'dart:convert';

import 'package:http/http.dart' as http;

/// Une citation trouvée sur Wikiquote : le texte, sa langue, et pour une
/// réplique le film et le personnage qui la dit.
class WrappedQuote {
  const WrappedQuote(this.text, {required this.language, this.film, this.role});
  final String text;
  final String language;
  final String? film;
  final String? role;

  Map<String, Object?> toJson() => {
        'x': text,
        'l': language,
        if (film != null) 'f': film,
        if (role != null) 'r': role,
      };

  static WrappedQuote? fromJson(Object? json) =>
      json is Map && json['x'] is String
          ? WrappedQuote(json['x'] as String,
              language: json['l'] as String? ?? 'fr',
              film: json['f'] as String?,
              role: json['r'] as String?)
          : null;
}

/// Longueurs acceptées : assez pour dire quelque chose, assez court pour
/// tenir sur une diapo.
const _quoteMin = 40;
const _quoteMax = 160;
const _lineMin = 20;
const _lineMax = 120;

/// Le texte lisible d'un fragment de wikitexte : liens, gras, italiques,
/// modèles et indications de mise en scène retirés.
String stripWikitext(String text) {
  var s = text
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'</?poem>|</?small>|</?i>|</?b>'), '')
      .replaceAll(RegExp(r'<ref[^>]*/>'), '')
      .replaceAll(RegExp(r'<ref[^>]*>.*?</ref>', dotAll: true), '')
      // [[cible|texte]] → texte, [[texte]] → texte
      .replaceAllMapped(RegExp(r'\[\[(?:[^\]|]*\|)?([^\]]*)\]\]'), (m) => m[1]!)
      // {{lang|en|texte}}, {{w|cible|texte}} → texte
      .replaceAllMapped(
          RegExp(r'\{\{(?:lang|w)\|(?:[^}|]*\|)?([^}]*)\}\}'), (m) => m[1]!)
      .replaceAll(RegExp(r'\{\{[^}]*\}\}'), '')
      // Indications de mise en scène : [entre crochets] ou ''(en italique)''
      .replaceAll(RegExp(r"\[''[^\]]*''\]"), '')
      .replaceAll(RegExp(r'\[[^\]]*\]'), '')
      .replaceAll(RegExp(r"''\([^)]*\)''"), '')
      .replaceAll(RegExp(r"'{2,}"), '')
      .replaceAll(RegExp(r'[{}]'), '');
  s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  return s;
}

/// La citation d'une personne sur sa page Wikiquote : la plus courte qui
/// dit quelque chose, hors entretiens à deux voix. Français
/// (`{{Citation|citation=…}}`) ou anglais (puces de la première partie,
/// avant « Quotes about », « Disputed », « Misattributed »).
String? personQuote(String wikitext) {
  final candidates = <String>[];
  for (final m in RegExp(r'\{\{\s*[Cc]itation\s*\|\s*citation\s*=(.*?)\n?\|',
          dotAll: true)
      .allMatches(wikitext)) {
    final raw = m[1]!;
    // Un entretien (« A. Ferenczi : … ») n'est pas une citation.
    if (RegExp(r'^\s*[A-ZÀ-Ý][\w.\- ]{0,20} :').hasMatch(raw)) continue;
    candidates.add(stripWikitext(raw));
  }
  if (candidates.isEmpty) {
    final end = RegExp(
            r'^=+\s*(Quotes about|Disputed|Misattributed|About|External links|See also)',
            multiLine: true)
        .firstMatch(wikitext)
        ?.start;
    final body = end == null ? wikitext : wikitext.substring(0, end);
    for (final m
        in RegExp(r'^\*\s*(?!\*)(.+)$', multiLine: true).allMatches(body)) {
      candidates.add(stripWikitext(m[1]!));
    }
  }
  // La première qui tient sur une diapo : les pages commencent par les
  // propos les plus connus.
  return candidates
      .where((c) => c.length >= _quoteMin && c.length <= _quoteMax)
      .firstOrNull;
}

bool _sameCharacter(String speaker, String role) {
  final a = speaker.toLowerCase().trim(), b = role.toLowerCase().trim();
  if (a.isEmpty || b.isEmpty) return false;
  if (a == b || a.contains(b) || b.contains(a)) return true;
  final words = b.split(RegExp(r'[\s/]+')).where((w) => w.length > 2);
  return words.any((w) => a.split(RegExp(r'\s+')).contains(w));
}

/// Les répliques d'un personnage sur la page Wikiquote d'un film :
/// `{{Personnage|Nom}} : …` (français), section `== Nom ==` à puces ou
/// dialogue `'''Nom''': …` (anglais).
List<String> characterLines(String wikitext, String role) {
  final lines = <String>[];
  for (final m in RegExp(r'\{\{Personnage\|([^}]*)\}\}\s*:\s*(.+)')
      .allMatches(wikitext)) {
    if (_sameCharacter(m[1]!, role)) lines.add(m[2]!);
  }
  for (final m in RegExp(r"^:?\s*'''([^']+?)'''\s*:\s*(.+)$", multiLine: true)
      .allMatches(wikitext)) {
    if (_sameCharacter(m[1]!.replaceAll(':', ''), role)) lines.add(m[2]!);
  }
  final headings = RegExp(r'^==\s*([^=]+?)\s*==\s*$', multiLine: true)
      .allMatches(wikitext)
      .toList();
  for (var i = 0; i < headings.length; i++) {
    if (!_sameCharacter(headings[i][1]!, role)) continue;
    final body = wikitext.substring(headings[i].end,
        i + 1 < headings.length ? headings[i + 1].start : wikitext.length);
    for (final m
        in RegExp(r'^\*\s*(?!\*)(.+)$', multiLine: true).allMatches(body)) {
      lines.add(m[1]!);
    }
  }
  return [for (final l in lines) stripWikitext(l)];
}

/// La réplique qu'on retient : celle où le personnage dit son propre nom
/// (« The name's Bond. James Bond. »), sinon la plus courte qui tienne.
String? bestLine(List<String> lines, String role) {
  bool shouting(String l) {
    final letters = l.replaceAll(RegExp(r'[^A-Za-zÀ-ÿ]'), '');
    return letters.isNotEmpty &&
        letters.replaceAll(RegExp(r'[^A-ZÀ-Ý]'), '').length / letters.length >
            .6;
  }

  final fitting = lines
      .where(
          (l) => l.length >= _lineMin && l.length <= _lineMax && !shouting(l))
      .toList();
  if (fitting.isEmpty) return null;
  final names = role
      .toLowerCase()
      .split(RegExp(r'[\s/]+'))
      .where((w) => w.length > 2)
      .toList();
  int score(String line) {
    final lower = line.toLowerCase();
    final own = names.where(lower.contains).length;
    return own * 100 - line.length;
  }

  fitting.sort((a, b) => score(b).compareTo(score(a)));
  return fitting.first;
}

/// L'API de Wikiquote (lecture seule). Un client générique : aucune
/// information sur l'utilisateur ne part avec la requête.
class WikiquoteClient {
  WikiquoteClient({http.Client? client}) : _http = client ?? http.Client();
  final http.Client _http;

  static const _headers = {'User-Agent': 'KinosWrapped/1.0'};

  Future<Map<String, dynamic>?> _get(
      String language, Map<String, String> query) async {
    final uri = Uri.https('$language.wikiquote.org', '/w/api.php',
        {...query, 'format': 'json', 'formatversion': '2'});
    final response = await _http
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) return null;
    final json = jsonDecode(response.body);
    return json is Map<String, dynamic> ? json : null;
  }

  /// Le wikitexte d'une page, redirections suivies ; null si absente.
  Future<String?> page(String language, String title) async {
    final json = await _get(language, {
      'action': 'parse',
      'page': title,
      'prop': 'wikitext',
      'redirects': '1',
    });
    final text = (json?['parse'] as Map?)?['wikitext'];
    return text is String ? text : null;
  }

  /// Le titre de page le plus proche de [query].
  Future<String?> search(String language, String query) async {
    final json = await _get(language, {
      'action': 'query',
      'list': 'search',
      'srsearch': query,
      'srlimit': '1',
    });
    final results = (json?['query'] as Map?)?['search'];
    return results is List && results.isNotEmpty
        ? (results.first as Map)['title'] as String?
        : null;
  }

  void close() => _http.close();
}

/// Le titre d'une page trouvée par la recherche ressemble-t-il à [title] ?
/// Évite de lire les répliques d'un autre film.
bool sameTitle(String page, String title) {
  String norm(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'\(.*?\)'), '')
      .replaceAll(RegExp(r"[^a-z0-9à-ÿ]+"), ' ')
      .trim();
  final a = norm(page), b = norm(title);
  return a.isNotEmpty && b.isNotEmpty && (a == b || a.startsWith(b));
}
