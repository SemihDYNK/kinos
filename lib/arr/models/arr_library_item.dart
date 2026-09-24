/// Image d'un film/série pour un `coverType` donné ("poster", "fanart"...)
/// — préfère l'URL distante (hébergée par le fournisseur de métadonnées,
/// aucune authentification requise) ; à défaut, reconstruit l'URL locale
/// servie par Radarr/Sonarr lui-même, avec la clé API en paramètre
/// (`/mediacover/...` accepte `apikey` en query, pas seulement l'en-tête
/// `X-Api-Key`). Partagée par [resolveArrPosterUrl] (jaquette,
/// `coverType: 'poster'`) et `resolveArrFanartUrl` (bandeau de la fiche
/// détail, `coverType: 'fanart'`).
String? resolveArrImageUrl(
  dynamic images, {
  required String coverType,
  required String baseUrl,
  required String apiKey,
}) {
  if (images is! List) return null;
  Map? match;
  for (final entry in images) {
    if (entry is Map && entry['coverType'] == coverType) {
      match = entry;
      break;
    }
  }
  if (match == null) return null;

  final remote = match['remoteUrl'] as String?;
  if (remote != null && remote.isNotEmpty) return remote;

  final relative = match['url'] as String?;
  if (relative == null || relative.isEmpty) return null;
  final trimmedBase = baseUrl.trim();
  final normalizedBase = trimmedBase.endsWith('/')
      ? trimmedBase.substring(0, trimmedBase.length - 1)
      : trimmedBase;
  final separator = relative.contains('?') ? '&' : '?';
  return '$normalizedBase$relative${separator}apikey=$apiKey';
}

/// Jaquette Primary — cf. [resolveArrImageUrl].
String? resolveArrPosterUrl(
  dynamic images, {
  required String baseUrl,
  required String apiKey,
}) =>
    resolveArrImageUrl(images,
        coverType: 'poster', baseUrl: baseUrl, apiKey: apiKey);

/// Date d'ajout à la bibliothèque (`added`, commun à `/movie` et
/// `/series`) — `null` si absente ou d'un type inattendu plutôt que de
/// lever, cohérent avec le reste du parsing *Arr.
DateTime? _parseAdded(dynamic value) =>
    value is String ? DateTime.tryParse(value) : null;

/// Film de la bibliothèque Radarr (`GET /api/v3/movie`) — de quoi chercher,
/// afficher un résultat parlant (jaquette, statut, qualité) et lancer une
/// recherche interactive.
class ArrMovie {
  final int id;
  final String title;
  final int? year;
  final String? posterUrl;
  final bool monitored;
  final bool hasFile;

  /// Qualité du fichier déjà présent — `null` si [hasFile] est faux.
  final String? qualityName;

  /// Date d'ajout à Radarr — sert de critère de tri par défaut.
  final DateTime? added;

  /// Corps JSON brut tel que reçu — Radarr exige le corps complet de la
  /// ressource sur `PUT /api/v3/movie/{id}` (pas un correctif partiel) :
  /// gardé pour renvoyer exactement ce qui a été lu, avec un seul champ
  /// changé (ex. `monitored`), plutôt que de reconstruire une ressource
  /// partielle qui perdrait les champs que ce modèle ne connaît pas.
  final Map<String, dynamic> raw;

  const ArrMovie({
    required this.id,
    required this.title,
    required this.year,
    required this.posterUrl,
    required this.monitored,
    required this.hasFile,
    required this.qualityName,
    required this.added,
    required this.raw,
  });

  factory ArrMovie.fromJson(
    Map<String, dynamic> json, {
    required String baseUrl,
    required String apiKey,
  }) {
    final movieFile = json['movieFile'];
    String? qualityName;
    if (movieFile is Map) {
      final quality = movieFile['quality'];
      if (quality is Map) {
        final inner = quality['quality'];
        if (inner is Map) qualityName = inner['name'] as String?;
      }
    }
    return ArrMovie(
      id: json['id'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      year: json['year'] as int?,
      posterUrl:
          resolveArrPosterUrl(json['images'], baseUrl: baseUrl, apiKey: apiKey),
      monitored: json['monitored'] as bool? ?? false,
      hasFile: json['hasFile'] as bool? ?? false,
      qualityName: qualityName,
      added: _parseAdded(json['added']),
      raw: json,
    );
  }
}

/// Série de la bibliothèque Sonarr (`GET /api/v3/series`).
class ArrSeries {
  final int id;
  final String title;
  final int? year;
  final String? posterUrl;
  final bool monitored;
  final int seasonCount;
  final int episodeCount;
  final int episodeFileCount;

  /// Date d'ajout à Sonarr — même raison que [ArrMovie.added].
  final DateTime? added;

  /// Corps JSON brut tel que reçu — même raison que [ArrMovie.raw].
  final Map<String, dynamic> raw;

  const ArrSeries({
    required this.id,
    required this.title,
    required this.year,
    required this.posterUrl,
    required this.monitored,
    required this.seasonCount,
    required this.episodeCount,
    required this.episodeFileCount,
    required this.added,
    required this.raw,
  });

  factory ArrSeries.fromJson(
    Map<String, dynamic> json, {
    required String baseUrl,
    required String apiKey,
  }) {
    final statistics = json['statistics'];
    final seasons = json['seasons'];
    return ArrSeries(
      id: json['id'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      year: json['year'] as int?,
      posterUrl:
          resolveArrPosterUrl(json['images'], baseUrl: baseUrl, apiKey: apiKey),
      monitored: json['monitored'] as bool? ?? false,
      seasonCount: statistics is Map && statistics['seasonCount'] is int
          ? statistics['seasonCount'] as int
          : seasons is List
              ? seasons.length
              : 0,
      episodeCount:
          statistics is Map ? (statistics['episodeCount'] as int? ?? 0) : 0,
      episodeFileCount:
          statistics is Map ? (statistics['episodeFileCount'] as int? ?? 0) : 0,
      added: _parseAdded(json['added']),
      raw: json,
    );
  }
}

/// Épisode d'une série Sonarr (`GET /api/v3/episode?seriesId=`) — sert au
/// sélecteur saison/épisode une fois la série choisie, et au dépliage de
/// saison sur la fiche détail (présence de fichier + date de diffusion).
class ArrEpisode {
  final int id;
  final int seriesId;
  final int seasonNumber;
  final int episodeNumber;
  final String title;

  /// Identifiant du fichier déjà téléchargé pour cet épisode — `null` ou
  /// `0` si absent. Source de vérité pour "présent/manquant" (pas le
  /// booléen `hasFile`, cf. la consigne calendrier : `episodeFileId`
  /// reste fiable même sur les payloads qui n'exposent pas `hasFile`).
  final int? episodeFileId;

  /// Date de diffusion en UTC telle que renvoyée par Sonarr — toujours
  /// consommée via `.toLocal()` côté affichage, jamais montrée telle
  /// quelle.
  final DateTime? airDateUtc;

  const ArrEpisode({
    required this.id,
    required this.seriesId,
    required this.seasonNumber,
    required this.episodeNumber,
    required this.title,
    this.episodeFileId,
    this.airDateUtc,
  });

  bool get hasFile => episodeFileId != null && episodeFileId != 0;

  factory ArrEpisode.fromJson(Map<String, dynamic> json) => ArrEpisode(
        id: json['id'] as int? ?? 0,
        seriesId: json['seriesId'] as int? ?? 0,
        seasonNumber: json['seasonNumber'] as int? ?? 0,
        episodeNumber: json['episodeNumber'] as int? ?? 0,
        title: json['title'] as String? ?? '',
        episodeFileId: json['episodeFileId'] as int?,
        airDateUtc: switch (json['airDateUtc']) {
          String value => DateTime.tryParse(value),
          _ => null,
        },
      );
}
