import 'package:flutter_test/flutter_test.dart';

import 'package:kinos/arr/models/arr_calendar_entry.dart';
import 'package:kinos/arr/models/arr_service.dart';

void main() {
  group('computeArrCalendarStatus', () {
    test('has a file -> downloaded, regardless of date', () {
      expect(
        computeArrCalendarStatus(
            hasFile: true, referenceDate: DateTime(2000)),
        ArrCalendarStatus.downloaded,
      );
      expect(
        computeArrCalendarStatus(
            hasFile: true,
            referenceDate: DateTime.now().add(const Duration(days: 30))),
        ArrCalendarStatus.downloaded,
      );
    });

    test('no file, date in the future -> announced, never missing', () {
      expect(
        computeArrCalendarStatus(
          hasFile: false,
          referenceDate: DateTime.now().add(const Duration(days: 1)),
        ),
        ArrCalendarStatus.announced,
      );
    });

    test('no file, date in the past -> missing (aired/released, not imported)',
        () {
      expect(
        computeArrCalendarStatus(
          hasFile: false,
          referenceDate: DateTime.now().subtract(const Duration(days: 1)),
        ),
        ArrCalendarStatus.missing,
      );
    });

    test('no file, no reference date -> missing (never falsely announced)',
        () {
      expect(
        computeArrCalendarStatus(hasFile: false, referenceDate: null),
        ArrCalendarStatus.missing,
      );
    });
  });

  group('ArrCalendarEntry.fromRadarrJson', () {
    test('prefers digitalRelease over physicalRelease and inCinemas', () {
      final entry = ArrCalendarEntry.fromRadarrJson(
        {
          'id': 1,
          'title': 'Movie',
          'hasFile': false,
          'digitalRelease': '2030-01-15T00:00:00Z',
          'physicalRelease': '2030-01-01T00:00:00Z',
          'inCinemas': '2029-12-01T00:00:00Z',
        },
        baseUrl: 'http://localhost:7878',
        apiKey: 'key',
      );
      expect(entry.dateBasis, ArrCalendarDateBasis.digital);
      expect(entry.hasNonObviousDateBasis, isFalse);
    });

    test('falls back to physicalRelease, then inCinemas, when absent', () {
      final physical = ArrCalendarEntry.fromRadarrJson(
        {
          'id': 1,
          'title': 'Movie',
          'hasFile': false,
          'physicalRelease': '2030-01-01T00:00:00Z',
          'inCinemas': '2029-12-01T00:00:00Z',
        },
        baseUrl: 'http://localhost:7878',
        apiKey: 'key',
      );
      expect(physical.dateBasis, ArrCalendarDateBasis.physical);
      expect(physical.hasNonObviousDateBasis, isTrue);

      final cinema = ArrCalendarEntry.fromRadarrJson(
        {
          'id': 1,
          'title': 'Movie',
          'hasFile': false,
          'inCinemas': '2029-12-01T00:00:00Z',
        },
        baseUrl: 'http://localhost:7878',
        apiKey: 'key',
      );
      expect(cinema.dateBasis, ArrCalendarDateBasis.cinema);
      expect(cinema.hasNonObviousDateBasis, isTrue);
    });

    test('subtitle is null, service is radarr', () {
      final entry = ArrCalendarEntry.fromRadarrJson(
        {'id': 1, 'title': 'Movie', 'digitalRelease': '2030-01-15T00:00:00Z'},
        baseUrl: 'http://localhost:7878',
        apiKey: 'key',
      );
      expect(entry.subtitle, isNull);
      expect(entry.service, ArrService.radarr);
      expect(entry.detailId, 1);
    });
  });

  group('ArrCalendarEntry.fromSonarrJson', () {
    test('airDateUtc is converted to local, subtitle carries SxxExx', () {
      final entry = ArrCalendarEntry.fromSonarrJson(
        {
          'id': 42,
          'seriesId': 7,
          'seasonNumber': 2,
          'episodeNumber': 5,
          'title': 'Episode title',
          'airDateUtc': '2030-06-01T20:00:00Z',
          'episodeFileId': 0,
          'series': {'title': 'Series title', 'monitored': true},
        },
        baseUrl: 'http://localhost:8989',
        apiKey: 'key',
      );
      expect(entry.title, 'Series title');
      expect(entry.subtitle, 'S02E05 — Episode title');
      expect(entry.detailId, 7);
      expect(entry.episodeId, 42);
      expect(entry.service, ArrService.sonarr);
      expect(entry.displayDate.isUtc, isFalse);
      expect(entry.monitored, isTrue);
    });

    test('status derives from episodeFileId, not the raw hasFile flag', () {
      final entry = ArrCalendarEntry.fromSonarrJson(
        {
          'id': 1,
          'seriesId': 1,
          'seasonNumber': 1,
          'episodeNumber': 1,
          'title': 'x',
          // hasFile absent from payload, episodeFileId is the source of
          // truth per the module's convention.
          'episodeFileId': 99,
          'airDateUtc': '2000-01-01T00:00:00Z',
          'series': {'title': 'Series', 'monitored': false},
        },
        baseUrl: 'http://localhost:8989',
        apiKey: 'key',
      );
      expect(entry.status, ArrCalendarStatus.downloaded);
      expect(entry.monitored, isFalse);
    });
  });
}
