/// Film de la bibliothèque Radarr (`GET /api/v3/movie`) — juste de quoi
/// chercher et lancer une recherche interactive, pas les détails complets.
class ArrMovie {
  final int id;
  final String title;
  final int? year;

  const ArrMovie({required this.id, required this.title, required this.year});

  factory ArrMovie.fromJson(Map<String, dynamic> json) => ArrMovie(
        id: json['id'] as int? ?? 0,
        title: json['title'] as String? ?? '',
        year: json['year'] as int?,
      );
}

/// Série de la bibliothèque Sonarr (`GET /api/v3/series`).
class ArrSeries {
  final int id;
  final String title;
  final int? year;

  const ArrSeries({required this.id, required this.title, required this.year});

  factory ArrSeries.fromJson(Map<String, dynamic> json) => ArrSeries(
        id: json['id'] as int? ?? 0,
        title: json['title'] as String? ?? '',
        year: json['year'] as int?,
      );
}

/// Épisode d'une série Sonarr (`GET /api/v3/episode?seriesId=`) — sert au
/// sélecteur saison/épisode une fois la série choisie.
class ArrEpisode {
  final int id;
  final int seriesId;
  final int seasonNumber;
  final int episodeNumber;
  final String title;

  const ArrEpisode({
    required this.id,
    required this.seriesId,
    required this.seasonNumber,
    required this.episodeNumber,
    required this.title,
  });

  factory ArrEpisode.fromJson(Map<String, dynamic> json) => ArrEpisode(
        id: json['id'] as int? ?? 0,
        seriesId: json['seriesId'] as int? ?? 0,
        seasonNumber: json['seasonNumber'] as int? ?? 0,
        episodeNumber: json['episodeNumber'] as int? ?? 0,
        title: json['title'] as String? ?? '',
      );
}
