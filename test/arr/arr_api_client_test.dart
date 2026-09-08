import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:kinos/arr/services/arr_api_client.dart';

void main() {
  group('ArrApiClient.testConnection', () {
    test('returns ArrConnectionOk with the reported version on a matching app',
        () async {
      final client = RadarrApiClient(
        baseUrl: 'https://radarr.example.com',
        apiKey: 'key',
        httpClient: MockClient((request) async {
          expect(request.url.path, '/api/v3/system/status');
          expect(request.headers['X-Api-Key'], 'key');
          return http.Response(
            jsonEncode({'appName': 'Radarr', 'version': '5.14.0.9383'}),
            200,
          );
        }),
      );

      final result = await client.testConnection();

      expect(result, isA<ArrConnectionOk>());
      expect((result as ArrConnectionOk).version, '5.14.0.9383');
    });

    test(
        'flags a mismatched app name as an invalid response (wrong service configured)',
        () async {
      final client = RadarrApiClient(
        baseUrl: 'https://sonarr.example.com',
        apiKey: 'key',
        httpClient: MockClient((request) async {
          return http.Response(
            jsonEncode({'appName': 'Sonarr', 'version': '3.0.10.1567'}),
            200,
          );
        }),
      );

      final result = await client.testConnection();

      expect(result, isA<ArrConnectionFailed>());
      expect(
          (result as ArrConnectionFailed).error, ArrApiError.invalidResponse);
      expect(result.detail, contains('Sonarr'));
    });

    test('maps 401 to unauthorized', () async {
      final client = RadarrApiClient(
        baseUrl: 'https://radarr.example.com',
        apiKey: 'wrong-key',
        httpClient: MockClient((request) async => http.Response('', 401)),
      );

      final result = await client.testConnection();

      expect(result, isA<ArrConnectionFailed>());
      expect((result as ArrConnectionFailed).error, ArrApiError.unauthorized);
    });

    test('maps 404 to notFound', () async {
      final client = RadarrApiClient(
        baseUrl: 'https://radarr.example.com/wrong-path',
        apiKey: 'key',
        httpClient: MockClient((request) async => http.Response('', 404)),
      );

      final result = await client.testConnection();

      expect(result, isA<ArrConnectionFailed>());
      expect((result as ArrConnectionFailed).error, ArrApiError.notFound);
    });

    test('maps other error statuses to serverError', () async {
      final client = RadarrApiClient(
        baseUrl: 'https://radarr.example.com',
        apiKey: 'key',
        httpClient: MockClient((request) async => http.Response('', 500)),
      );

      final result = await client.testConnection();

      expect(result, isA<ArrConnectionFailed>());
      expect((result as ArrConnectionFailed).error, ArrApiError.serverError);
    });

    test('maps a connection failure (unreachable host) to unreachable',
        () async {
      final client = RadarrApiClient(
        baseUrl: 'https://radarr.example.com',
        apiKey: 'key',
        httpClient: MockClient((request) async {
          throw const SocketException('Connection refused');
        }),
      );

      final result = await client.testConnection();

      expect(result, isA<ArrConnectionFailed>());
      expect((result as ArrConnectionFailed).error, ArrApiError.unreachable);
    });

    test('maps a non-JSON 2xx body to invalidResponse rather than throwing',
        () async {
      final client = RadarrApiClient(
        baseUrl: 'https://radarr.example.com',
        apiKey: 'key',
        httpClient: MockClient(
            (request) async => http.Response('<html>not json</html>', 200)),
      );

      final result = await client.testConnection();

      expect(result, isA<ArrConnectionFailed>());
      expect(
          (result as ArrConnectionFailed).error, ArrApiError.invalidResponse);
    });
  });

  group('ArrApiClient.fetchQueue', () {
    test('parses a Sonarr queue response (series/episode, not movie)',
        () async {
      // Forme réelle d'une réponse Sonarr : `{records: [...]}` (paginée,
      // pas une liste nue), chaque enregistrement portant `series`/
      // `episode` là où Radarr porte `movie`.
      final client = SonarrApiClient(
        baseUrl: 'https://sonarr.example.com',
        apiKey: 'key',
        httpClient: MockClient((request) async {
          expect(request.url.path, '/api/v3/queue');
          return http.Response(
            jsonEncode({
              'page': 1,
              'pageSize': 250,
              'totalRecords': 1,
              'records': [
                {
                  'id': 7,
                  'seriesId': 12,
                  'episodeId': 345,
                  'series': {'id': 12, 'title': 'Some Series'},
                  'episode': {'id': 345, 'seasonNumber': 2, 'episodeNumber': 5},
                  'title': 'Some.Series.S02E05.1080p.WEB-DL-GROUP',
                  'size': 1073741824,
                  'sizeleft': 268435456,
                  'status': 'downloading',
                  'trackedDownloadStatus': 'ok',
                  'trackedDownloadState': 'downloading',
                  'protocol': 'usenet',
                },
              ],
            }),
            200,
          );
        }),
      );

      final result = await client.fetchQueue();

      expect(result, isA<ArrSuccess>());
      final items = (result as ArrSuccess).data;
      expect(items, hasLength(1));
      expect(items.single.id, 7);
      expect(items.single.title, 'Some.Series.S02E05.1080p.WEB-DL-GROUP');
    });

    test('a single malformed record does not take down the rest of the queue',
        () async {
      final client = SonarrApiClient(
        baseUrl: 'https://sonarr.example.com',
        apiKey: 'key',
        httpClient: MockClient((request) async => http.Response(
              jsonEncode({
                'records': [
                  'not even an object',
                  {'id': 2, 'title': 'Readable record'},
                ],
              }),
              200,
            )),
      );

      final result = await client.fetchQueue();

      expect(result, isA<ArrSuccess>());
      final items = (result as ArrSuccess).data;
      expect(items, hasLength(1));
      expect(items.single.title, 'Readable record');
    });

    test('a non-list `records` field is reported as an invalid response',
        () async {
      final client = SonarrApiClient(
        baseUrl: 'https://sonarr.example.com',
        apiKey: 'key',
        httpClient:
            MockClient((request) async => http.Response(jsonEncode({}), 200)),
      );

      final result = await client.fetchQueue();

      expect(result, isA<ArrFailure>());
      expect((result as ArrFailure).error, ArrApiError.invalidResponse);
    });
  });
}
