import 'package:kinos/recommendations/models/candidate_item.dart';

/// Une œuvre connue de Jellyfin, sous une forme minimale — juste assez
/// pour l'appariement titre/année (cf. [excludeArrCandidatesKnownToJellyfin]),
/// pas un [CandidateItem] complet : ni le profil joué (`played`) ni le
/// profil repris (`resumable`) n'ont besoin d'en extraire des traits
/// pour cet usage.
typedef TitledWork = ({String title, int? year});

/// Identifiants de fournisseurs externes d'une œuvre, quand connus —
/// appariement exact entre Radarr/Sonarr et Jellyfin (cf.
/// [findKnownJellyfinMatch]), prioritaire sur tout rapprochement de
/// titre. Toutes les valeurs comparées comme chaînes : Radarr expose
/// `tmdbId` en entier, Jellyfin le porte en chaîne dans `ProviderIds` —
/// un seul type de comparaison des deux côtés plutôt que de faire
/// porter la conversion à chaque appelant.
typedef ExternalIds = ({String? tmdbId, String? imdbId, String? tvdbId});

const _noExternalIds = (tmdbId: null, imdbId: null, tvdbId: null);

/// Normalise un titre pour une comparaison tolérante (même œuvre, pas
/// forcément la même chaîne exacte) — pas l'heuristique de franchise de
/// `franchise_key.dart`, qui retire volontairement les numéros de
/// suite : ici on veut au contraire ne jamais confondre "Batman" et
/// "Batman Returns".
///
/// Tolère, dans cet ordre :
/// - la casse ;
/// - les accents/diacritiques (cf. [_stripDiacritics]) ;
/// - la ponctuation (deux-points, apostrophes, tirets...), remplacée par
///   un espace plutôt que retirée pure — "Spider-Man" ne doit pas
///   devenir "spiderman" et collisionner avec un titre sans lien ;
/// - un article initial ("The", "Le", "La", "Les", "L'"...) — Radarr/
///   Sonarr et Jellyfin ne l'incluent pas toujours de la même façon ;
/// - un chiffre romain en fin de titre, ramené en chiffre arabe ("Evil
///   Dead II" == "Evil Dead 2", cf. [_romanToArabic]) — Radarr/TMDb et
///   Jellyfin ne s'accordent pas toujours sur la notation d'une suite.
///
/// Reste volontairement strict sur le reste du titre : c'est un
/// rapprochement de *la même œuvre écrite différemment*, pas une
/// recherche floue qui risquerait de confondre deux films distincts.
String normalizeTitleForMatching(String title) {
  var normalized = _stripDiacritics(title);
  normalized = normalized.replaceAll(
      RegExp(r'''[’'`´.,:;!?()\[\]{}"«»…\-–—_/\\]'''), ' ');
  normalized = normalized.toLowerCase();

  var words = normalized.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isNotEmpty && _leadingArticles.contains(words.first)) {
    words = words.skip(1).toList();
  }
  if (words.isNotEmpty) {
    final arabic = _romanToArabic(words.last.toUpperCase());
    if (arabic != null) words[words.length - 1] = arabic.toString();
  }

  return words.join(' ');
}

const _leadingArticles = {
  'the', 'a', 'an', // anglais
  'le', 'la', 'les', 'l', 'un', 'une', 'des', // français
};

const _diacriticsMap = {
  'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'ã': 'a', 'å': 'a',
  'ç': 'c',
  'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
  'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
  'ñ': 'n',
  'ò': 'o', 'ó': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o',
  'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u',
  'ý': 'y', 'ÿ': 'y',
  'œ': 'oe', 'æ': 'ae',
};

String _stripDiacritics(String value) {
  final buffer = StringBuffer();
  for (final rune in value.runes) {
    final char = String.fromCharCode(rune);
    final lower = char.toLowerCase();
    // `_diacriticsMap` n'a que des clés en minuscule — chercher avec
    // `lower` puis recomposer la casse d'origine sur le résultat trouvé.
    // Le bug corrigé ici réindexait avec `char` (potentiellement
    // majuscule, ex. 'É') au lieu de `lower` : `_diacriticsMap['É']`
    // n'existe pas (seul 'é' y est), d'où un `!` sur `null` — pas un cas
    // limite, n'importe quel titre avec une majuscule accentuée en tête
    // de mot (ex. "À bout de souffle") le déclenchait, aussi bien côté
    // titre Arr que côté catalogue Jellyfin.
    final replacement = _diacriticsMap[lower];
    if (replacement == null) {
      buffer.write(char);
    } else {
      buffer.write(char == lower ? replacement : replacement.toUpperCase());
    }
  }
  return buffer.toString();
}

const _romanValues = {
  'I': 1, 'V': 5, 'X': 10, 'L': 50, 'C': 100, 'D': 500, 'M': 1000,
};
final _romanNumeralPattern = RegExp(r'^[IVXLCDM]+$');

/// Convertit un chiffre romain en entier, `null` si [token] n'en est pas
/// un — validé par aller-retour (reconverti en romain canonique et
/// comparé à l'original) plutôt qu'une simple somme des valeurs : rejette
/// une écriture non canonique (ex. "IIII") et, plus important, un mot
/// dont les lettres appartiennent par coïncidence à I/V/X/L/C/D/M sans
/// être un chiffre romain voulu. Ce filet n'est pas parfait (un titre se
/// terminant par un mot qui EST accessoirement un chiffre romain valide,
/// ex. "MIX", serait converti à tort) — risque accepté : ça ne joue que
/// sur le repli textuel, jamais sur l'appariement par identifiant
/// externe (cf. [findKnownJellyfinMatch]), et une conversion erronée ne
/// fait au pire qu'échouer à apparier plutôt que d'apparier à tort (le
/// filtre par année reste actif).
int? _romanToArabic(String token) {
  if (token.isEmpty || !_romanNumeralPattern.hasMatch(token)) return null;
  var total = 0;
  for (var i = 0; i < token.length; i++) {
    final value = _romanValues[token[i]]!;
    final next = i + 1 < token.length ? _romanValues[token[i + 1]]! : 0;
    total += value < next ? -value : value;
  }
  return _toRomanNumeral(total) == token ? total : null;
}

const _romanTable = [
  (1000, 'M'), (900, 'CM'), (500, 'D'), (400, 'CD'),
  (100, 'C'), (90, 'XC'), (50, 'L'), (40, 'XL'),
  (10, 'X'), (9, 'IX'), (5, 'V'), (4, 'IV'), (1, 'I'),
];

String _toRomanNumeral(int value) {
  var remaining = value;
  final buffer = StringBuffer();
  for (final (amount, symbol) in _romanTable) {
    while (remaining >= amount) {
      buffer.write(symbol);
      remaining -= amount;
    }
  }
  return buffer.toString();
}

/// Retire d'une liste de candidats Arr tout ce qui correspond déjà à une
/// œuvre connue de Jellyfin, peu importe son état (jouée, en cours, ou
/// déjà présente dans la bibliothèque non vue) — cf. spec du calibrage :
/// pas de doublon entre la rangée Jellyfin et la rangée Arr, et la
/// rangée Arr ne doit garder que ce qui n'a "jamais été lancé".
///
/// Appariement sur le titre normalisé (cf. [normalizeTitleForMatching])
/// et l'année quand les deux sont connues — au-delà d'un an d'écart,
/// considéré comme deux œuvres distinctes plutôt que la même (filet de
/// sécurité contre une collision de titre, ex. un remake). Titre connu
/// sans année d'un côté ou de l'autre : exclu par prudence plutôt que
/// risquer un doublon visible.
///
/// Reste volontairement limité au titre (pas d'identifiant externe,
/// contrairement à [findKnownJellyfinMatch]) : cette liste d'entrée
/// ([TitledWork]) ne les porte pas — élargir ce filtre demanderait de
/// faire remonter tmdbId/imdbId jusqu'ici, hors du périmètre demandé
/// pour ce calibrage (qui ne visait que la destination du clic).
///
/// Uniquement des comparaisons en mémoire sur des listes déjà
/// récupérées — jamais un appel réseau par entrée (cf. le commentaire
/// historique à ce sujet dans `arr_candidate_adapter.dart`).
List<CandidateItem> excludeArrCandidatesKnownToJellyfin(
  List<CandidateItem> arrCandidates,
  Iterable<TitledWork> knownJellyfinWorks,
) {
  final index = <String, List<int?>>{};
  for (final work in knownJellyfinWorks) {
    index
        .putIfAbsent(normalizeTitleForMatching(work.title), () => [])
        .add(work.year);
  }

  return arrCandidates
      .where((candidate) => !_isKnownWork(candidate.title, candidate.year, index))
      .toList();
}

/// Vrai si (titre, année) correspond à une entrée déjà indexée par titre
/// normalisé — année inconnue d'un côté ou de l'autre, ou à un an
/// d'écart au plus, considéré comme la même œuvre ; au-delà, deux
/// œuvres distinctes plutôt qu'un doublon (filet de sécurité contre une
/// collision de titre, ex. un remake).
bool _isKnownWork(String title, int? year, Map<String, List<int?>> index) {
  final knownYears = index[normalizeTitleForMatching(title)];
  if (knownYears == null) return false;
  return knownYears.any(
      (known) => known == null || year == null || (year - known).abs() <= 1);
}

bool _sameExternalId(ExternalIds a, ExternalIds b) =>
    (a.tmdbId != null && a.tmdbId == b.tmdbId) ||
    (a.imdbId != null && a.imdbId == b.imdbId) ||
    (a.tvdbId != null && a.tvdbId == b.tvdbId);

/// Retrouve l'objet Jellyfin correspondant à un candidat Arr donné —
/// pour la destination du clic d'une entrée "Vous l'aviez mis de côté"
/// (lot B, `recommendation_row_section.dart`) : une entrée qui existe
/// déjà dans Jellyfin doit ouvrir sa fiche Jellyfin, pas sa fiche Arr —
/// y compris quand le dédoublonnage de la rangée elle-même (limité au
/// titre, cf. [excludeArrCandidatesKnownToJellyfin]) l'a laissée passer.
/// [catalog] peut donc être un ensemble plus large que celui utilisé
/// pour construire la rangée, c'est voulu (filet de sécurité, pas une
/// seconde règle de correspondance).
///
/// Deux étapes, dans cet ordre :
///
/// 1. **Identifiant externe** (cf. [externalIds]/[externalIdsOf]) —
///    tmdbId, imdbId ou tvdbId partagé : appariement exact, insensible
///    à toute variation de titre (langue, notation, ponctuation).
///    Radarr expose `tmdbId`/`imdbId`, Sonarr `tvdbId`/`imdbId` ;
///    Jellyfin porte les trois dans `ProviderIds` quand le plugin de
///    métadonnées les a renseignés. C'est le chemin fiable — cherché
///    sur tout [catalog], pas seulement les titres qui se ressemblent.
/// 2. **Repli textuel**, seulement si aucun identifiant ne correspond
///    (ou qu'aucun des deux côtés n'en porte) — titre normalisé (cf.
///    [normalizeTitleForMatching]) comparé au titre d'affichage ET,
///    quand [originalTitleOf] est fourni, au titre original ; Radarr/
///    Sonarr et Jellyfin n'affichent pas toujours la même version d'un
///    titre (VO/VF, article, notation numérique). Même tolérance
///    d'année qu'[excludeArrCandidatesKnownToJellyfin].
///
/// `titleOf`/`yearOf`/... : [T] générique plutôt que couplé à un modèle
/// Jellyfin précis — ce fichier n'a besoin de connaître aucun type
/// d'affichage, même principe que le reste du moteur.
T? findKnownJellyfinMatch<T>(
  String title,
  int? year,
  Iterable<T> catalog, {
  required String Function(T item) titleOf,
  required int? Function(T item) yearOf,
  String? Function(T item)? originalTitleOf,
  ExternalIds externalIds = _noExternalIds,
  ExternalIds Function(T item)? externalIdsOf,
}) {
  if (externalIdsOf != null &&
      (externalIds.tmdbId != null ||
          externalIds.imdbId != null ||
          externalIds.tvdbId != null)) {
    for (final item in catalog) {
      if (_sameExternalId(externalIds, externalIdsOf(item))) return item;
    }
  }

  final normalized = normalizeTitleForMatching(title);
  for (final item in catalog) {
    final displayMatches = normalizeTitleForMatching(titleOf(item)) == normalized;
    final original = originalTitleOf?.call(item);
    final originalMatches =
        original != null && normalizeTitleForMatching(original) == normalized;
    if (!displayMatches && !originalMatches) continue;

    final itemYear = yearOf(item);
    if (itemYear == null || year == null || (year - itemYear).abs() <= 1) {
      return item;
    }
  }
  return null;
}
