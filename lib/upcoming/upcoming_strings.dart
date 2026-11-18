import 'package:intl/intl.dart';

import 'upcoming_logic.dart';
import 'upcoming_models.dart';

/// Libellés de la page « Prochainement », réunis ici pour la traduction.
abstract final class UpcomingStrings {
  static const title = 'Prochainement';
  static const settingsTitle = 'Prochainement';
  static const settingsDesc =
      'Les films et séries qui sortent bientôt, et ce que vous suivez';
  static const regionTitle = 'Région des sorties';
  static const followsTitle = 'Vos suivis';
  static const bigRelease = 'Grande sortie';
  static const inRadarr = 'Dans Radarr';
  static const inSonarr = 'Dans Sonarr';
  static const toRequest = 'À demander';
  static const requested = 'Demandé';
  static const available = 'Disponible';
  static const open = 'Fiche';
  static const unfollow = 'Ne plus suivre';
  static const refresh = 'Actualiser';
  static const refreshing = 'Mise à jour…';
  static const loading = 'Recherche des sorties à venir…';
  static const failed = 'Seerr ne répond pas. Nouvel essai plus tard.';
  static const empty = 'Rien à venir avec ces filtres.';
  static const noFollows =
      'Suivez un réalisateur, un acteur, une saga ou un studio depuis la '
      'fiche d\'un film ou d\'une série : ses prochaines sorties '
      'arriveront ici.';
  static const all = 'Tout';
  static const movies = 'Films';
  static const series = 'Séries';
  static const both = 'Suivis et grandes sorties';
  static const followed = 'Suivis';
  static const big = 'Grandes sorties';
  static const byWeek = 'Par semaine';
  static const byMonth = 'Par mois';
  static const follow = 'Suivre…';
  static const followDialogTitle = 'Suivre';
  static const followDialogHint =
      'Leurs prochaines sorties apparaîtront dans Prochainement.';
  static const followDialogEmpty = 'Rien à suivre pour ce titre.';
  static const followDialogFailed = 'Seerr ne répond pas.';
  static const asDirector = 'réalisation';
  static const asActor = 'interprétation';
  static const saga = 'Saga';
  static const studio = 'Studio';
  static const network = 'Chaîne';
  static const thisSeries = 'Cette série';

  /// Régions proposées dans les réglages.
  static const regions = {
    'FR': 'France',
    'BE': 'Belgique',
    'CH': 'Suisse',
    'CA': 'Canada',
    'US': 'États-Unis',
    'GB': 'Royaume-Uni',
    'IE': 'Irlande',
    'DE': 'Allemagne',
    'AT': 'Autriche',
    'NL': 'Pays-Bas',
    'LU': 'Luxembourg',
    'ES': 'Espagne',
    'PT': 'Portugal',
    'IT': 'Italie',
    'SE': 'Suède',
    'NO': 'Norvège',
    'DK': 'Danemark',
    'FI': 'Finlande',
    'PL': 'Pologne',
    'TR': 'Turquie',
    'MA': 'Maroc',
    'DZ': 'Algérie',
    'TN': 'Tunisie',
    'JP': 'Japon',
    'KR': 'Corée du Sud',
    'CN': 'Chine',
    'IN': 'Inde',
    'AU': 'Australie',
    'NZ': 'Nouvelle-Zélande',
    'BR': 'Brésil',
    'MX': 'Mexique',
    'AR': 'Argentine',
  };

  static String regionName(String code) => regions[code] ?? code;

  static String release(UpcomingEntry e) => switch (e.release) {
        UpcomingRelease.theatrical => 'Salle',
        UpcomingRelease.digital => 'Numérique',
        UpcomingRelease.physical => 'Physique',
        UpcomingRelease.television => 'Télévision',
        UpcomingRelease.premiere => 'Nouvelle série',
        UpcomingRelease.season => 'Saison ${e.season}',
        UpcomingRelease.episode =>
          'S${e.season.toString().padLeft(2, '0')}E${e.episode.toString().padLeft(2, '0')}',
        UpcomingRelease.unknown => 'Date inconnue',
      };

  /// Sous le titre d'une tuile : les raisons, puis le type de sortie.
  static String caption(UpcomingEntry e) => [
        if (e.reasons.isNotEmpty) ...e.reasons else if (e.big) bigRelease,
        release(e),
        if (e.outsideRegion) 'hors région',
      ].join(' · ');

  static String pill(UpcomingEntry e, String locale) {
    final date = e.date;
    if (date == null) return '';
    return DateFormat('d MMM', locale).format(date);
  }

  static String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  /// « Mercredi 3 décembre · au cinéma ».
  static String bannerDate(UpcomingEntry e, String locale) {
    final date = e.date;
    final when = date == null
        ? 'Bientôt'
        : _cap(DateFormat('EEEE d MMMM', locale).format(date));
    final how = switch (e.release) {
      UpcomingRelease.theatrical => 'au cinéma',
      UpcomingRelease.digital => 'en numérique',
      UpcomingRelease.physical => 'en vidéo',
      UpcomingRelease.television => 'à la télévision',
      _ => release(e).toLowerCase(),
    };
    return '$when · $how${e.outsideRegion ? ' (hors région)' : ''}';
  }

  /// Titre d'une section et sa précision.
  static (String, String?) section(UpcomingSection s, String locale) {
    final start = s.start, end = s.end;
    String day(DateTime d) => DateFormat('d MMMM', locale).format(d);
    String span() {
      if (start == null || end == null) return '';
      return start.month == end.month
          ? 'du ${start.day} au ${day(end)}'
          : 'du ${day(start)} au ${day(end)}';
    }

    switch (s.kind) {
      case UpcomingSectionKind.thisWeek:
        return ('Cette semaine', span());
      case UpcomingSectionKind.nextWeek:
        return ('Semaine prochaine', span());
      case UpcomingSectionKind.week:
        // Titrée par sa date la plus marquante : celle du titre le plus
        // attendu de la semaine, les suivis d'abord.
        final marking = ([...s.entries]..sort((a, b) {
                if (a.reasons.isEmpty != b.reasons.isEmpty) {
                  return a.reasons.isEmpty ? 1 : -1;
                }
                return b.popularity.compareTo(a.popularity);
              }))
            .first
            .date;
        return (
          marking == null ? 'Semaine' : day(marking),
          'semaine ${span()}'
        );
      case UpcomingSectionKind.thisMonth:
        return ('Ce mois-ci', null);
      case UpcomingSectionKind.month:
        final now = DateTime.now();
        return (
          _cap(DateFormat(start!.year == now.year ? 'MMMM' : 'MMMM y', locale)
              .format(start)),
          null
        );
      case UpcomingSectionKind.later:
        return ('Plus tard', null);
      case UpcomingSectionKind.unknown:
        return ('Date inconnue', 'annoncés, sans date de sortie');
    }
  }

  static String followCount(int n) => '$n suivis';
  static String updatedLine(DateTime? at) => 'mis à jour ${updated(at)}';

  static String updated(DateTime? at) {
    if (at == null) return '';
    final age = DateTime.now().difference(at);
    if (age.inMinutes < 1) return 'à l\'instant';
    if (age.inHours < 1) return 'il y a ${age.inMinutes} min';
    if (age.inDays < 1) return 'il y a ${age.inHours} h';
    return 'il y a ${age.inDays} j';
  }
}

/// Libellés des pages personne, studio, chaîne et saga.
abstract final class EntityStrings {
  static const series = 'Série';
  static const announced = 'Annoncé';
  static const episodes = 'ép.';
  static const followDirecting = 'Suivre ses réalisations';
  static const followedDirecting = 'Réalisations suivies';
  static const followActing = 'Suivre ses rôles';
  static const followedActing = 'Rôles suivis';
  static const followSaga = 'Suivre la saga';
  static const followedSaga = 'Saga suivie';
  static const follow = 'Suivre';
  static const followed = 'Suivi';
  static const acting = 'Interprétation';
  static const directing = 'Réalisation';
  static const recent = 'Les plus récents';
  static const rated = 'Les mieux notés';
  static const popular = 'Populaires';
  static String checking(int n) => 'Tri des rôles… $n';
  static const failed = 'Seerr ne répond pas.';
  static const upcoming = 'À venir';
  static const library = 'Dans votre bibliothèque';
  static const restPerson = 'Le reste de sa filmographie';
  static const restSaga = 'À demander';
  static const catalogue = 'Catalogue';
  static const more = 'Voir plus';
  static const appearances = 'Apparaît dans';
  static String appearancesDetail(int n) => 'seconds rôles, caméos, voix · $n';
  static const nothing = 'Rien à montrer.';
  static const close = 'Fermer';
  static const biography = 'Biographie';
  static const presentation = 'Présentation';
  static const open = 'Ouvrir';
  static const openPage = 'Ouvrir sa page';
  static const studio = 'Studio';
  static const network = 'Chaîne';
  static String saga(int films) => 'Saga · $films films';
  static String department(String? known) => switch (known) {
        'Directing' => 'Réalisation',
        'Acting' => 'Interprétation',
        'Writing' => 'Scénario',
        'Production' => 'Production',
        _ => '',
      };
  static String born(String year) => 'né·e en $year';
  static String directingCount(int n) => '$n réalisations';
  static String actingCount(int n) => '$n rôles';
}
