import 'package:kinos/arr/models/arr_library_item.dart';
import 'package:kinos/arr/models/arr_media_detail.dart' show resolveArrFanartUrl;
import 'package:kinos/arr/models/arr_service.dart';

/// Statut d'une entrée de calendrier — 3 jetons sémantiques seulement
/// (`AppColors.calendarAnnounced/Downloaded/Missing`, déjà posés dans
/// `app_theme.dart`). Le cas "diffusé/sorti mais pas encore importé" est
/// un [missing] : il prend la même couleur qu'un manquant ordinaire,
/// déjà visuellement distincte d'[announced] (bleu vs. rouge-brun) —
/// aucun 4ᵉ jeton n'est nécessaire, seule la logique de calcul doit
/// éviter de confondre "pas encore sorti" et "sorti sans fichier".
enum ArrCalendarStatus { announced, downloaded, missing }

/// Tranche entre les 3 statuts à partir de la présence d'un fichier et de
/// la date de référence (date de sortie résolue côté Radarr, date de
/// diffusion côté Sonarr) comparée à maintenant. Partagée par les
/// entrées de calendrier et les lignes d'épisode du dépliage de saison
/// (fiche détail) — même règle des deux côtés.
ArrCalendarStatus computeArrCalendarStatus({
  required bool hasFile,
  required DateTime? referenceDate,
}) {
  if (hasFile) return ArrCalendarStatus.downloaded;
  final now = DateTime.now();
  if (referenceDate != null && referenceDate.isAfter(now)) {
    return ArrCalendarStatus.announced;
  }
  return ArrCalendarStatus.missing;
}

/// Quelle date porte foi pour une entrée Radarr — `digitalRelease` en
/// priorité, puis `physicalRelease`, puis `inCinemas`. Sonarr n'a qu'une
/// seule date possible (`air`), gardée dans la même énumération pour que
/// l'affichage n'ait qu'un seul type à traiter.
enum ArrCalendarDateBasis { digital, physical, cinema, air }

/// Entrée unifiée de calendrier Radarr (film) ou Sonarr (épisode) — les
/// deux API renvoient des ressources différentes (`movie` vs. `episode`
/// imbriquant `series`), mais l'écran calendrier n'a besoin que de ce
/// dénominateur commun.
class ArrCalendarEntry {
  /// Identifiant à utiliser pour ouvrir la fiche détail — id film
  /// (Radarr) ou id **série** (Sonarr, jamais l'id épisode : la fiche
  /// détail n'existe qu'à l'échelle film/série).
  final int detailId;

  final ArrService service;
  final String title;

  /// `SxxExx — titre d'épisode` pour une entrée Sonarr, `null` pour un
  /// film.
  final String? subtitle;

  /// Date affichée, déjà convertie en heure locale.
  final DateTime displayDate;
  final ArrCalendarDateBasis dateBasis;
  final ArrCalendarStatus status;
  final String? posterUrl;
  final String? fanartUrl;

  /// Surveillance du film/de la série (jamais de l'épisode seul) — sert
  /// à calculer le nouvel état pour "basculer la surveillance" depuis le
  /// menu contextuel.
  final bool monitored;

  /// Id épisode Sonarr, pour scoper une recherche à cette diffusion
  /// précise — `null` côté Radarr (le film entier est déjà la portée).
  final int? episodeId;

  const ArrCalendarEntry({
    required this.detailId,
    required this.service,
    required this.title,
    required this.subtitle,
    required this.displayDate,
    required this.dateBasis,
    required this.status,
    required this.posterUrl,
    required this.fanartUrl,
    required this.monitored,
    required this.episodeId,
  });

  /// `true` quand la date affichée n'est pas la plus évidente pour ce
  /// service (Sonarr n'a qu'une date, toujours "évidente") — pilote la
  /// légende secondaire de la carte.
  bool get hasNonObviousDateBasis =>
      dateBasis == ArrCalendarDateBasis.physical ||
      dateBasis == ArrCalendarDateBasis.cinema;

  String get dateBasisLabel => switch (dateBasis) {
        ArrCalendarDateBasis.digital => 'Sortie numérique',
        ArrCalendarDateBasis.physical => 'Sortie physique',
        ArrCalendarDateBasis.cinema => 'Sortie en salles',
        ArrCalendarDateBasis.air => 'Diffusion',
      };

  factory ArrCalendarEntry.fromRadarrJson(
    Map<String, dynamic> json, {
    required String baseUrl,
    required String apiKey,
  }) {
    final digital = _parseDate(json['digitalRelease']);
    final physical = _parseDate(json['physicalRelease']);
    final cinema = _parseDate(json['inCinemas']);
    final DateTime date;
    final ArrCalendarDateBasis basis;
    if (digital != null) {
      date = digital;
      basis = ArrCalendarDateBasis.digital;
    } else if (physical != null) {
      date = physical;
      basis = ArrCalendarDateBasis.physical;
    } else {
      date = cinema ?? DateTime.now();
      basis = ArrCalendarDateBasis.cinema;
    }
    final hasFile = json['hasFile'] as bool? ?? false;
    final images = json['images'];
    return ArrCalendarEntry(
      detailId: json['id'] as int? ?? 0,
      service: ArrService.radarr,
      title: json['title'] as String? ?? '',
      subtitle: null,
      displayDate: date.toLocal(),
      dateBasis: basis,
      status: computeArrCalendarStatus(
          hasFile: hasFile, referenceDate: date.toLocal()),
      posterUrl:
          resolveArrPosterUrl(images, baseUrl: baseUrl, apiKey: apiKey),
      fanartUrl:
          resolveArrFanartUrl(images, baseUrl: baseUrl, apiKey: apiKey),
      monitored: json['monitored'] as bool? ?? false,
      episodeId: null,
    );
  }

  /// `json` est une ressource épisode (`series` imbriquée requiert
  /// `includeSeries=true` sur l'appel calendrier — sans quoi ni le titre
  /// de série ni son affiche ne sont disponibles).
  factory ArrCalendarEntry.fromSonarrJson(
    Map<String, dynamic> json, {
    required String baseUrl,
    required String apiKey,
  }) {
    final air = _parseDate(json['airDateUtc']) ?? DateTime.now();
    final episodeFileId = json['episodeFileId'] as int?;
    final hasFile = episodeFileId != null && episodeFileId != 0;
    final series = json['series'];
    final seriesMap = series is Map ? Map<String, dynamic>.from(series) : null;
    final images = seriesMap?['images'];
    return ArrCalendarEntry(
      detailId: json['seriesId'] as int? ?? 0,
      service: ArrService.sonarr,
      title: seriesMap?['title'] as String? ?? json['title'] as String? ?? '',
      subtitle:
          'S${_pad(json['seasonNumber'])}E${_pad(json['episodeNumber'])} — '
          '${json['title'] as String? ?? ''}',
      displayDate: air.toLocal(),
      dateBasis: ArrCalendarDateBasis.air,
      status: computeArrCalendarStatus(
          hasFile: hasFile, referenceDate: air.toLocal()),
      posterUrl:
          resolveArrPosterUrl(images, baseUrl: baseUrl, apiKey: apiKey),
      fanartUrl:
          resolveArrFanartUrl(images, baseUrl: baseUrl, apiKey: apiKey),
      // Surveillance de la série (nécessite `includeSeries=true`), pas de
      // l'épisode : "basculer la surveillance" agit toujours à l'échelle
      // série, cohérent avec la fiche détail.
      monitored: seriesMap?['monitored'] as bool? ?? false,
      episodeId: json['id'] as int?,
    );
  }
}

DateTime? _parseDate(dynamic value) =>
    value is String ? DateTime.tryParse(value) : null;

String _pad(dynamic number) => (number as int? ?? 0).toString().padLeft(2, '0');
