import 'package:flutter_test/flutter_test.dart';

import 'package:kinos/stats/viewing_log.dart';
import 'package:kinos/stats/wrapped/wrapped_habits.dart';

ViewingEvent watch(DateTime at,
        {Set<ViewingSource> sources = const {ViewingSource.kinos},
        int? season,
        int? episode,
        String series = 'Show'}) =>
    ViewingEvent(
        identity: 'e:$series:$season:$episode:$at',
        kind: 'episode',
        title: 'Episode',
        seriesTitle: series,
        season: season,
        episode: episode,
        at: at,
        sources: sources);

void main() {
  test('hours only count sessions whose time is known', () {
    final events = [
      for (var i = 0; i < 12; i++) watch(DateTime(2026, 3, 7 + i % 2, 23)),
      // Letterboxd : le jour seul, rangé à minuit — ignoré.
      for (var i = 0; i < 30; i++)
        watch(DateTime(2026, 4, 1), sources: const {ViewingSource.letterboxd}),
    ];
    final hours = wrappedHours(events)!;
    expect(hours.timed, 12);
    expect(peakHour(hours), anyOf(21, 22, 23));
    expect(lateShare(hours), 1);
    // Le 7 mars 2026 est un samedi, le 8 un dimanche.
    expect(weekendShare(hours), 1);
    expect(wrappedHours(events.take(5)), isNull);
  });

  test('the fastest season: most distinct episodes per day', () {
    final slow = [
      for (var e = 1; e <= 10; e++)
        watch(DateTime(2026, 1, e * 3), season: 1, episode: e, series: 'Slow')
    ];
    final fast = [
      for (var e = 1; e <= 8; e++)
        watch(DateTime(2026, 5, 1 + e ~/ 4),
            season: 2, episode: e, series: 'Fast'),
      // Un épisode revu ne compte pas deux fois.
      watch(DateTime(2026, 5, 3), season: 2, episode: 8, series: 'Fast'),
    ];
    final pace = fastestSeason([
      (name: 'Slow', episodes: slow),
      (name: 'Fast', episodes: fast),
    ])!;
    expect(pace.series, 'Fast');
    expect(pace.season, 2);
    expect(pace.episodes, 8);
    expect(pace.days, 3);
  });

  test('binge share: episodes watched three or more a day', () {
    final binged = [
      for (var e = 0; e < 15; e++) watch(DateTime(2026, 2, 1 + e ~/ 5))
    ];
    final spread = [
      for (var e = 0; e < 10; e++) watch(DateTime(2026, 3, 1 + e * 2))
    ];
    expect(
        bingeShare(
            [(name: 'A', episodes: binged), (name: 'B', episodes: spread)]),
        15 / 25);
    expect(bingeShare([(name: 'B', episodes: spread)]), isNull);
  });

  test('the profile picks the strongest trait, eclectic by default', () {
    final night = wrappedProfile(ProfileSignals(
      year: 2026,
      films: 40,
      episodes: 10,
      hours: wrappedHours([
        for (var i = 0; i < 20; i++)
          watch(DateTime(2026, 3, 2 + i, i.isEven ? 23 : 1)),
      ]),
    ));
    expect(night.id, 'night');
    expect(night.facts.first, contains('après 23 h'));

    final classic = wrappedProfile(const ProfileSignals(
        year: 2026, films: 30, episodes: 0, medianYear: 1975));
    expect(classic.id, 'classic');
    expect(classic.title, 'Nostalgique');

    final plain =
        wrappedProfile(const ProfileSignals(year: 2026, films: 4, episodes: 3));
    expect(plain.id, 'eclectic');
    expect(plain.facts, ['4 films', '3 épisodes']);
  });
}
