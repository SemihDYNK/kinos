import 'dart:convert';
import 'dart:io';

import 'package:chopper/chopper.dart' as chopper;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:kinos/models/seerr/seerr_dashboard_model.dart';
import 'package:kinos/seerr/seerr_json_converter.dart';
import 'package:kinos/seerr/seerr_models.dart';

/// Loads a fixture from `test/fixtures/seerr/` — filenames ending in
/// `.synthetic.json` are hand-written from the Jellyseerr/Overseerr API
/// docs, never captured from a real instance (see the README in that
/// folder). Treat their exact values as illustrative, not authoritative.
String _fixture(String name) =>
    File('test/fixtures/seerr/$name').readAsStringSync();

/// Runs [SeerrJsonConverter.convertResponse] the same way chopper does for
/// a real HTTP response: `body` starts as the raw JSON string, decoded
/// internally by the converter - not pre-decoded here.
Future<chopper.Response<Item>> _convert<Item>(String rawJson,
    {int statusCode = 200}) async {
  final base = http.Response(rawJson, statusCode);
  final input = chopper.Response<String>(base, rawJson);
  try {
    return await const SeerrJsonConverter().convertResponse<Item, Item>(input);
  } on chopper.ChopperHttpException catch (e) {
    return chopper.Response<Item>(e.response.base, null,
        error: e.response.error);
  }
}

void main() {
  group('SeerrJsonConverter — realistic fixtures', () {
    test(
        'decodes a discover/trending response (movie + tv + person + '
        'ambiguous-type entries)', () async {
      final result = await _convert<SeerrDiscoverResponse>(
        _fixture('discover_trending.synthetic.json'),
      );

      expect(result.error, isNull);
      final body = result.body!;
      expect(body.page, 1);
      expect(body.totalResults, 400);
      expect(body.results, hasLength(4));
      expect(body.results![0].mediaType, SeerrMediaType.movie);
      expect(body.results![0].mediaInfo?.tmdbId, 603692);
      expect(body.results![1].mediaType, SeerrMediaType.tvshow);
      expect(body.results![1].mediaInfo, isNull);
      expect(body.results![2].mediaType, SeerrMediaType.person);
      expect(
          body.results![3].mediaType, isNull); // resolved downstream, not here
    });

    test(
        'decodes a movie/<id> response, including nested externalIds and '
        'mediaInfo', () async {
      final result = await _convert<SeerrMovieDetails>(
        _fixture('movie_details.synthetic.json'),
      );

      expect(result.error, isNull);
      final body = result.body!;
      expect(body.id, 603692);
      expect(body.title, 'John Wick: Chapter 4');
      expect(body.externalIds?.imdbId, 'tt10366206');
      expect(body.mediaInfo?.mediaStatus, SeerrMediaStatus.available);
      expect(body.genres, hasLength(2));
    });

    test('decodes a tv details response, including seasons and tvdbId',
        () async {
      final result = await _convert<SeerrTvDetails>(
        _fixture('tv_details.synthetic.json'),
      );

      expect(result.error, isNull);
      final body = result.body!;
      expect(body.name, 'House of the Dragon');
      expect(body.mediaInfo?.tvdbId, 371572);
      expect(
          body.seasons,
          hasLength(
              1)); // top-level `seasons` list, from `genres`-sibling field
    });

    test('decodes a freshly created movie request response', () async {
      final result = await _convert<SeerrMediaRequest>(
        _fixture('request_created_movie.synthetic.json'),
      );

      expect(result.error, isNull);
      final body = result.body!;
      expect(body.id, 512);
      expect(body.requestStatus, SeerrRequestStatus.pending);
      expect(body.media?.tmdbId, 603692);
      expect(body.requestedBy?.displayName, 'Alice');
      expect(body.seasons, isEmpty);
    });

    test(
        'decodes a freshly created TV request response, with seasons as a '
        'list of objects (not bare ints)', () async {
      final result = await _convert<SeerrMediaRequest>(
        _fixture('request_created_tv.synthetic.json'),
      );

      expect(result.error, isNull);
      final body = result.body!;
      expect(body.media?.tvdbId, 355567);
      expect(
          body.seasons, [1, 2]); // _parseRequestSeasons pulled seasonNumber out
    });

    test('decodes a paginated requests list response', () async {
      final result = await _convert<SeerrRequestsResponse>(
        _fixture('requests_list.synthetic.json'),
      );

      expect(result.error, isNull);
      final body = result.body!;
      expect(body.pageInfo?.results, 25);
      expect(body.results, hasLength(2));
      expect(body.results![1].seasons, [1]);
    });
  });

  group('SeerrJsonConverter — invalid bodies fail without a secondary cast',
      () {
    Future<void> expectInvalid<Item>(String rawJson) async {
      final result = await _convert<Item>(rawJson);
      expect(result.statusCode, 200);
      expect(result.body, isNull);
      expect(result.error, isA<FormatException>());
    }

    test(
        'SeerrDiscoverResponse: "results" is a string instead of a list',
        () => expectInvalid<SeerrDiscoverResponse>(
              jsonEncode({'page': 1, 'results': 'not-a-list'}),
            ));

    test(
        'SeerrMediaRequest: "status" is a string instead of a number',
        () => expectInvalid<SeerrMediaRequest>(
              jsonEncode({'id': 512, 'status': 'pending'}),
            ));

    test(
        'SeerrMovieDetails: "voteAverage" is a string instead of a number',
        () => expectInvalid<SeerrMovieDetails>(
              jsonEncode({'id': 1, 'title': 'X', 'voteAverage': 'high'}),
            ));

    test(
        'SeerrMediaInfo: "status" is a nested object instead of a number',
        () => expectInvalid<SeerrMediaInfo>(
              jsonEncode({
                'id': 1,
                'status': {'code': 5}
              }),
            ));

    test(
        'SeerrUserModel: "permissions" is a list instead of a number',
        () => expectInvalid<SeerrUserModel>(
              jsonEncode({'id': 1, 'permissions': []}),
            ));

    test('an unrecognized extra field is silently ignored, not fatal',
        () async {
      final result = await _convert<SeerrMediaRequest>(jsonEncode({
        'id': 512,
        'status': 1,
        'thisFieldDoesNotExistInTheModel': 'from a future API version',
      }));

      expect(result.error, isNull);
      expect(result.body?.id, 512);
    });
  });

  group('SeerrJsonConverter — response envelope', () {
    test('JSON null stays null for nullable and dynamic response types',
        () async {
      final dynamicResult = await _convert<dynamic>('null');
      final nullableResult = await _convert<SeerrMediaRequest?>('null');
      expect(dynamicResult.body, isNull);
      expect(dynamicResult.error, isNull);
      expect(nullableResult.body, isNull);
      expect(nullableResult.error, isNull);
    });

    test('an empty typed response exposes an error without losing the envelope',
        () async {
      final base = http.Response('', 200, headers: {'x-test': 'preserved'});
      final input = chopper.Response<String>(base, '');
      try {
        await const SeerrJsonConverter()
            .convertResponse<SeerrMediaRequest, SeerrMediaRequest>(input);
        fail('A typed empty 200 response must signal a conversion error');
      } on chopper.ChopperHttpException catch (e) {
        expect(e.response.body, isNull);
        expect(e.response.error, isA<FormatException>());
        expect(e.response.base, same(base));
        expect(e.response.headers['x-test'], 'preserved');
      }
    });

    test('an unknown response type exposes a conversion error', () async {
      final result = await _convert<Never>(jsonEncode({'foo': 'bar'}));
      expect(result.body, isNull);
      expect(result.error, isA<FormatException>());
    });

    test(
        '204 and empty dynamic responses preserve successful no-content actions',
        () async {
      for (final code in [200, 204]) {
        final result = await _convert<dynamic>('', statusCode: code);
        expect(result.body, isNull);
        expect(result.error, isNull);
        expect(result.statusCode, code);
      }
      final typed = await _convert<SeerrMediaRequest>('', statusCode: 204);
      expect(typed.body, isNull);
      expect(typed.error, isNull);
    });

    test('invalid JSON errors do not echo the response payload', () async {
      final result =
          await _convert<SeerrMediaRequest>('private-response-not-json');
      expect(result.error, isA<FormatException>());
      expect(result.error.toString(), isNot(contains('private-response')));
    });
  });
}
