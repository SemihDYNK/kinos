import 'package:kinos/recommendations/models/trait.dart';

class LetterboxdFilm {
  final String uri;
  final String title;
  final int? year;
  final double? rating;
  final DateTime? ratedAt;
  final DateTime? watchedAt;
  final int watches;
  const LetterboxdFilm(
      {required this.uri,
      required this.title,
      this.year,
      this.rating,
      this.ratedAt,
      this.watchedAt,
      this.watches = 1});

  double get weight {
    if (rating == null) return watches > 1 ? 2 : 1;
    final value = (rating! - 3) * .75;
    return watches > 1 && value > 0
        ? (value * 4 / 3).clamp(0, 2).toDouble()
        : value;
  }

  Map<String, dynamic> toJson() => {
        'uri': uri,
        'title': title,
        'year': year,
        'rating': rating,
        'ratedAt': ratedAt?.toIso8601String(),
        'watchedAt': watchedAt?.toIso8601String(),
        'watches': watches
      };
  factory LetterboxdFilm.fromJson(Map<String, dynamic> json) {
    final uri = letterboxdFilmUri(json['uri'] as String);
    final title = json['title'] as String;
    final year = json['year'] as int?;
    final rating = (json['rating'] as num?)?.toDouble();
    final watches = json['watches'] as int;
    if (title.trim().isEmpty ||
        title.length > 2000 ||
        (year != null && (year < 1850 || year > 2200)) ||
        (rating != null &&
            (!rating.isFinite ||
                rating < .5 ||
                rating > 5 ||
                rating * 2 != (rating * 2).roundToDouble())) ||
        watches < 1 ||
        watches > 200000) {
      throw const FormatException('Film');
    }
    return LetterboxdFilm(
        uri: uri,
        title: title,
        year: year,
        rating: rating,
        watches: watches,
        ratedAt: json['ratedAt'] == null
            ? null
            : DateTime.parse(json['ratedAt'] as String),
        watchedAt: json['watchedAt'] == null
            ? null
            : DateTime.parse(json['watchedAt'] as String));
  }
}

String letterboxdFilmUri(String raw) {
  if (raw.startsWith('urn:kinos:letterboxd:') &&
      raw.length < 4000 &&
      RegExp(r'^urn:kinos:letterboxd:[A-Za-z0-9_=\-]+$').hasMatch(raw)) {
    return raw;
  }
  final uri = Uri.tryParse(raw.trim());
  if (uri != null &&
      ['http', 'https'].contains(uri.scheme) &&
      uri.host == 'boxd.it' &&
      uri.userInfo.isEmpty &&
      !uri.hasPort &&
      uri.pathSegments.where((s) => s.isNotEmpty).length == 1 &&
      RegExp(r'^[A-Za-z0-9]+$').hasMatch(uri.pathSegments.first)) {
    return 'https://boxd.it/${uri.pathSegments.first}';
  }
  if (uri == null ||
      !['https', 'http'].contains(uri.scheme) ||
      !['letterboxd.com', 'www.letterboxd.com'].contains(uri.host) ||
      uri.userInfo.isNotEmpty ||
      uri.hasPort ||
      uri.pathSegments.where((s) => s.isNotEmpty).length != 2 ||
      uri.pathSegments.first != 'film' ||
      uri.pathSegments[1].isEmpty) {
    throw const FormatException('Letterboxd URI');
  }
  return 'https://letterboxd.com/film/${uri.pathSegments[1]}/';
}

class LetterboxdWork {
  final String title;
  final int? year;
  final String? jellyfinId;
  final int? tmdbId;
  final List<TraitKey> traits;
  final List<String> aliases;
  const LetterboxdWork(
      {required this.title,
      this.year,
      this.jellyfinId,
      this.tmdbId,
      this.aliases = const [],
      required this.traits});
  String get identity =>
      tmdbId != null ? 'tmdb:movie:$tmdbId' : 'jellyfin:$jellyfinId';
  Map<String, dynamic> toJson() => {
        'title': title,
        'aliases': aliases,
        'year': year,
        'jellyfinId': jellyfinId,
        'tmdbId': tmdbId,
        'traits': [
          for (final t in traits) {'kind': t.kind.name, 'value': t.value}
        ]
      };
  factory LetterboxdWork.fromJson(Map<String, dynamic> json) {
    final id = json['tmdbId'] as int?;
    final local = json['jellyfinId'] as String?;
    final values = json['traits'] as List;
    if ((id == null && (local == null || local.isEmpty)) ||
        (id != null && id <= 0) ||
        values.length > 500) {
      throw const FormatException('Work');
    }
    return LetterboxdWork(
        title: json['title'] as String,
        year: json['year'] as int?,
        tmdbId: id,
        aliases: List<String>.from(json['aliases'] as List? ?? const []),
        jellyfinId: local,
        traits: [
          for (final t in values)
            trait(TraitKind.values.byName(t['kind'] as String),
                t['value'] as String)
        ]);
  }
}

class LetterboxdRecord {
  final LetterboxdFilm film;
  final LetterboxdWork? work;
  final List<LetterboxdWork> choices;
  const LetterboxdRecord(this.film, {this.work, this.choices = const []});
  Map<String, dynamic> toJson() =>
      {'film': film.toJson(), 'work': work?.toJson()};
  factory LetterboxdRecord.fromJson(Map<String, dynamic> json) =>
      LetterboxdRecord(
          LetterboxdFilm.fromJson(
              Map<String, dynamic>.from(json['film'] as Map)),
          work: json['work'] == null
              ? null
              : LetterboxdWork.fromJson(
                  Map<String, dynamic>.from(json['work'] as Map)));
}

class LetterboxdSnapshot {
  final DateTime? updatedAt;
  final List<LetterboxdRecord> records;
  const LetterboxdSnapshot({this.updatedAt, this.records = const []});
  int get matched =>
      records.where((r) => r.work?.traits.isNotEmpty == true).length;
  Map<String, dynamic> toJson() => {
        'version': 1,
        'updatedAt': updatedAt?.toIso8601String(),
        'records': records.map((r) => r.toJson()).toList()
      };
  factory LetterboxdSnapshot.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1 ||
        json['records'] is! List ||
        (json['records'] as List).length > 20000) {
      throw const FormatException('Snapshot');
    }
    return LetterboxdSnapshot(
        updatedAt: json['updatedAt'] == null
            ? null
            : DateTime.parse(json['updatedAt'] as String),
        records: [
          for (final r in json['records'] as List)
            LetterboxdRecord.fromJson(Map<String, dynamic>.from(r as Map))
        ]);
  }
}
