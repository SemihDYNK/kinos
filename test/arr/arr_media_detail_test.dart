import 'package:flutter_test/flutter_test.dart';

import 'package:kinos/arr/models/arr_media_detail.dart';

void main() {
  group('extractArrRating', () {
    test('flat form (Sonarr) — {value: x}', () {
      expect(extractArrRating({'value': 8.4, 'votes': 100}), 8.4);
    });

    test('nested form (Radarr) — prefers imdb over tmdb', () {
      expect(
        extractArrRating({
          'imdb': {'value': 8.8, 'votes': 2000000, 'type': 'user'},
          'tmdb': {'value': 8.3, 'votes': 20000, 'type': 'user'},
        }),
        8.8,
      );
    });

    test('nested form falls back to tmdb when imdb is absent', () {
      expect(
        extractArrRating({
          'tmdb': {'value': 7.1},
        }),
        7.1,
      );
    });

    test('neither form present — null, not 0', () {
      expect(
          extractArrRating({
            'rottenTomatoes': {'value': 90}
          }),
          isNull);
      expect(extractArrRating(null), isNull);
      expect(extractArrRating('not a map'), isNull);
    });
  });

  group('extractArrGenres', () {
    test('typical list', () {
      expect(extractArrGenres(['Action', 'Sci-Fi']), ['Action', 'Sci-Fi']);
    });

    test('absent or wrong type — empty, not throwing', () {
      expect(extractArrGenres(null), isEmpty);
      expect(extractArrGenres('Action'), isEmpty);
    });
  });

  group('resolveArrFanartUrl', () {
    test('prefers the remote URL when present', () {
      expect(
        resolveArrFanartUrl(
          [
            {'coverType': 'poster', 'remoteUrl': 'https://x/poster.jpg'},
            {'coverType': 'fanart', 'remoteUrl': 'https://x/fanart.jpg'},
          ],
          baseUrl: 'https://radarr.example.com',
          apiKey: 'key',
        ),
        'https://x/fanart.jpg',
      );
    });

    test('falls back to the local mediacover URL with the API key', () {
      expect(
        resolveArrFanartUrl(
          [
            {'coverType': 'fanart', 'url': '/mediacover/1/fanart.jpg'},
          ],
          baseUrl: 'https://radarr.example.com',
          apiKey: 'secret',
        ),
        'https://radarr.example.com/mediacover/1/fanart.jpg?apikey=secret',
      );
    });

    test('no fanart entry — null', () {
      expect(
        resolveArrFanartUrl(
          [
            {'coverType': 'poster', 'remoteUrl': 'https://x/poster.jpg'},
          ],
          baseUrl: 'https://radarr.example.com',
          apiKey: 'key',
        ),
        isNull,
      );
    });
  });

  group('ArrMovieDetail.fromJson', () {
    test('parses a realistic Radarr movie resource', () {
      final detail = ArrMovieDetail.fromJson(
        {
          'id': 1,
          'title': 'Inception',
          'year': 2010,
          'overview': 'A thief who steals corporate secrets...',
          'runtime': 148,
          'genres': ['Action', 'Sci-Fi'],
          'ratings': {
            'imdb': {'value': 8.8, 'votes': 2000000},
          },
          'images': [
            {'coverType': 'poster', 'remoteUrl': 'https://x/poster.jpg'},
            {'coverType': 'fanart', 'remoteUrl': 'https://x/fanart.jpg'},
          ],
          'monitored': true,
          'qualityProfileId': 4,
          'rootFolderPath': '/movies/',
          'path': '/movies/Inception (2010)',
          'sizeOnDisk': 12345678,
          'hasFile': true,
          'movieFile': {
            'quality': {
              'quality': {'name': 'Bluray-1080p', 'source': 'bluray'},
            },
            'mediaInfo': {'videoCodec': 'x264'},
          },
          'tmdbId': 27205,
          'imdbId': 'tt1375666',
        },
        baseUrl: 'https://radarr.example.com',
        apiKey: 'key',
      );

      expect(detail.id, 1);
      expect(detail.title, 'Inception');
      expect(detail.year, 2010);
      expect(detail.runtimeMinutes, 148);
      expect(detail.genres, ['Action', 'Sci-Fi']);
      expect(detail.rating, 8.8);
      expect(detail.posterUrl, 'https://x/poster.jpg');
      expect(detail.fanartUrl, 'https://x/fanart.jpg');
      expect(detail.monitored, isTrue);
      expect(detail.qualityProfileId, 4);
      expect(detail.rootFolderPath, '/movies/');
      expect(detail.path, '/movies/Inception (2010)');
      expect(detail.sizeOnDisk, 12345678);
      expect(detail.hasFile, isTrue);
      expect(detail.fileQualityName, 'Bluray-1080p');
      expect(detail.fileSource, 'bluray');
      expect(detail.fileCodec, 'x264');
      expect(detail.tmdbId, 27205);
      expect(detail.imdbId, 'tt1375666');
      expect(detail.raw['id'], 1);
    });

    test('a movie without a file has null file fields, not a crash', () {
      final detail = ArrMovieDetail.fromJson(
        {'id': 1, 'title': 'X', 'hasFile': false},
        baseUrl: 'https://radarr.example.com',
        apiKey: 'key',
      );
      expect(detail.hasFile, isFalse);
      expect(detail.fileQualityName, isNull);
      expect(detail.fileCodec, isNull);
      expect(detail.fileSource, isNull);
    });

    test('tolerates a completely empty body', () {
      final detail = ArrMovieDetail.fromJson(const {},
          baseUrl: 'https://radarr.example.com', apiKey: 'key');
      expect(detail.id, 0);
      expect(detail.title, '');
      expect(detail.genres, isEmpty);
      expect(detail.rating, isNull);
    });
  });

  group('ArrSeriesDetail.fromJson', () {
    test('parses a realistic Sonarr series resource, seasons included', () {
      final detail = ArrSeriesDetail.fromJson(
        {
          'id': 7,
          'title': 'Severance',
          'year': 2022,
          'overview': 'A team of workers...',
          'runtime': 55,
          'genres': ['Drama', 'Mystery'],
          'ratings': {'value': 8.7, 'votes': 5000},
          'images': [
            {'coverType': 'fanart', 'remoteUrl': 'https://x/fanart.jpg'},
          ],
          'monitored': true,
          'qualityProfileId': 3,
          'rootFolderPath': '/tv/',
          'path': '/tv/Severance',
          'statistics': {
            'seasonCount': 2,
            'episodeCount': 19,
            'episodeFileCount': 9,
            'sizeOnDisk': 987654321,
          },
          'seasons': [
            {
              'seasonNumber': 1,
              'monitored': true,
              'statistics': {'episodeCount': 9, 'episodeFileCount': 9},
            },
            {
              'seasonNumber': 2,
              'monitored': true,
              'statistics': {'episodeCount': 10, 'episodeFileCount': 0},
            },
          ],
          'tvdbId': 371980,
          'imdbId': 'tt11280740',
        },
        baseUrl: 'https://sonarr.example.com',
        apiKey: 'key',
      );

      expect(detail.id, 7);
      expect(detail.title, 'Severance');
      expect(detail.runtimeMinutes, 55);
      expect(detail.rating, 8.7);
      expect(detail.fanartUrl, 'https://x/fanart.jpg');
      expect(detail.sizeOnDisk, 987654321);
      expect(detail.episodeCount, 19);
      expect(detail.episodeFileCount, 9);
      expect(detail.seasons, hasLength(2));
      expect(detail.seasons[0].seasonNumber, 1);
      expect(detail.seasons[0].episodeFileCount, 9);
      expect(detail.seasons[1].episodeFileCount, 0);
      expect(detail.tvdbId, 371980);
      expect(detail.imdbId, 'tt11280740');
    });

    test('no seasons field — empty list, not a crash', () {
      final detail = ArrSeriesDetail.fromJson(
        {'id': 1, 'title': 'X'},
        baseUrl: 'https://sonarr.example.com',
        apiKey: 'key',
      );
      expect(detail.seasons, isEmpty);
      expect(detail.sizeOnDisk, isNull);
    });
  });

  group('ArrDetailEntry', () {
    test('movie entry exposes movie-only getters through the common surface',
        () {
      final movie = ArrMovieDetail.fromJson(
        {'id': 1, 'title': 'X', 'year': 2020, 'tmdbId': 42},
        baseUrl: 'https://radarr.example.com',
        apiKey: 'key',
      );
      final entry = ArrDetailEntry.movie(movie);
      expect(entry.isMovie, isTrue);
      expect(entry.id, 1);
      expect(entry.title, 'X');
      expect(entry.tmdbId, 42);
      expect(entry.tvdbId, isNull);
    });

    test('series entry exposes series-only getters through the common surface',
        () {
      final series = ArrSeriesDetail.fromJson(
        {'id': 2, 'title': 'Y', 'tvdbId': 99},
        baseUrl: 'https://sonarr.example.com',
        apiKey: 'key',
      );
      final entry = ArrDetailEntry.series(series);
      expect(entry.isMovie, isFalse);
      expect(entry.id, 2);
      expect(entry.tvdbId, 99);
      expect(entry.tmdbId, isNull);
    });
  });
}
