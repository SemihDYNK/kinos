import 'dart:collection';
import 'dart:convert';

enum AnilistTargetKind { movie, series, season }

enum AnilistMatchStatus { exact, needsConfirmation, notFound, unavailable }

enum AnilistMatchReason {
  conflictingIds,
  splitSeason,
  seasonUnproven,
  changedIds,
  invalidSource,
  network
}

int? positiveId(Object? value) {
  if (value is! String && value is! int) return null;
  final id = int.tryParse(value.toString().trim());
  return id != null && id > 0 ? id : null;
}

class AnilistIds {
  final Map<String, String> values;
  final bool conflicting;
  final bool known;
  const AnilistIds._(this.values, this.conflicting, this.known);
  factory AnilistIds.from(Map<String, Object?>? raw) {
    final ids = SplayTreeMap<String, String>();
    var conflicting = false;
    for (final entry in (raw ?? <String, Object?>{}).entries) {
      final key = switch (entry.key.trim().toLowerCase()) {
        'anilist' => 'anilist',
        'myanimelist' || 'mal' => 'mal',
        'anidb' => 'anidb',
        'tmdb' => 'tmdb',
        'tvdb' => 'tvdb',
        'imdb' => 'imdb',
        _ => null,
      };
      if (key == null) continue;
      final value = key == 'imdb'
          ? (entry.value is String &&
                  RegExp(r'^tt\d+$').hasMatch((entry.value as String).trim())
              ? (entry.value as String).trim()
              : null)
          : positiveId(entry.value)?.toString();
      if (value == null) continue;
      if (ids.containsKey(key) && ids[key] != value) conflicting = true;
      ids[key] = value;
    }
    return AnilistIds._(Map.unmodifiable(ids), conflicting, raw != null);
  }
  Object get fingerprint => [known, conflicting, values];
}

class AnilistTarget {
  final String itemId;
  final String title;
  final AnilistTargetKind kind;
  final AnilistIds ids;
  final AnilistIds parentIds;
  final int? season;
  final String? seasonSource;
  AnilistTarget(
      {required this.itemId,
      required this.title,
      required this.kind,
      Map<String, Object?>? ids,
      Map<String, Object?>? parentIds,
      this.season,
      this.seasonSource})
      : ids = AnilistIds.from(ids),
        parentIds = AnilistIds.from(parentIds);
  String get identity => '${kind.name}:$itemId';
  String get fingerprint => jsonEncode([
        kind.name,
        ids.fingerprint,
        parentIds.fingerprint,
        season,
        seasonSource
      ]);
  AnilistTarget copyWithSeasonSource(String source) => AnilistTarget(
      itemId: itemId,
      title: title,
      kind: kind,
      ids: ids.known ? ids.values : null,
      parentIds: parentIds.known ? parentIds.values : null,
      season: season,
      seasonSource: source);
  @override
  bool operator ==(Object other) =>
      other is AnilistTarget &&
      other.identity == identity &&
      other.fingerprint == fingerprint &&
      other.title == title;
  @override
  int get hashCode => Object.hash(identity, fingerprint, title);
}

class AnilistMedia {
  final int id;
  final int? malId;
  final String title;
  final int? year;
  final String? format;
  final int? episodes;
  const AnilistMedia(
      {required this.id,
      required this.title,
      this.malId,
      this.year,
      this.format,
      this.episodes});
  factory AnilistMedia.fromJson(Map<String, dynamic> json) {
    final id = positiveId(json['id']);
    if (id == null || json['type'] != 'ANIME') {
      throw const FormatException('Invalid anime');
    }
    final titles = json['title'];
    final title = titles is Map
        ? [
            titles['userPreferred'],
            titles['romaji'],
            titles['english'],
            titles['native']
          ].whereType<String>().where((s) => s.trim().isNotEmpty).firstOrNull
        : null;
    return AnilistMedia(
        id: id,
        malId: positiveId(json['idMal']),
        episodes: positiveId(json['episodes']),
        title: title ?? 'AniList #$id',
        year: json['startDate'] is Map
            ? positiveId(json['startDate']['year'])
            : null,
        format: json['format'] is String ? json['format'] as String : null);
  }
}

typedef AnilistEpisodeMapping = ({String source, int? season, int? offset});

class AnilistCandidate {
  final int id;
  final Set<String> sources;
  final AnilistMedia? media;
  final List<AnilistEpisodeMapping> episodeMappings;
  const AnilistCandidate(this.id, this.sources,
      {this.media, this.episodeMappings = const []});
  AnilistCandidate withMedia(AnilistMedia? value) =>
      AnilistCandidate(id, sources,
          media: value, episodeMappings: episodeMappings);
}

class AnilistMatch {
  final AnilistMatchStatus status;
  final List<AnilistCandidate> candidates;
  final AnilistMatchReason? reason;
  const AnilistMatch(this.status, [this.candidates = const [], this.reason]);
}

class _CatalogRow {
  final int id;
  final Map<String, int> seasons;
  final Map<String, int> offsets;
  const _CatalogRow(this.id, this.seasons, [this.offsets = const {}]);
}

class AnilistCatalogIndex {
  final Map<String, List<_CatalogRow>> _index;
  const AnilistCatalogIndex._(this._index);
  static const empty = AnilistCatalogIndex._({});
  factory AnilistCatalogIndex.fromJson(Object? json) {
    if (json is! List || json.isEmpty) {
      throw const FormatException('Invalid mapping catalog');
    }
    final index = <String, List<_CatalogRow>>{};
    var valid = 0;
    for (final value in json) {
      if (value is! Map) continue;
      final id = positiveId(value['anilist_id']);
      if (id == null) continue;
      valid++;
      final seasons = <String, int>{};
      if (value['season'] case final Map data) {
        for (final key in ['tmdb', 'tvdb']) {
          final v = data[key];
          final n =
              (v is String || v is int) ? int.tryParse(v.toString()) : null;
          if (n != null && n >= 0) seasons[key] = n;
        }
      }
      final offsets = <String, int>{};
      if (value['episode_offset'] case final Map data) {
        for (final key in ['tmdb', 'tvdb']) {
          final raw = data[key];
          final n = (raw is String || raw is int)
              ? int.tryParse(raw.toString())
              : null;
          // Negative offsets exist in the source and must not become absolute episode numbers.
          if (n != null) offsets[key] = n;
        }
      }
      final row =
          _CatalogRow(id, Map.unmodifiable(seasons), Map.unmodifiable(offsets));
      void add(String key, Object? v) {
        final n = positiveId(v);
        if (n != null) (index['$key:$n'] ??= []).add(row);
      }

      for (final key in ['anidb', 'mal', 'tvdb']) {
        add(key, value['${key}_id']);
      }
      if (value['imdb_id'] case final List ids) {
        for (final imdb in ids.whereType<String>()) {
          if (RegExp(r'^tt\d+$').hasMatch(imdb)) {
            (index['imdb:$imdb'] ??= []).add(row);
          }
        }
      }
      if (value['themoviedb_id'] case final Map tmdb) {
        add('tmdb:series', tmdb['tv']);
        if (tmdb['movie'] case final List movies) {
          for (final m in movies) {
            add('tmdb:movie', m);
          }
        }
      }
    }
    if (valid == 0) throw const FormatException('No valid anime mappings');
    return AnilistCatalogIndex._(index);
  }
}

AnilistMatch resolveAnilistTarget(
    AnilistTarget target, AnilistCatalogIndex catalog,
    {Map<int, int> malLookup = const {}}) {
  final signals = <Set<int>>[];
  final sources = <int, Set<String>>{};
  final seasonProven = <int>{};
  final episodeMappings = <int, Set<AnilistEpisodeMapping>>{};
  var ownAnimeId = false;
  void collect(AnilistIds ids, {required bool parent}) {
    for (final e in ids.values.entries) {
      final isSeason = target.kind == AnilistTargetKind.season;
      if (isSeason && !parent && ['tmdb', 'tvdb', 'imdb'].contains(e.key)) {
        continue;
      }
      final key = e.key == 'tmdb'
          ? 'tmdb:${target.kind == AnilistTargetKind.movie ? 'movie' : 'series'}:${e.value}'
          : '${e.key}:${e.value}';
      final rows = e.key == 'mal' && malLookup.containsKey(int.parse(e.value))
          ? [_CatalogRow(malLookup[int.parse(e.value)]!, {})]
          : e.key == 'anilist'
              ? [_CatalogRow(int.parse(e.value), {})]
              : catalog._index[key] ?? const <_CatalogRow>[];
      final matches = <int>{};
      for (final row in rows) {
        if (isSeason &&
            parent &&
            target.seasonSource != null &&
            target.season != null) {
          final expected = row.seasons[target.seasonSource];
          if (expected != null && expected != target.season) continue;
          if (expected == target.season) seasonProven.add(row.id);
        }
        for (final source in row.seasons.keys) {
          (episodeMappings[row.id] ??= {}).add((
            source: source,
            season: row.seasons[source],
            offset: row.offsets[source]
          ));
        }
        matches.add(row.id);
        (sources[row.id] ??= {}).add(parent ? 'parent:${e.key}' : e.key);
      }
      if (matches.isNotEmpty) {
        signals.add(matches);
        if (isSeason &&
            !parent &&
            ['anilist', 'mal', 'anidb'].contains(e.key)) {
          ownAnimeId = true;
        }
      }
    }
  }

  collect(target.ids, parent: false);
  if (target.kind == AnilistTargetKind.season) {
    collect(target.parentIds, parent: true);
  }
  if (signals.isEmpty) return const AnilistMatch(AnilistMatchStatus.notFound);
  var common = signals.first;
  for (final signal in signals.skip(1)) {
    common = common.intersection(signal);
  }
  final conflict =
      common.isEmpty || target.ids.conflicting || target.parentIds.conflicting;
  final ids = (conflict ? sources.keys.toSet() : common).toList()..sort();
  final candidates = [
    for (final id in ids)
      AnilistCandidate(id, Set.unmodifiable(sources[id]!),
          episodeMappings: List.unmodifiable(
              episodeMappings[id] ?? const <AnilistEpisodeMapping>{}))
  ];
  if (conflict) {
    return AnilistMatch(AnilistMatchStatus.needsConfirmation, candidates,
        AnilistMatchReason.conflictingIds);
  }
  final split = <(String, int?), Set<int>>{};
  for (final candidate in candidates) {
    for (final mapping in candidate.episodeMappings) {
      if (mapping.season != target.season ||
          (target.seasonSource != null &&
              mapping.source != target.seasonSource)) {
        continue;
      }
      (split[(mapping.source, mapping.season)] ??= {}).add(candidate.id);
    }
  }
  if (target.kind == AnilistTargetKind.season &&
      split.values.any((ids) => ids.length > 1)) {
    return AnilistMatch(AnilistMatchStatus.needsConfirmation, candidates,
        AnilistMatchReason.splitSeason);
  }
  if (target.kind == AnilistTargetKind.season &&
      !ownAnimeId &&
      (ids.length != 1 || !seasonProven.contains(ids.single))) {
    return AnilistMatch(AnilistMatchStatus.needsConfirmation, candidates,
        AnilistMatchReason.seasonUnproven);
  }
  return AnilistMatch(
      ids.length == 1
          ? AnilistMatchStatus.exact
          : AnilistMatchStatus.needsConfirmation,
      candidates);
}
