import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:fladder/arr/models/arr_library_item.dart';
import 'package:fladder/arr/models/arr_library_poster.dart';
import 'package:fladder/arr/services/arr_api_client.dart';

void main() {
  group('arrNativePosterUrl', () {
    test('builds the mediacover route, no trailing slash issue', () {
      expect(
        arrNativePosterUrl(42, baseUrl: 'https://radarr.example.com'),
        'https://radarr.example.com/api/v3/mediacover/42/poster-500.jpg',
      );
      expect(
        arrNativePosterUrl(42, baseUrl: 'https://radarr.example.com/'),
        'https://radarr.example.com/api/v3/mediacover/42/poster-500.jpg',
      );
    });
  });

  group('RadarrApiClient library actions', () {
    test('setMovieMonitored PUTs the full raw body with monitored flipped',
        () async {
      var captured = <String, dynamic>{};
      final client = RadarrApiClient(
        baseUrl: 'https://radarr.example.com',
        apiKey: 'key',
        httpClient: MockClient((request) async {
          expect(request.method, 'PUT');
          expect(request.url.path, '/api/v3/movie/7');
          captured = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response('{}', 200);
        }),
      );
      final movie = ArrMovie.fromJson(
        {
          'id': 7,
          'title': 'Dune',
          'monitored': false,
          'qualityProfileId': 3,
        },
        baseUrl: 'https://radarr.example.com',
        apiKey: 'key',
      );

      final result = await client.setMovieMonitored(movie, true);

      expect(result, isA<ArrSuccess>());
      expect(captured['monitored'], true);
      // Les champs que ce modèle ne connaît pas (ex. qualityProfileId)
      // doivent survivre au round-trip — PUT exige le corps complet.
      expect(captured['qualityProfileId'], 3);
      expect(captured['id'], 7);
    });

    test('deleteMovie sends DELETE with deleteFiles=true', () async {
      final client = RadarrApiClient(
        baseUrl: 'https://radarr.example.com',
        apiKey: 'key',
        httpClient: MockClient((request) async {
          expect(request.method, 'DELETE');
          expect(request.url.path, '/api/v3/movie/9');
          expect(request.url.queryParameters['deleteFiles'], 'true');
          return http.Response('', 200);
        }),
      );

      final result = await client.deleteMovie(9);

      expect(result, isA<ArrSuccess>());
    });

    test('triggerMovieSearch posts the MoviesSearch command', () async {
      var captured = <String, dynamic>{};
      final client = RadarrApiClient(
        baseUrl: 'https://radarr.example.com',
        apiKey: 'key',
        httpClient: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/v3/command');
          captured = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response('{}', 201);
        }),
      );

      final result = await client.triggerMovieSearch(11);

      expect(result, isA<ArrSuccess>());
      expect(captured['name'], 'MoviesSearch');
      expect(captured['movieIds'], [11]);
    });
  });

  group('SonarrApiClient library actions', () {
    test('setSeriesMonitored PUTs the full raw body with monitored flipped',
        () async {
      var captured = <String, dynamic>{};
      final client = SonarrApiClient(
        baseUrl: 'https://sonarr.example.com',
        apiKey: 'key',
        httpClient: MockClient((request) async {
          expect(request.method, 'PUT');
          expect(request.url.path, '/api/v3/series/4');
          captured = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response('{}', 200);
        }),
      );
      final series = ArrSeries.fromJson(
        {'id': 4, 'title': 'Severance', 'monitored': true, 'tvdbId': 55},
        baseUrl: 'https://sonarr.example.com',
        apiKey: 'key',
      );

      final result = await client.setSeriesMonitored(series, false);

      expect(result, isA<ArrSuccess>());
      expect(captured['monitored'], false);
      expect(captured['tvdbId'], 55);
    });

    test('deleteSeries sends DELETE with deleteFiles=true', () async {
      final client = SonarrApiClient(
        baseUrl: 'https://sonarr.example.com',
        apiKey: 'key',
        httpClient: MockClient((request) async {
          expect(request.method, 'DELETE');
          expect(request.url.path, '/api/v3/series/5');
          expect(request.url.queryParameters['deleteFiles'], 'true');
          return http.Response('', 200);
        }),
      );

      final result = await client.deleteSeries(5);

      expect(result, isA<ArrSuccess>());
    });

    test('triggerSeriesSearch posts the SeriesSearch command', () async {
      var captured = <String, dynamic>{};
      final client = SonarrApiClient(
        baseUrl: 'https://sonarr.example.com',
        apiKey: 'key',
        httpClient: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/v3/command');
          captured = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response('{}', 201);
        }),
      );

      final result = await client.triggerSeriesSearch(21);

      expect(result, isA<ArrSuccess>());
      expect(captured['name'], 'SeriesSearch');
      expect(captured['seriesId'], 21);
    });
  });
}
