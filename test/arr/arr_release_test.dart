import 'package:flutter_test/flutter_test.dart';

import 'package:kinos/arr/models/arr_release.dart';

void main() {
  group('ArrRelease.fromJson', () {
    test('parses a typical torrent release', () {
      final release = ArrRelease.fromJson({
        'guid': 'abc123',
        'indexerId': 4,
        'indexer': 'SomeIndexer',
        'title': 'Movie.Title.2024.1080p.BluRay.x264-GROUP',
        'size': 4294967296,
        'age': 3,
        'ageHours': 76.5,
        'publishDate': '2024-01-01T00:00:00Z',
        'seeders': 42,
        'leechers': 3,
        'protocol': 'torrent',
        'quality': {
          'quality': {'id': 7, 'name': 'Bluray-1080p'},
          'revision': {'version': 1, 'real': 0},
        },
        'languages': [
          {'id': 1, 'name': 'English'},
          {'id': 2, 'name': 'French'},
        ],
        'customFormatScore': 150,
        'rejected': false,
        'rejections': [],
      });

      expect(release.guid, 'abc123');
      expect(release.indexerId, 4);
      expect(release.indexer, 'SomeIndexer');
      expect(release.title, 'Movie.Title.2024.1080p.BluRay.x264-GROUP');
      expect(release.size, 4294967296);
      // `publishDate` prime toujours sur `age`/`ageHours` quand elle est
      // présente et lisible — ce sont ces derniers qui ne servent que de
      // repli (cf. le commentaire sur `ageDays`).
      final expectedAgeDays = DateTime.now()
              .toUtc()
              .difference(DateTime.parse('2024-01-01T00:00:00Z'))
              .inMinutes /
          (60 * 24);
      expect(release.ageDays, closeTo(expectedAgeDays, 0.01));
      expect(release.seeders, 42);
      expect(release.leechers, 3);
      expect(release.protocol, ArrReleaseProtocol.torrent);
      expect(release.qualityName, 'Bluray-1080p');
      expect(release.languages, ['English', 'French']);
      expect(release.customFormatScore, 150);
      expect(release.rejected, false);
      expect(release.rejections, isEmpty);
    });

    test('parses a usenet release without seeders/leechers', () {
      final release = ArrRelease.fromJson({
        'guid': 'nzb-1',
        'indexerId': 2,
        'indexer': 'NewznabIndexer',
        'title': 'Show.S01E02.720p.WEB-DL-GROUP',
        'size': 1073741824,
        'age': 10,
        'protocol': 'usenet',
        'quality': {
          'quality': {'id': 4, 'name': 'WEBDL-720p'},
        },
        'languages': [
          {'id': 1, 'name': 'English'},
        ],
        'customFormatScore': 0,
        'rejected': false,
        'rejections': [],
      });

      expect(release.protocol, ArrReleaseProtocol.usenet);
      expect(release.protocol.label, 'Usenet');
      expect(release.seeders, isNull);
      expect(release.leechers, isNull);
    });

    test('derives age in days from publishDate when age/ageHours are absent',
        () {
      final publishDate =
          DateTime.now().toUtc().subtract(const Duration(days: 2));
      final release = ArrRelease.fromJson({
        'guid': 'g',
        'indexerId': 1,
        'indexer': 'X',
        'title': 'X',
        'publishDate': publishDate.toIso8601String(),
        'protocol': 'torrent',
        'rejected': false,
      });

      expect(release.ageDays, isNotNull);
      expect(release.ageDays!, closeTo(2, 0.1));
    });

    test(
        'prefers publishDate over the (potentially stale/cached) age fields '
        'when both are present', () {
      final publishDate =
          DateTime.now().toUtc().subtract(const Duration(days: 5));
      final release = ArrRelease.fromJson({
        'guid': 'g',
        'indexerId': 1,
        'indexer': 'X',
        'title': 'X',
        // Champs `age`/`ageHours` volontairement incohérents avec
        // `publishDate`, pour prouver que publishDate gagne.
        'age': 538,
        'ageHours': 538 * 24,
        'publishDate': publishDate.toIso8601String(),
        'protocol': 'torrent',
        'rejected': false,
      });

      expect(release.ageDays, closeTo(5, 0.1));
    });

    test('falls back to the age field when publishDate is absent', () {
      final release = ArrRelease.fromJson({
        'guid': 'g',
        'indexerId': 1,
        'indexer': 'X',
        'title': 'X',
        'age': 3,
        'protocol': 'torrent',
        'rejected': false,
      });

      expect(release.ageDays, 3);
    });

    test('captures rejection reasons on a rejected release', () {
      final release = ArrRelease.fromJson({
        'guid': 'rej-1',
        'indexerId': 1,
        'indexer': 'X',
        'title': 'X',
        'protocol': 'torrent',
        'rejected': true,
        'rejections': [
          'Not a preferred word',
          'Release is older than retention'
        ],
      });

      expect(release.rejected, isTrue);
      expect(release.rejections,
          ['Not a preferred word', 'Release is older than retention']);
    });

    test('tolerates missing optional fields without throwing', () {
      final release = ArrRelease.fromJson(const {});

      expect(release.guid, '');
      expect(release.title, '');
      expect(release.infoUrl, isNull);
      expect(release.size, isNull);
      expect(release.ageDays, isNull);
      expect(release.protocol, ArrReleaseProtocol.unknown);
      expect(release.qualityName, isNull);
      expect(release.languages, isEmpty);
      expect(release.rejected, isFalse);
      expect(release.rejections, isEmpty);
    });

    test('falls back to a singular language field when languages is absent',
        () {
      final release = ArrRelease.fromJson({
        'guid': 'g',
        'indexerId': 1,
        'indexer': 'X',
        'title': 'X',
        'language': {'id': 1, 'name': 'German'},
      });

      expect(release.languages, ['German']);
    });

    test('captures infoUrl when present', () {
      final release = ArrRelease.fromJson({
        'guid': 'g',
        'indexerId': 1,
        'indexer': 'X',
        'title': 'X',
        'infoUrl': 'https://indexer.example/details/123',
      });

      expect(release.infoUrl, 'https://indexer.example/details/123');
    });

    test('treats an empty infoUrl as absent, not a dead link', () {
      final release = ArrRelease.fromJson({
        'guid': 'g',
        'indexerId': 1,
        'indexer': 'X',
        'title': 'X',
        'infoUrl': '',
      });

      expect(release.infoUrl, isNull);
    });
  });
}
