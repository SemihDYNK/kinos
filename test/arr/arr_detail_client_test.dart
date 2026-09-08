import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:fladder/arr/models/arr_media_detail.dart';
import 'package:fladder/arr/services/arr_api_client.dart';

void main() {
  group('fetchQualityProfiles / fetchRootFolders', () {
    test('fetchQualityProfiles parses the list', () async {
      final client = RadarrApiClient(
        baseUrl: 'https://radarr.example.com',
        apiKey: 'key',
        httpClient: MockClient((request) async {
          expect(request.url.path, '/api/v3/qualityprofile');
          return http.Response(
              jsonEncode([
                {'id': 1, 'name': 'HD-1080p'},
                {'id': 2, 'name': 'Ultra-HD'},
              ]),
              200);
        }),
      );

      final result = await client.fetchQualityProfiles();

      expect(result, isA<ArrSuccess<List<ArrQualityProfile>>>());
      final profiles = (result as ArrSuccess<List<ArrQualityProfile>>).data;
      expect(profiles.map((p) => p.name), ['HD-1080p', 'Ultra-HD']);
    });

    test('fetchRootFolders parses the list', () async {
      final client = SonarrApiClient(
        baseUrl: 'https://sonarr.example.com',
        apiKey: 'key',
        httpClient: MockClient((request) async {
          expect(request.url.path, '/api/v3/rootfolder');
          return http.Response(
              jsonEncode([
                {'id': 1, 'path': '/tv/'},
              ]),
              200);
        }),
      );

      final result = await client.fetchRootFolders();

      expect(result, isA<ArrSuccess<List<ArrRootFolder>>>());
      final folders = (result as ArrSuccess<List<ArrRootFolder>>).data;
      expect(folders.single.path, '/tv/');
    });
  });

  group('RadarrApiClient.fetchMovieDetail', () {
    test('parses a full movie resource', () async {
      final client = RadarrApiClient(
        baseUrl: 'https://radarr.example.com',
        apiKey: 'key',
        httpClient: MockClient((request) async {
          expect(request.url.path, '/api/v3/movie/12');
          return http.Response(
              jsonEncode({'id': 12, 'title': 'Dune', 'monitored': true}), 200);
        }),
      );

      final result = await client.fetchMovieDetail(12);

      expect(result, isA<ArrSuccess<ArrMovieDetail>>());
      expect((result as ArrSuccess<ArrMovieDetail>).data.title, 'Dune');
    });
  });

  group('RadarrApiClient.updateMovie', () {
    ArrMovieDetail movie({String? rootFolderPath, String? path}) =>
        ArrMovieDetail.fromJson(
          {
            'id': 5,
            'title': 'Dune',
            'monitored': false,
            'qualityProfileId': 1,
            'rootFolderPath': rootFolderPath ?? '/movies/',
            'path': path ?? '/movies/Dune (2021)',
          },
          baseUrl: 'https://radarr.example.com',
          apiKey: 'key',
        );

    test('same root folder — plain PUT, no moveFiles, path untouched',
        () async {
      var captured = <String, dynamic>{};
      Uri? capturedUri;
      final client = RadarrApiClient(
        baseUrl: 'https://radarr.example.com',
        apiKey: 'key',
        httpClient: MockClient((request) async {
          capturedUri = request.url;
          captured = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response('{}', 200);
        }),
      );

      final result = await client.updateMovie(
        movie(),
        monitored: true,
        qualityProfileId: 2,
        rootFolderPath: '/movies/',
      );

      expect(result, isA<ArrSuccess>());
      expect(capturedUri!.queryParameters['moveFiles'], isNull);
      expect(captured['monitored'], true);
      expect(captured['qualityProfileId'], 2);
      expect(captured['rootFolderPath'], '/movies/');
      // Le chemin existant n'est pas recalculé : rien à déplacer — il
      // survit tel quel via le corps brut (`...detail.raw`), pas via une
      // valeur `path` explicitement recalculée par ce client.
      expect(captured['path'], '/movies/Dune (2021)');
    });

    test(
        'changed root folder — moveFiles=true, path recomputed keeping the '
        'same folder name', () async {
      var captured = <String, dynamic>{};
      Uri? capturedUri;
      final client = RadarrApiClient(
        baseUrl: 'https://radarr.example.com',
        apiKey: 'key',
        httpClient: MockClient((request) async {
          capturedUri = request.url;
          captured = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response('{}', 200);
        }),
      );

      final result = await client.updateMovie(
        movie(rootFolderPath: '/movies/', path: '/movies/Dune (2021)'),
        monitored: false,
        qualityProfileId: 1,
        rootFolderPath: '/other-drive/movies',
      );

      expect(result, isA<ArrSuccess>());
      expect(capturedUri!.queryParameters['moveFiles'], 'true');
      expect(captured['rootFolderPath'], '/other-drive/movies');
      expect(captured['path'], '/other-drive/movies/Dune (2021)');
    });
  });

  group('SonarrApiClient.fetchSeriesDetail / updateSeries', () {
    test('fetchSeriesDetail parses the seasons array', () async {
      final client = SonarrApiClient(
        baseUrl: 'https://sonarr.example.com',
        apiKey: 'key',
        httpClient: MockClient((request) async {
          expect(request.url.path, '/api/v3/series/3');
          return http.Response(
              jsonEncode({
                'id': 3,
                'title': 'Severance',
                'seasons': [
                  {
                    'seasonNumber': 1,
                    'monitored': true,
                    'statistics': {'episodeCount': 9, 'episodeFileCount': 9},
                  },
                ],
              }),
              200);
        }),
      );

      final result = await client.fetchSeriesDetail(3);

      expect(result, isA<ArrSuccess<ArrSeriesDetail>>());
      final detail = (result as ArrSuccess<ArrSeriesDetail>).data;
      expect(detail.seasons.single.episodeCount, 9);
    });

    test('updateSeries recomputes path the same way as updateMovie', () async {
      var captured = <String, dynamic>{};
      Uri? capturedUri;
      final client = SonarrApiClient(
        baseUrl: 'https://sonarr.example.com',
        apiKey: 'key',
        httpClient: MockClient((request) async {
          capturedUri = request.url;
          captured = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response('{}', 200);
        }),
      );
      final series = ArrSeriesDetail.fromJson(
        {
          'id': 3,
          'title': 'Severance',
          'rootFolderPath': '/tv/',
          'path': '/tv/Severance',
        },
        baseUrl: 'https://sonarr.example.com',
        apiKey: 'key',
      );

      final result = await client.updateSeries(
        series,
        monitored: true,
        qualityProfileId: 4,
        rootFolderPath: '/tv-4k/',
      );

      expect(result, isA<ArrSuccess>());
      expect(capturedUri!.queryParameters['moveFiles'], 'true');
      expect(captured['path'], '/tv-4k/Severance');
    });
  });
}
