import 'package:intl/intl.dart';

/// Ce qui distingue une année de cinéma, mesuré par [computeWrapped] : la
/// phrase d'accroche retient le signal le plus marqué, avec un vrai chiffre
/// et un vrai nom, plutôt qu'un portrait que tout le monde partage.
class HookSignals {
  const HookSignals({
    required this.films,
    this.obscureShare,
    this.medianYear,
    required this.year,
    this.foreignShare,
    this.topLanguage,
    this.director,
    this.directorFilms = 0,
    this.publicGap,
    this.elsewhere = 0,
    this.rewatched = 0,
    this.streakDays,
    this.streakStart,
    this.genre,
    this.genreFilms = 0,
  });

  final int films;

  /// Part des films de moins de [obscureVotes] votes TMDB.
  final double? obscureShare;
  final int? medianYear;
  final int year;

  /// Part des films dont la langue originale n'est pas l'anglais, et la
  /// plus fréquente d'entre elles (code ISO 639-1).
  final double? foreignShare;
  final String? topLanguage;
  final String? director;
  final int directorFilms;

  /// Écart moyen à la note du public, en étoiles (négatif : plus sévère).
  final double? publicGap;
  final int elsewhere;
  final int rewatched;
  final int? streakDays;
  final DateTime? streakStart;
  final String? genre;
  final int genreFilms;
}

/// Seuil sous lequel un film est « peu vu » (votes TMDB).
const obscureVotes = 5000;

typedef WrappedHook = ({String signal, String text});

const _languages = {
  'fr': 'le français',
  'ja': 'le japonais',
  'ko': 'le coréen',
  'zh': 'le chinois',
  'cn': 'le cantonais',
  'it': 'l\'italien',
  'es': 'l\'espagnol',
  'de': 'l\'allemand',
  'sv': 'le suédois',
  'da': 'le danois',
  'no': 'le norvégien',
  'ru': 'le russe',
  'pt': 'le portugais',
  'hi': 'l\'hindi',
  'fa': 'le persan',
  'pl': 'le polonais',
  'tr': 'le turc',
  'th': 'le thaï',
  'ar': 'l\'arabe',
  'he': 'l\'hébreu',
};

const _numbers = {
  2: 'deux',
  3: 'trois',
  4: 'quatre',
  5: 'cinq',
  6: 'six',
  7: 'sept',
  8: 'huit',
  9: 'neuf',
  10: 'dix',
};

/// « Un film sur trois », « La moitié de vos films ».
String _oneIn(double share) {
  if (share >= .7) return 'Presque tous vos films';
  if (share >= .45) return 'La moitié de vos films';
  final n = (1 / share).round();
  return 'Un film sur ${_numbers[n] ?? '$n'}';
}

bool _vowel(String word) =>
    word.isNotEmpty && 'aeiouyéèêàâh'.contains(word[0].toLowerCase());

const _genreEndings = {
  'action': 'vous avez eu votre dose d\'adrénaline',
  'thriller': 'vous aimez avoir le cœur qui bat',
  'drame': 'vous n\'avez pas peur des larmes',
  'comédie': 'vous avez beaucoup ri',
  'science-fiction': 'le futur vous appartient',
  'horreur': 'vous dormez la lumière allumée',
  'romance': 'le cœur a ses raisons',
  'animation': 'l\'enfance n\'est jamais loin',
  'aventure': 'toujours prêt à partir',
  'crime': 'le crime paie, au moins à l\'écran',
  'documentaire': 'le réel vous suffit',
  'guerre': 'vous ne craignez pas le fracas',
  'western': 'l\'horizon vous appelle',
};

String _stars(double value) => NumberFormat('0.#', 'fr').format(value.abs());

/// La phrase d'accroche : le signal le plus fort au-delà de son seuil,
/// sinon une phrase chiffrée sur le genre dominant. Null sans film.
WrappedHook? wrappedHook(HookSignals s) {
  if (s.films == 0) return null;
  final candidates = <(double, WrappedHook)>[];
  // Le texte n'est écrit que pour un signal retenu (une part nulle n'a
  // pas de « un film sur N »).
  void add(double score, String signal, String Function() text) {
    if (score >= 1) candidates.add((score, (signal: signal, text: text())));
  }

  if (s.obscureShare case final share?) {
    final verb = share >= .45 ? 'ont' : 'a';
    add(
        share / .3,
        'obscure',
        () =>
            '${_oneIn(share)} $verb moins de 5 000 votes. Vous creusez là où personne ne va.');
  }
  if (s.medianYear case final median?) {
    add(
        (s.year - median) / 25,
        'age',
        () =>
            'Votre film moyen est sorti en $median. Le présent peut attendre.');
  }
  if (s.foreignShare case final share?) {
    final verb = share >= .45 ? 'n\'étaient' : 'n\'était';
    final lead = _languages[s.topLanguage];
    add(
        share / .3,
        'language',
        () =>
            '${_oneIn(share)} $verb pas en anglais${lead == null ? '' : ', $lead en tête'}. Le monde est votre salle.');
  }
  if (s.director case final director? when s.directorFilms >= 4) {
    final share = s.directorFilms / s.films;
    add(
        share / .08,
        'director',
        () =>
            '${_oneIn(share)} signé $director. Ce n\'est plus de l\'admiration, c\'est une filmographie.');
  }
  if (s.publicGap case final gap?) {
    final stars = _stars(gap);
    final unit = gap.abs() >= 2 ? 'étoiles' : 'étoile';
    if (gap < 0) {
      add(
          -gap / .6,
          'severe',
          () =>
              '$stars $unit de moins que le public en moyenne. Le cinéma doit encore vous convaincre.');
    } else {
      add(
          gap / .6,
          'generous',
          () =>
              '$stars $unit de plus que le public en moyenne. Vous savez aimer.');
    }
  }
  if (s.films >= 8) {
    final share = s.elsewhere / s.films;
    add(
        share / .25,
        'elsewhere',
        () =>
            '${_oneIn(share)} vu hors de chez vous. La salle obscure vous connaît.');
  }
  add(
      s.rewatched / 5 * .9,
      'rewatch',
      () =>
          '${s.rewatched} films revus cette année. Vous savez ce que vous aimez.');
  if (s.streakDays case final days? when s.streakStart != null) {
    final month = DateFormat('MMMM', 'fr').format(s.streakStart!);
    final summer = s.streakStart!.month >= 6 && s.streakStart!.month <= 8;
    add(
        days / 7 * .9,
        'streak',
        () => '$days jours d\'affilée en $month. '
            '${summer ? 'Un été en salle de projection.' : 'Une habitude, plus qu\'une envie.'}');
  }
  if (candidates.isNotEmpty) {
    candidates.sort((a, b) => b.$1.compareTo(a.$1));
    return candidates.first.$2;
  }
  final genre = s.genre;
  if (genre == null) {
    return (
      signal: 'films',
      text: '${s.films} films cette année. Chacun a compté.'
    );
  }
  final lower = genre.toLowerCase();
  final ending =
      _genreEndings[lower] ?? 'le genre $lower vous a tenu toute l\'année';
  return (
    signal: 'genre',
    text:
        '${s.genreFilms} films ${_vowel(lower) ? 'd\'' : 'de '}$lower : $ending.'
  );
}
