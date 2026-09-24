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
Future<chopper.Response<Item>> _convert<Item>(String rawJson, {int statusCode = 200}) async {
  final base = http.Response(rawJson, statusCode);
  final input = chopper.Response<String>(base, rawJson);
  return const SeerrJsonConverter().convertResponse<Item, Item>(input);
}

void main() {
  group('SeerrJsonConverter — realistic fixtures', () {
    test('decodes a discover/trending response (movie + tv + person + '
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
      expect(body.results![3].mediaType, isNull); // resolved downstream, not here
    });

    test('decodes a movie/<id> response, including nested externalIds and '
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
      expect(body.seasons, hasLength(1)); // top-level `seasons` list, from `genres`-sibling field
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

    test('decodes a freshly created TV request response, with seasons as a '
        'list of objects (not bare ints)', () async {
      final result = await _convert<SeerrMediaRequest>(
        _fixture('request_created_tv.synthetic.json'),
      );

      expect(result.error, isNull);
      final body = result.body!;
      expect(body.media?.tvdbId, 355567);
      expect(body.seasons, [1, 2]); // _parseRequestSeasons pulled seasonNumber out
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

  // BUG (found while writing these tests, not fixed here - see the report):
  // every "graceful failure" path in SeerrJsonConverter.convertResponse
  // (lib/seerr/seerr_json_converter.dart:60 and :75) actually throws an
  // uncaught TypeError instead of returning `body: null, error: ...`.
  //
  // Root cause is in chopper itself: `Response.copyWith<NewBodyType>({...
  // NewBodyType? body, ...})` (chopper-8.4.0/lib/src/response.dart:41-49)
  // resolves the new body as `body ?? (this.body as NewBodyType?)`. Dart's
  // optional named parameters don't distinguish "omitted" from
  // "explicitly passed null" - both leave the local `body` variable null -
  // so passing `body: null` (line 75) or omitting it (line 60's bare
  // `response.copyWith()`) both fall through to `this.body as NewBodyType?`,
  // which re-casts the ORIGINAL raw body (still the raw JSON String, or ''
  // for an empty response) onto the new model type. That cast fails for
  // every real ResultType, so the catch block meant to recover from a
  // decode error throws a *second*, different (TypeError) exception that
  // escapes `convertResponse` uncaught.
  //
  // Practical impact: a malformed field, an empty body, or an unregistered
  // response type - anything the converter's own try/catch exists to
  // handle - currently crashes the caller instead of surfacing
  // `response.error`. Per instructions this is reported, not silently
  // patched (fix would touch lib/seerr/seerr_json_converter.dart); tests
  // below document the actual current behavior so a future fix has a
  // baseline to flip.
  group('SeerrJsonConverter — malformed field currently crashes instead of '
      'failing gracefully (BUG, see comment above)', () {
    // Each case swaps ONE field to the wrong JSON type. json_serializable's
    // generated fromJson (no `checked: true` in build.yaml) does unsafe
    // casts and throws inside `factory(data)`, as intended - but the
    // converter's recovery from that throw is itself broken (see above),
    // so the exception that actually escapes is a TypeError from
    // response.dart:47, not the original decode error.
    Future<void> expectCurrentlyThrows<Item>(String rawJson) async {
      await expectLater(
        _convert<Item>(rawJson),
        throwsA(isA<TypeError>()),
      );
    }

    test('SeerrDiscoverResponse: "results" is a string instead of a list',
        () => expectCurrentlyThrows<SeerrDiscoverResponse>(
              jsonEncode({'page': 1, 'results': 'not-a-list'}),
            ));

    test('SeerrMediaRequest: "status" is a string instead of a number',
        () => expectCurrentlyThrows<SeerrMediaRequest>(
              jsonEncode({'id': 512, 'status': 'pending'}),
            ));

    test('SeerrMovieDetails: "voteAverage" is a string instead of a number',
        () => expectCurrentlyThrows<SeerrMovieDetails>(
              jsonEncode({'id': 1, 'title': 'X', 'voteAverage': 'high'}),
            ));

    test('SeerrMediaInfo: "status" is a nested object instead of a number',
        () => expectCurrentlyThrows<SeerrMediaInfo>(
              jsonEncode({
                'id': 1,
                'status': {'code': 5}
              }),
            ));

    test('SeerrUserModel: "permissions" is a list instead of a number',
        () => expectCurrentlyThrows<SeerrUserModel>(
              jsonEncode({'id': 1, 'permissions': []}),
            ));

    // Unknown/extra fields, by contrast, are genuinely harmless: generated
    // fromJson only ever reads the keys it knows about, so an extra field
    // the model doesn't declare is silently ignored - checked here once as
    // a smoke test, not per model (it's the same code path, `json[key]`
    // for a known key, for every model). This one does NOT hit the bug
    // above: decoding succeeds, so `convertResponse` takes the success
    // path (line 72, `body:` is non-null, `copyWith`'s `??` never falls
    // through to the broken cast).
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
    test('an empty body currently throws instead of passing through as '
        'null (BUG, see comment above group) - seerr_json_converter.dart:60',
        () async {
      final base = http.Response('', 200);
      final input = chopper.Response<String>(base, '');
      await expectLater(
        const SeerrJsonConverter()
            .convertResponse<SeerrMediaRequest, SeerrMediaRequest>(input),
        throwsA(isA<TypeError>()),
      );
    });

    test('a type not registered in _typeDeserializers currently throws '
        'instead of surfacing as response.error (BUG, see comment above '
        'group) - seerr_json_converter.dart:75', () async {
      // No `Item` type argument matching a real Seerr model on purpose.
      // `convertedData is! ResultType` throws inside the converter's own
      // try/catch for `Never` (unconstructable); the catch block's own
      // recovery then throws the second, unrelated TypeError.
      await expectLater(
        _convert<Never>(jsonEncode({'foo': 'bar'})),
        throwsA(isA<TypeError>()),
      );
    });
  });
}
