import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:fladder/arr/services/arr_api_client.dart';

void main() {
  group('RadarrApiClient', () {
    test('searchMovies filters the full library client-side by title',
        () async {
      final client = RadarrApiClient(
        baseUrl: 'https://radarr.example.com',
        apiKey: 'key',
        httpClient: MockClient((request) async {
          expect(request.url.path, '/api/v3/movie');
          return http.Response(
            jsonEncode([
              {'id': 1, 'title': 'Dune', 'year': 2021},
              {'id': 2, 'title': 'Dune: Part Two', 'year': 2024},
              {'id': 3, 'title': 'Arrival', 'year': 2016},
            ]),
            200,
          );
        }),
      );

      final result = await client.searchMovies('dune');

      expect(result, isA<ArrSuccess>());
      final movies = (result as ArrSuccess).data;
      expect(movies.map((m) => m.title), ['Dune', 'Dune: Part Two']);
    });

    test('searchMovies returns everything when the query is empty', () async {
      final client = RadarrApiClient(
        baseUrl: 'https://radarr.example.com',
        apiKey: 'key',
        httpClient: MockClient((request) async => http.Response(
              jsonEncode([
                {'id': 1, 'title': 'Dune', 'year': 2021},
                {'id': 2, 'title': 'Arrival', 'year': 2016},
              ]),
              200,
            )),
      );

      final result = await client.searchMovies('');

      expect((result as ArrSuccess).data.length, 2);
    });

    test('releasesForMovie queries /release with movieId', () async {
      final client = RadarrApiClient(
        baseUrl: 'https://radarr.example.com',
        apiKey: 'key',
        httpClient: MockClient((request) async {
          expect(request.url.path, '/api/v3/release');
          expect(request.url.queryParameters['movieId'], '42');
          return http.Response(jsonEncode([]), 200);
        }),
      );

      final result = await client.releasesForMovie(42);

      expect(result, isA<ArrSuccess>());
    });

    test('grabRelease posts guid and indexerId', () async {
      final client = RadarrApiClient(
        baseUrl: 'https://radarr.example.com',
        apiKey: 'key',
        httpClient: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/v3/release');
          final body = jsonDecode(request.body) as Map;
          expect(body['guid'], 'release-guid');
          expect(body['indexerId'], 7);
          return http.Response('', 200);
        }),
      );

      final result =
          await client.grabRelease(guid: 'release-guid', indexerId: 7);

      expect(result, isA<ArrSuccess>());
    });

    test('grabRelease surfaces a server error', () async {
      final client = RadarrApiClient(
        baseUrl: 'https://radarr.example.com',
        apiKey: 'key',
        httpClient: MockClient((request) async => http.Response('', 500)),
      );

      final result = await client.grabRelease(guid: 'g', indexerId: 1);

      expect(result, isA<ArrFailure>());
      expect((result as ArrFailure).error, ArrApiError.serverError);
    });
  });

  group('SonarrApiClient', () {
    test('searchSeries filters the full library client-side by title',
        () async {
      final client = SonarrApiClient(
        baseUrl: 'https://sonarr.example.com',
        apiKey: 'key',
        httpClient: MockClient((request) async {
          expect(request.url.path, '/api/v3/series');
          return http.Response(
            jsonEncode([
              {'id': 1, 'title': 'Breaking Bad', 'year': 2008},
              {'id': 2, 'title': 'Better Call Saul', 'year': 2015},
            ]),
            200,
          );
        }),
      );

      final result = await client.searchSeries('breaking');

      expect((result as ArrSuccess).data.map((s) => s.title), ['Breaking Bad']);
    });

    test('episodesForSeries queries /episode with seriesId', () async {
      final client = SonarrApiClient(
        baseUrl: 'https://sonarr.example.com',
        apiKey: 'key',
        httpClient: MockClient((request) async {
          expect(request.url.path, '/api/v3/episode');
          expect(request.url.queryParameters['seriesId'], '9');
          return http.Response(
            jsonEncode([
              {
                'id': 100,
                'seriesId': 9,
                'seasonNumber': 1,
                'episodeNumber': 1,
                'title': 'Pilot'
              },
            ]),
            200,
          );
        }),
      );

      final result = await client.episodesForSeries(9);

      final episodes = (result as ArrSuccess).data;
      expect(episodes.single.title, 'Pilot');
      expect(episodes.single.seasonNumber, 1);
    });

    test('releasesForEpisode queries /release with episodeId', () async {
      final client = SonarrApiClient(
        baseUrl: 'https://sonarr.example.com',
        apiKey: 'key',
        httpClient: MockClient((request) async {
          expect(request.url.queryParameters['episodeId'], '55');
          expect(request.url.queryParameters.containsKey('seriesId'), isFalse);
          return http.Response(jsonEncode([]), 200);
        }),
      );

      await client.releasesForEpisode(55);
    });

    test('releasesForSeason queries /release with seriesId and seasonNumber',
        () async {
      final client = SonarrApiClient(
        baseUrl: 'https://sonarr.example.com',
        apiKey: 'key',
        httpClient: MockClient((request) async {
          expect(request.url.queryParameters['seriesId'], '9');
          expect(request.url.queryParameters['seasonNumber'], '2');
          return http.Response(jsonEncode([]), 200);
        }),
      );

      await client.releasesForSeason(9, 2);
    });
  });
}
