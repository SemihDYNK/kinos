import 'mapping.dart';

class EpisodeRange {
  final int season, first, last, mediaId, anilistFirst;
  final String source;
  EpisodeRange(
      {required this.season,
      required this.first,
      required this.last,
      required this.mediaId,
      required this.anilistFirst,
      this.source = 'manual'}) {
    if (season < 0 ||
        first < 1 ||
        last < first ||
        mediaId < 1 ||
        anilistFirst < 1) {
      throw ArgumentError('Invalid episode range');
    }
  }
  int get anilistLast => anilistFirst + last - first;
  Object get identity => (season, first, last, mediaId, anilistFirst, source);
  Map<String, Object> toJson() => {
        'season': season,
        'first': first,
        'last': last,
        'mediaId': mediaId,
        'anilistFirst': anilistFirst
      };
  factory EpisodeRange.fromJson(Map<String, dynamic> j) => EpisodeRange(
      season: j['season'] as int,
      first: j['first'] as int,
      last: j['last'] as int,
      mediaId: j['mediaId'] as int,
      anilistFirst: j['anilistFirst'] as int);
}

typedef EpisodeDestination = ({int mediaId, int episode});

class EpisodePlan {
  final List<EpisodeRange> ranges;
  final Set<(String, int, int)> _blocked;
  EpisodePlan._(this.ranges, this._blocked);
  factory EpisodePlan.manual(List<EpisodeRange> values) {
    for (var i = 0; i < values.length; i++) {
      for (final other in values.skip(i + 1)) {
        final a = values[i];
        if ((a.season == other.season &&
                a.first <= other.last &&
                other.first <= a.last) ||
            (a.mediaId == other.mediaId &&
                a.anilistFirst <= other.anilistLast &&
                other.anilistFirst <= a.anilistLast)) {
          throw ArgumentError('Overlapping episode ranges');
        }
      }
    }
    return EpisodePlan._(List.unmodifiable(values), {});
  }
  factory EpisodePlan.automatic(List<AnilistCandidate> candidates) {
    final ranges = <EpisodeRange>[];
    final seen = <Object>{};
    final blocked = <(String, int, int)>{};
    for (final c in candidates) {
      for (final mapping in c.episodeMappings) {
        final season = mapping.season;
        if (season == null || season <= 0) continue;
        final count = c.media?.episodes;
        final offset = mapping.offset ?? 0;
        // Missing offsets only establish a bounded start when the episode count is known.
        if (count == null || offset < 0) {
          blocked.add((mapping.source, season, offset >= 0 ? offset + 1 : 1));
          continue;
        }
        final range = EpisodeRange(
            season: season,
            first: offset + 1,
            last: offset + count,
            mediaId: c.id,
            anilistFirst: 1,
            source: mapping.source);
        if (seen.add(range.identity)) ranges.add(range);
      }
    }
    return EpisodePlan._(List.unmodifiable(ranges), Set.unmodifiable(blocked));
  }
  factory EpisodePlan.overlay(EpisodePlan automatic, EpisodePlan? manual) {
    if (manual == null) return automatic;
    return EpisodePlan._([
      ...manual.ranges,
      ...automatic.ranges.where((r) =>
          !manual.hasSeason(r.season) &&
          !manual.ranges.any((m) =>
              m.mediaId == r.mediaId &&
              m.anilistFirst <= r.anilistLast &&
              r.anilistFirst <= m.anilistLast)),
    ], automatic._blocked.where((key) => !manual.hasSeason(key.$2)).toSet());
  }
  bool hasSeason(int season) => ranges.any((r) => r.season == season);
  EpisodeDestination? resolve(int? season, int? episode, {int? end}) {
    if (season == null ||
        episode == null ||
        episode < 1 ||
        (end != null && end < episode) ||
        _blocked.any((key) => key.$2 == season && (end ?? episode) >= key.$3)) {
      return null;
    }
    final matches = <EpisodeDestination>{};
    for (final r in ranges) {
      if (r.season == season &&
          episode >= r.first &&
          (end ?? episode) <= r.last) {
        matches.add((
          mediaId: r.mediaId,
          episode: r.anilistFirst + (end ?? episode) - r.first
        ));
      }
    }
    return matches.length == 1 ? matches.single : null;
  }
}

int contiguousProgress(int current, Set<int> watched) {
  var result = current;
  while (watched.contains(result + 1)) {
    result++;
  }
  return result;
}
