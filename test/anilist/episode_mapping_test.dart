import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/anilist/episode_mapping.dart';
import 'package:kinos/anilist/mapping.dart';

void main() {
  const a = AnilistCandidate(1, {'tvdb'},
      media: AnilistMedia(id: 1, title: 'A', episodes: 24),
      episodeMappings: [(source: 'tvdb', season: 2, offset: null)]);
  const b = AnilistCandidate(2, {'tvdb'},
      media: AnilistMedia(id: 2, title: 'B', episodes: 24),
      episodeMappings: [(source: 'tvdb', season: 2, offset: 24)]);
  test('one TVDB season maps two AniList parts without any confirmation', () {
    final plan = EpisodePlan.automatic([a, b]);
    expect(plan.resolve(2, 24)?.mediaId, 1);
    expect(plan.resolve(2, 25)?.episode, 1);
    expect(plan.resolve(2, 48)?.episode, 24);
    expect(plan.resolve(2, 49), isNull);
    expect(plan.resolve(0, 1), isNull);
  });
  test('unknown counts, overlapping ranges and disagreeing sources block sends',
      () {
    const conflict = AnilistCandidate(3, {'tmdb'},
        media: AnilistMedia(id: 3, title: 'C', episodes: 24),
        episodeMappings: [(source: 'tmdb', season: 2, offset: null)]);
    expect(EpisodePlan.automatic([a, b, conflict]).resolve(2, 1), isNull);
    const missing = AnilistCandidate(4, {'tvdb'},
        media: AnilistMedia(id: 4, title: 'Unknown'),
        episodeMappings: [(source: 'tvdb', season: 2, offset: 48)]);
    expect(EpisodePlan.automatic([a, b, missing]).resolve(2, 1)?.mediaId, 1);
    expect(EpisodePlan.automatic([a, b, missing]).resolve(2, 49), isNull);
    expect(EpisodePlan.automatic([a, a]).resolve(2, 1)?.mediaId, 1);
  });
  test('matching providers do not require a preferred numbering source', () {
    const mirror = AnilistCandidate(1, {'tmdb'},
        media: AnilistMedia(id: 1, title: 'A', episodes: 24),
        episodeMappings: [(source: 'tmdb', season: 2, offset: 0)]);
    expect(EpisodePlan.automatic([a, mirror]).resolve(2, 5)?.episode, 5);
  });
  test('manual mappings validate both local and remote overlaps', () {
    final r = EpisodeRange(
        season: 3, first: 1, last: 24, mediaId: 2, anilistFirst: 1);
    expect(EpisodePlan.manual([r]).resolve(3, 1)?.mediaId, 2);
    expect(
        () => EpisodeRange(
            season: 1, first: 0, last: 24, mediaId: 1, anilistFirst: 1),
        throwsArgumentError);
    expect(() => EpisodePlan.manual([r, r]), throwsArgumentError);
    expect(
        () => EpisodePlan.manual([
              r,
              EpisodeRange(
                  season: 4, first: 1, last: 24, mediaId: 2, anilistFirst: 1)
            ]),
        throwsArgumentError);
  });
  test('manual correction preserves automatic mappings on other seasons', () {
    final manual = EpisodePlan.manual([
      EpisodeRange(season: 3, first: 1, last: 24, mediaId: 2, anilistFirst: 1)
    ]);
    final plan = EpisodePlan.overlay(EpisodePlan.automatic([a, b]), manual);
    expect(plan.resolve(2, 1)?.mediaId, 1);
    expect(plan.resolve(2, 25), isNull);
    expect(plan.resolve(3, 1)?.mediaId, 2);
  });
  test('double episodes may not span two AniList entries', () {
    final p = EpisodePlan.automatic([a, b]);
    expect(p.resolve(2, 23, end: 24)?.episode, 24);
    expect(p.resolve(2, 24, end: 25), isNull);
  });
  test(
      'progress advances only over contiguous watched episodes, never backwards',
      () {
    expect(contiguousProgress(5, {6, 7, 9}), 7);
    expect(contiguousProgress(10, {1, 2, 3}), 10);
    expect(contiguousProgress(0, {2, 3}), 0);
  });
}
