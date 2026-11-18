import 'package:kinos/models/seerr/seerr_dashboard_model.dart'
    show SeerrMediaStatus;

import '../upcoming_logic.dart' show parseTmdbDate;
import '../upcoming_models.dart';

/// Un titre de la filmographie d'une personne ou du catalogue d'un studio,
/// d'une chaîne ou d'une saga, lu dans Seerr.
class EntityTitle {
  const EntityTitle({
    required this.type,
    required this.id,
    required this.title,
    this.date,
    this.posterPath,
    this.backdropPath,
    this.character,
    this.episodes,
    this.popularity = 0,
    this.vote = 0,
    this.status = SeerrMediaStatus.unknown,
    this.jellyfinId,
  });

  /// `movie` ou `tv`.
  final String type;
  final int id;
  final String title;
  final DateTime? date;
  final String? posterPath;
  final String? backdropPath;

  /// Rôle tenu (personne, interprétation).
  final String? character;

  /// Épisodes tournés (personne, série).
  final int? episodes;
  final double popularity;
  final double vote;
  final SeerrMediaStatus status;
  final String? jellyfinId;

  String get identity => 'tmdb:$type:$id';
  bool get isMovie => type == 'movie';

  /// Déjà dans Jellyfin.
  bool get inLibrary =>
      jellyfinId != null ||
      status == SeerrMediaStatus.available ||
      status == SeerrMediaStatus.partiallyAvailable;

  /// Pas encore sorti (ou sans date).
  bool upcoming(DateTime today) {
    final d = date;
    return d == null ||
        !d.isBefore(DateTime(today.year, today.month, today.day));
  }

  /// Une entrée de la frise, pour réutiliser ses tuiles.
  UpcomingEntry toEntry() => UpcomingEntry(
      type: type,
      id: id,
      title: title,
      date: date,
      release: date == null
          ? UpcomingRelease.unknown
          : type == 'movie'
              ? UpcomingRelease.theatrical
              : UpcomingRelease.premiere,
      posterPath: posterPath,
      backdropPath: backdropPath,
      status: status,
      jellyfinId: jellyfinId,
      popularity: popularity);

  static EntityTitle? fromJson(Map<String, dynamic> json, {String? type}) {
    final kind = type ?? json['mediaType'];
    final id = json['id'];
    if ((kind != 'movie' && kind != 'tv') || id is! int) return null;
    final title = json[kind == 'movie' ? 'title' : 'name'];
    if (title is! String || title.isEmpty) return null;
    final info = json['mediaInfo'];
    final jellyfin = info is Map ? info['jellyfinMediaId'] : null;
    final popularity = json['popularity'], vote = json['voteAverage'];
    final episodes = json['episodeCount'];
    final character = json['character'];
    return EntityTitle(
        type: kind as String,
        id: id,
        title: title,
        date: parseTmdbDate(
            json[kind == 'movie' ? 'releaseDate' : 'firstAirDate']),
        posterPath: tmdbPath(json['posterPath']),
        backdropPath: tmdbPath(json['backdropPath']),
        character:
            character is String && character.isNotEmpty ? character : null,
        episodes: episodes is int ? episodes : null,
        popularity: popularity is num ? popularity.toDouble() : 0,
        vote: vote is num ? vote.toDouble() : 0,
        status: info is Map
            ? SeerrMediaStatus.fromRaw(info['status'] as int?)
            : SeerrMediaStatus.unknown,
        jellyfinId:
            jellyfin is String && jellyfin.isNotEmpty ? jellyfin : null);
  }
}

/// L'en-tête d'une page : nom, image, une ligne de contexte.
class EntityHeader {
  const EntityHeader(
      {required this.name,
      this.image,
      this.backdrop,
      this.context = '',
      this.biography,
      this.knownFor});
  final String name;

  /// Photo ou logo (chemin TMDB).
  final String? image;

  /// Image de fond (saga).
  final String? backdrop;
  final String context;
  final String? biography;

  /// Métier principal d'une personne (`Acting`, `Directing`).
  final String? knownFor;
}

final _notARole = RegExp(
    r'^(self|himself|herself|themselves|lui-même|elle-même)\b|\(voice\)|\(uncredited\)|\(archive',
    caseSensitive: false);

/// Un rôle qui ne compte pas comme un rôle : apparition dans son propre
/// rôle, voix, non crédité, images d'archive.
bool isAppearance(EntityTitle title) {
  final character = title.character;
  if (character != null && _notARole.hasMatch(character)) return true;
  if (!title.isMovie) return (title.episodes ?? 0) < 6;
  return false;
}
