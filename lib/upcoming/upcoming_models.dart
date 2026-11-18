import 'package:kinos/models/seerr/seerr_dashboard_model.dart'
    show SeerrMediaStatus;

/// Ce que l'on peut suivre : une personne, un studio, une chaîne, une saga
/// ou une série. Identifiants TMDB.
enum UpcomingFollowKind { person, company, network, collection, tv }

/// Pour une personne : le métier suivi.
enum UpcomingRole { acting, directing }

class UpcomingFollow {
  const UpcomingFollow(
      {required this.kind,
      required this.id,
      required this.name,
      this.image,
      this.role});

  final UpcomingFollowKind kind;
  final int id;
  final String name;

  /// Chemin TMDB relatif (photo, logo, affiche), ou null.
  final String? image;
  final UpcomingRole? role;

  String get key => '${kind.name}:$id${role == null ? '' : ':${role!.name}'}';

  Map<String, Object?> toJson() => {
        'k': kind.name,
        'i': id,
        'n': name,
        if (image != null) 'p': image,
        if (role != null) 'r': role!.name,
      };

  static UpcomingFollow? fromJson(Object? json) {
    if (json is! Map) return null;
    final kind = UpcomingFollowKind.values.asNameMap()[json['k']];
    final id = json['i'], name = json['n'], image = json['p'];
    if (kind == null || id is! int || id <= 0 || name is! String) return null;
    return UpcomingFollow(
        kind: kind,
        id: id,
        name: name,
        image: tmdbPath(image),
        role: UpcomingRole.values.asNameMap()[json['r']]);
  }
}

/// Type de la date affichée.
enum UpcomingRelease {
  /// Sortie en salle.
  theatrical,
  digital,
  physical,
  television,

  /// Premier épisode d'une nouvelle série.
  premiere,

  /// Premier épisode d'une nouvelle saison.
  season,
  episode,

  /// Annoncé, sans date.
  unknown,
}

/// Un titre à venir, prêt à afficher.
class UpcomingEntry {
  const UpcomingEntry({
    required this.type,
    required this.id,
    required this.title,
    required this.release,
    this.date,
    this.posterPath,
    this.backdropPath,
    this.season,
    this.episode,
    this.outsideRegion = false,
    this.reasons = const [],
    this.big = false,
    this.status = SeerrMediaStatus.unknown,
    this.jellyfinId,
    this.popularity = 0,
    this.overview = '',
    this.genres = const [],
  });

  /// `movie` ou `tv`.
  final String type;
  final int id;
  final String title;
  final DateTime? date;
  final UpcomingRelease release;
  final String? posterPath;
  final String? backdropPath;
  final int? season;
  final int? episode;

  /// Pas de date connue dans la région : date mondiale.
  final bool outsideRegion;

  /// Pourquoi il est là : « Denis Villeneuve », « Saga Dune », « A24 ».
  final List<String> reasons;

  /// Parmi les grandes sorties.
  final bool big;
  final SeerrMediaStatus status;

  /// Déjà dans Jellyfin (statut Seerr), pour ouvrir sa fiche.
  final String? jellyfinId;
  final double popularity;

  /// Synopsis et genres, pour le bandeau.
  final String overview;
  final List<String> genres;

  bool get isMovie => type == 'movie';
  String get identity => 'tmdb:$type:$id';

  /// Demandé ou déjà disponible : pas de « À demander ».
  bool get requested =>
      status != SeerrMediaStatus.unknown &&
      status != SeerrMediaStatus.deleted &&
      status != SeerrMediaStatus.blacklisted;

  UpcomingEntry copyWith({List<String>? reasons, bool? big}) => UpcomingEntry(
      type: type,
      id: id,
      title: title,
      release: release,
      date: date,
      posterPath: posterPath,
      backdropPath: backdropPath,
      season: season,
      episode: episode,
      outsideRegion: outsideRegion,
      reasons: reasons ?? this.reasons,
      big: big ?? this.big,
      status: status,
      jellyfinId: jellyfinId,
      popularity: popularity,
      overview: overview,
      genres: genres);

  Map<String, Object?> toJson() => {
        't': type,
        'i': id,
        'n': title,
        'r': release.name,
        if (date != null) 'd': date!.millisecondsSinceEpoch,
        if (posterPath != null) 'p': posterPath,
        if (backdropPath != null) 'b': backdropPath,
        if (season != null) 's': season,
        if (episode != null) 'e': episode,
        if (outsideRegion) 'o': true,
        'w': reasons,
        if (big) 'g': true,
        'st': status.index,
        if (jellyfinId != null) 'j': jellyfinId,
        'pop': popularity,
        if (overview.isNotEmpty) 'ov': overview,
        if (genres.isNotEmpty) 'gn': genres,
      };

  static UpcomingEntry? fromJson(Object? json) {
    if (json is! Map) return null;
    final type = json['t'], id = json['i'], title = json['n'];
    final release = UpcomingRelease.values.asNameMap()[json['r']];
    if ((type != 'movie' && type != 'tv') ||
        id is! int ||
        title is! String ||
        release == null) {
      return null;
    }
    final d = json['d'], st = json['st'], pop = json['pop'], j = json['j'];
    return UpcomingEntry(
        type: type as String,
        id: id,
        title: title,
        release: release,
        date: d is int ? DateTime.fromMillisecondsSinceEpoch(d) : null,
        posterPath: tmdbPath(json['p']),
        backdropPath: tmdbPath(json['b']),
        season: json['s'] is int ? json['s'] as int : null,
        episode: json['e'] is int ? json['e'] as int : null,
        outsideRegion: json['o'] == true,
        reasons: [
          if (json['w'] is List)
            for (final r in json['w'] as List)
              if (r is String) r
        ],
        big: json['g'] == true,
        status: st is int && st >= 0 && st < SeerrMediaStatus.values.length
            ? SeerrMediaStatus.values[st]
            : SeerrMediaStatus.unknown,
        jellyfinId: j is String && j.isNotEmpty ? j : null,
        popularity: pop is num ? pop.toDouble() : 0,
        overview: json['ov'] is String ? json['ov'] as String : '',
        genres: [
          if (json['gn'] is List)
            for (final g in json['gn'] as List)
              if (g is String) g
        ]);
  }
}

/// Seuls les chemins TMDB relatifs sont gardés, jamais une adresse
/// arbitraire.
String? tmdbPath(Object? value) =>
    value is String && value.startsWith('/') && !value.startsWith('//')
        ? value
        : null;

String tmdbImage(String path, {String size = 'w500'}) =>
    'https://image.tmdb.org/t/p/$size$path';
