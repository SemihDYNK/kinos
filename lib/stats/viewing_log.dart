import 'dart:convert';
import 'dart:isolate';

import 'package:kinos/models/syncing/database_item.dart';

/// D'où vient une séance.
enum ViewingSource {
  /// Lue dans Kinos : date, durée regardée exactes.
  kinos,

  /// Journal Letterboxd (export ou flux) : la date, au jour près.
  letterboxd,

  /// Dernière lecture connue de Jellyfin, en dernier recours.
  jellyfin,
}

/// Une séance : un film ou un épisode vu un jour donné.
class ViewingEvent {
  const ViewingEvent({
    required this.identity,
    required this.kind,
    required this.title,
    required this.at,
    this.seriesTitle,
    this.season,
    this.episode,
    this.watchedSeconds = 0,
    this.runtimeSeconds,
    this.completed = true,
    this.sources = const {},
    this.jellyfinId,
    this.tmdbId,
    this.year,
    this.genres = const [],
    this.directors = const [],
    this.cast = const [],
    this.studios = const [],
    this.rewatch = false,
  });

  /// `tmdb:movie:<id>` quand on le connaît, sinon `jellyfin:<id>` ou
  /// `letterboxd:<slug>` : deux sources qui parlent du même film le même
  /// jour se rejoignent.
  final String identity;

  /// `movie` ou `episode`.
  final String kind;
  final String title;
  final String? seriesTitle;
  final int? season;
  final int? episode;

  /// Début de la séance (heure locale ; minuit si seul le jour est connu).
  final DateTime at;

  /// Temps réellement regardé (Kinos) ; 0 si inconnu.
  final int watchedSeconds;
  final int? runtimeSeconds;
  final bool completed;
  final Set<ViewingSource> sources;
  final String? jellyfinId;
  final int? tmdbId;
  final int? year;
  final List<String> genres;
  final List<String> directors;

  /// Rôles principaux (trois premiers).
  final List<String> cast;
  final List<String> studios;
  final bool rewatch;

  bool get isMovie => kind == 'movie';

  /// Durée retenue pour les statistiques : le temps regardé, sinon la durée
  /// du titre s'il a été vu en entier.
  int get seconds => watchedSeconds > 0
      ? watchedSeconds
      : (completed ? (runtimeSeconds ?? 0) : 0);

  static String dayOf(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Clé de la séance : un même titre, un même jour.
  String get key => 'v:${dayOf(at)}:$identity';

  /// Réunit deux relevés de la même séance : les durées Kinos s'ajoutent
  /// (une séance reprise), les métadonnées les plus riches restent.
  ViewingEvent merge(ViewingEvent other) {
    List<String> pick(List<String> a, List<String> b) => a.isNotEmpty ? a : b;
    final kinos = sources.contains(ViewingSource.kinos) &&
        other.sources.contains(ViewingSource.kinos);
    return ViewingEvent(
      identity: identity,
      kind: kind,
      title: title.isNotEmpty ? title : other.title,
      seriesTitle: seriesTitle ?? other.seriesTitle,
      season: season ?? other.season,
      episode: episode ?? other.episode,
      at: _earliestTimed(at, other.at),
      watchedSeconds: kinos
          ? watchedSeconds + other.watchedSeconds
          : (watchedSeconds > other.watchedSeconds
              ? watchedSeconds
              : other.watchedSeconds),
      runtimeSeconds: runtimeSeconds ?? other.runtimeSeconds,
      completed: completed || other.completed,
      sources: {...sources, ...other.sources},
      jellyfinId: jellyfinId ?? other.jellyfinId,
      tmdbId: tmdbId ?? other.tmdbId,
      year: year ?? other.year,
      genres: pick(genres, other.genres),
      directors: pick(directors, other.directors),
      cast: pick(cast, other.cast),
      studios: pick(studios, other.studios),
      rewatch: rewatch || other.rewatch,
    );
  }

  // Une heure connue (Kinos) l'emporte sur un jour seul (Letterboxd, à
  // minuit) ; entre deux heures, la plus tôt.
  static DateTime _earliestTimed(DateTime a, DateTime b) {
    bool timed(DateTime d) => d.hour != 0 || d.minute != 0 || d.second != 0;
    if (timed(a) != timed(b)) return timed(a) ? a : b;
    return a.isBefore(b) ? a : b;
  }

  Map<String, Object?> toJson() => {
        'i': identity,
        'k': kind,
        'n': title,
        if (seriesTitle != null) 'sn': seriesTitle,
        if (season != null) 's': season,
        if (episode != null) 'e': episode,
        't': at.millisecondsSinceEpoch,
        if (watchedSeconds > 0) 'w': watchedSeconds,
        if (runtimeSeconds != null) 'r': runtimeSeconds,
        if (!completed) 'c': false,
        'o': [for (final s in sources) s.name],
        if (jellyfinId != null) 'j': jellyfinId,
        if (tmdbId != null) 'tm': tmdbId,
        if (year != null) 'y': year,
        if (genres.isNotEmpty) 'g': genres,
        if (directors.isNotEmpty) 'd': directors,
        if (cast.isNotEmpty) 'a': cast,
        if (studios.isNotEmpty) 'st': studios,
        if (rewatch) 'rw': true,
      };

  static List<String> _strings(Object? value) => [
        if (value is List)
          for (final v in value)
            if (v is String) v
      ];

  static ViewingEvent? fromJson(Object? json) {
    if (json is! Map) return null;
    final identity = json['i'], kind = json['k'], title = json['n'];
    final t = json['t'];
    if (identity is! String ||
        (kind != 'movie' && kind != 'episode') ||
        title is! String ||
        t is! int) {
      return null;
    }
    int? integer(Object? v) => v is int ? v : null;
    return ViewingEvent(
      identity: identity,
      kind: kind as String,
      title: title,
      seriesTitle: json['sn'] is String ? json['sn'] as String : null,
      season: integer(json['s']),
      episode: integer(json['e']),
      at: DateTime.fromMillisecondsSinceEpoch(t),
      watchedSeconds: integer(json['w']) ?? 0,
      runtimeSeconds: integer(json['r']),
      completed: json['c'] != false,
      sources: {
        for (final s in _strings(json['o']))
          if (ViewingSource.values.asNameMap()[s] case final source?) source
      },
      jellyfinId: json['j'] is String ? json['j'] as String : null,
      tmdbId: integer(json['tm']),
      year: integer(json['y']),
      genres: _strings(json['g']),
      directors: _strings(json['d']),
      cast: _strings(json['a']),
      studios: _strings(json['st']),
      rewatch: json['rw'] == true,
    );
  }
}

/// Le journal de visionnage d'un profil, une ligne par séance dans la
/// table `Settings` (pas de nouvelle table, donc pas de migration).
class ViewingLogStore {
  ViewingLogStore(this.db, String profileScope)
      : scope = '$profileScope:viewing:v1';
  final AppDatabase db;
  final String scope;

  /// Ajoute des séances, fusionnées avec celles déjà notées le même jour.
  Future<void> addAll(Iterable<ViewingEvent> events) async {
    final byKey = <String, ViewingEvent>{};
    for (final event in events) {
      final known = byKey[event.key];
      byKey[event.key] = known == null ? event : known.merge(event);
    }
    if (byKey.isEmpty) return;
    await db.transaction(() async {
      for (final MapEntry(key: key, value: event) in byKey.entries) {
        final row = await db.getSetting(key, scope: scope);
        final known = row == null ? null : _decode(row.value);
        final merged = known == null ? event : known.merge(event);
        await db.setSetting(key, jsonEncode(merged.toJson()), scope: scope);
      }
    });
  }

  Future<void> add(ViewingEvent event) => addAll([event]);

  /// Toutes les séances, décodées hors du fil de l'interface.
  Future<List<ViewingEvent>> all() async {
    final values = [
      for (final row in await db.getSettingsForScope(scope).get())
        if (row.key.startsWith('v:')) row.value
    ];
    return Isolate.run(() => values.map(_decode).nonNulls.toList());
  }

  /// Oublie les séances venues de [source] (avant de les relire).
  Future<void> removeSource(ViewingSource source) async {
    await db.transaction(() async {
      for (final row in await db.getSettingsForScope(scope).get()) {
        if (!row.key.startsWith('v:')) continue;
        final event = _decode(row.value);
        if (event == null || !event.sources.contains(source)) continue;
        if (event.sources.length == 1) {
          await db.deleteSetting(row.key, scope: scope);
        }
      }
    });
  }

  static ViewingEvent? _decode(String value) {
    try {
      return ViewingEvent.fromJson(jsonDecode(value));
    } on FormatException {
      return null;
    }
  }
}
