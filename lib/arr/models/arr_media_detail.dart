import 'package:fladder/arr/models/arr_library_item.dart';

/// Fanart (bandeau) d'un film/série — cf. [resolveArrImageUrl].
String? resolveArrFanartUrl(
  dynamic images, {
  required String baseUrl,
  required String apiKey,
}) =>
    resolveArrImageUrl(images,
        coverType: 'fanart', baseUrl: baseUrl, apiKey: apiKey);

/// Note extraite de `ratings` — Radarr l'expose par fournisseur
/// (`{imdb: {value}, tmdb: {value}, ...}`), Sonarr à plat (`{value}`) :
/// on essaie d'abord la forme à plat, puis IMDb, puis TMDB — dans cet
/// ordre parce qu'IMDb est la référence la plus reconnue quand elle est
/// disponible. `null` si aucune des deux formes ne donne de valeur
/// exploitable, plutôt qu'une note à 0 trompeuse.
double? extractArrRating(dynamic ratings) {
  if (ratings is! Map) return null;
  final direct = ratings['value'];
  if (direct is num) return direct.toDouble();
  for (final key in ['imdb', 'tmdb']) {
    final nested = ratings[key];
    if (nested is Map && nested['value'] is num) {
      return (nested['value'] as num).toDouble();
    }
  }
  return null;
}

List<String> extractArrGenres(dynamic genres) =>
    genres is List ? genres.whereType<String>().toList() : const [];

/// Profil de qualité (`GET /api/v3/qualityprofile`) — même ressource pour
/// Radarr et Sonarr.
class ArrQualityProfile {
  final int id;
  final String name;
  const ArrQualityProfile({required this.id, required this.name});

  factory ArrQualityProfile.fromJson(Map<String, dynamic> json) =>
      ArrQualityProfile(
        id: json['id'] as int? ?? 0,
        name: json['name'] as String? ?? '',
      );
}

/// Dossier racine (`GET /api/v3/rootfolder`) — même ressource pour Radarr
/// et Sonarr.
class ArrRootFolder {
  final int id;
  final String path;
  const ArrRootFolder({required this.id, required this.path});

  factory ArrRootFolder.fromJson(Map<String, dynamic> json) => ArrRootFolder(
        id: json['id'] as int? ?? 0,
        path: json['path'] as String? ?? '',
      );
}

/// Une saison d'une série (`series.seasons[]`, imbriqué dans `GET
/// /api/v3/series/{id}`) — épisodes présents/total et surveillance,
/// affichés tels quels dans la fiche détail (pas un sélecteur, cf.
/// `ArrSeasonEpisodePicker` pour la recherche interactive).
class ArrSeasonSummary {
  final int seasonNumber;
  final bool monitored;
  final int episodeCount;
  final int episodeFileCount;

  const ArrSeasonSummary({
    required this.seasonNumber,
    required this.monitored,
    required this.episodeCount,
    required this.episodeFileCount,
  });

  factory ArrSeasonSummary.fromJson(Map<String, dynamic> json) {
    final statistics = json['statistics'];
    return ArrSeasonSummary(
      seasonNumber: json['seasonNumber'] as int? ?? 0,
      monitored: json['monitored'] as bool? ?? false,
      episodeCount:
          statistics is Map ? (statistics['episodeCount'] as int? ?? 0) : 0,
      episodeFileCount:
          statistics is Map ? (statistics['episodeFileCount'] as int? ?? 0) : 0,
    );
  }
}

/// Fiche détail d'un film (`GET /api/v3/movie/{id}`) — au-delà des champs
/// déjà connus de [ArrMovie] (utilisés pour la grille), ajoute tout ce
/// qu'une fiche détail montre : résumé, durée, genres, note, profil de
/// qualité, dossier, taille sur disque, et — fichier présent — sa
/// qualité/codec/source.
class ArrMovieDetail {
  final int id;
  final String title;
  final int? year;
  final String? overview;
  final int? runtimeMinutes;
  final List<String> genres;
  final double? rating;
  final String? posterUrl;
  final String? fanartUrl;
  final bool monitored;
  final int qualityProfileId;
  final String? rootFolderPath;

  /// Chemin réel du dossier du film (`path`) — pas seulement son dossier
  /// racine : nécessaire pour recomputer un nouveau chemin en gardant le
  /// même nom de dossier si le dossier racine change (cf.
  /// [RadarrApiClient.updateMovie]).
  final String? path;
  final int? sizeOnDisk;
  final bool hasFile;
  final String? fileQualityName;
  final String? fileSource;
  final String? fileCodec;
  final int? tmdbId;
  final String? imdbId;

  /// Corps JSON brut — même raison que [ArrMovie.raw] : Radarr exige le
  /// corps complet sur `PUT`.
  final Map<String, dynamic> raw;

  const ArrMovieDetail({
    required this.id,
    required this.title,
    required this.year,
    required this.overview,
    required this.runtimeMinutes,
    required this.genres,
    required this.rating,
    required this.posterUrl,
    required this.fanartUrl,
    required this.monitored,
    required this.qualityProfileId,
    required this.rootFolderPath,
    required this.path,
    required this.sizeOnDisk,
    required this.hasFile,
    required this.fileQualityName,
    required this.fileSource,
    required this.fileCodec,
    required this.tmdbId,
    required this.imdbId,
    required this.raw,
  });

  factory ArrMovieDetail.fromJson(
    Map<String, dynamic> json, {
    required String baseUrl,
    required String apiKey,
  }) {
    final movieFile = json['movieFile'];
    String? fileQualityName;
    String? fileSource;
    String? fileCodec;
    if (movieFile is Map) {
      final quality = movieFile['quality'];
      if (quality is Map) {
        final inner = quality['quality'];
        if (inner is Map) {
          fileQualityName = inner['name'] as String?;
          fileSource = inner['source'] as String?;
        }
      }
      final mediaInfo = movieFile['mediaInfo'];
      if (mediaInfo is Map) fileCodec = mediaInfo['videoCodec'] as String?;
    }
    return ArrMovieDetail(
      id: json['id'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      year: json['year'] as int?,
      overview: json['overview'] as String?,
      runtimeMinutes: json['runtime'] as int?,
      genres: extractArrGenres(json['genres']),
      rating: extractArrRating(json['ratings']),
      posterUrl:
          resolveArrPosterUrl(json['images'], baseUrl: baseUrl, apiKey: apiKey),
      fanartUrl:
          resolveArrFanartUrl(json['images'], baseUrl: baseUrl, apiKey: apiKey),
      monitored: json['monitored'] as bool? ?? false,
      qualityProfileId: json['qualityProfileId'] as int? ?? 0,
      rootFolderPath: json['rootFolderPath'] as String?,
      path: json['path'] as String?,
      sizeOnDisk: json['sizeOnDisk'] as int?,
      hasFile: json['hasFile'] as bool? ?? false,
      fileQualityName: fileQualityName,
      fileSource: fileSource,
      fileCodec: fileCodec,
      tmdbId: json['tmdbId'] as int?,
      imdbId: json['imdbId'] as String?,
      raw: json,
    );
  }
}

/// Fiche détail d'une série (`GET /api/v3/series/{id}`) — équivalent
/// [ArrMovieDetail] pour Sonarr : pas de fichier/qualité unique (varie
/// par épisode), mais la liste des saisons ([seasons]).
class ArrSeriesDetail {
  final int id;
  final String title;
  final int? year;
  final String? overview;

  /// Durée d'un épisode, en minutes — pas une durée totale de série.
  final int? runtimeMinutes;
  final List<String> genres;
  final double? rating;
  final String? posterUrl;
  final String? fanartUrl;
  final bool monitored;
  final int qualityProfileId;
  final String? rootFolderPath;
  final String? path;
  final int? sizeOnDisk;
  final int episodeCount;
  final int episodeFileCount;
  final List<ArrSeasonSummary> seasons;
  final int? tvdbId;
  final String? imdbId;

  /// Corps JSON brut — même raison que [ArrSeries.raw].
  final Map<String, dynamic> raw;

  const ArrSeriesDetail({
    required this.id,
    required this.title,
    required this.year,
    required this.overview,
    required this.runtimeMinutes,
    required this.genres,
    required this.rating,
    required this.posterUrl,
    required this.fanartUrl,
    required this.monitored,
    required this.qualityProfileId,
    required this.rootFolderPath,
    required this.path,
    required this.sizeOnDisk,
    required this.episodeCount,
    required this.episodeFileCount,
    required this.seasons,
    required this.tvdbId,
    required this.imdbId,
    required this.raw,
  });

  factory ArrSeriesDetail.fromJson(
    Map<String, dynamic> json, {
    required String baseUrl,
    required String apiKey,
  }) {
    final statistics = json['statistics'];
    final rawSeasons = json['seasons'];
    return ArrSeriesDetail(
      id: json['id'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      year: json['year'] as int?,
      overview: json['overview'] as String?,
      runtimeMinutes: json['runtime'] as int?,
      genres: extractArrGenres(json['genres']),
      rating: extractArrRating(json['ratings']),
      posterUrl:
          resolveArrPosterUrl(json['images'], baseUrl: baseUrl, apiKey: apiKey),
      fanartUrl:
          resolveArrFanartUrl(json['images'], baseUrl: baseUrl, apiKey: apiKey),
      monitored: json['monitored'] as bool? ?? false,
      qualityProfileId: json['qualityProfileId'] as int? ?? 0,
      rootFolderPath: json['rootFolderPath'] as String?,
      path: json['path'] as String?,
      sizeOnDisk: statistics is Map ? (statistics['sizeOnDisk'] as int?) : null,
      episodeCount:
          statistics is Map ? (statistics['episodeCount'] as int? ?? 0) : 0,
      episodeFileCount:
          statistics is Map ? (statistics['episodeFileCount'] as int? ?? 0) : 0,
      seasons: rawSeasons is List
          ? rawSeasons
              .whereType<Map<String, dynamic>>()
              .map(ArrSeasonSummary.fromJson)
              .toList()
          : const [],
      tvdbId: json['tvdbId'] as int?,
      imdbId: json['imdbId'] as String?,
      raw: json,
    );
  }
}

/// Film ou série — l'un des deux champs est renseigné, jamais les deux.
/// Même principe qu'[ArrLibraryEntry], pour la fiche détail : évite à
/// l'écran de distinguer les deux cas partout.
class ArrDetailEntry {
  final ArrMovieDetail? movie;
  final ArrSeriesDetail? series;

  const ArrDetailEntry.movie(this.movie) : series = null;
  const ArrDetailEntry.series(this.series) : movie = null;

  bool get isMovie => movie != null;
  int get id => movie?.id ?? series!.id;
  String get title => movie?.title ?? series!.title;
  int? get year => movie?.year ?? series?.year;
  String? get overview => movie?.overview ?? series?.overview;
  int? get runtimeMinutes => movie?.runtimeMinutes ?? series?.runtimeMinutes;
  List<String> get genres => movie?.genres ?? series?.genres ?? const [];
  double? get rating => movie?.rating ?? series?.rating;
  String? get posterUrl => movie?.posterUrl ?? series?.posterUrl;
  String? get fanartUrl => movie?.fanartUrl ?? series?.fanartUrl;
  bool get monitored => movie?.monitored ?? series?.monitored ?? false;
  int get qualityProfileId =>
      movie?.qualityProfileId ?? series?.qualityProfileId ?? 0;
  String? get rootFolderPath => movie?.rootFolderPath ?? series?.rootFolderPath;
  String? get path => movie?.path ?? series?.path;
  int? get sizeOnDisk => movie?.sizeOnDisk ?? series?.sizeOnDisk;
  int? get tmdbId => movie?.tmdbId;
  int? get tvdbId => series?.tvdbId;
  String? get imdbId => movie?.imdbId ?? series?.imdbId;
}
