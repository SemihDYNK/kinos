import 'dart:convert';
import 'dart:io';

import 'package:chopper/chopper.dart' as chopper;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:kinos/models/account_model.dart';
import 'package:kinos/models/credentials_model.dart';
import 'package:kinos/models/seerr_credentials_model.dart';
import 'package:kinos/providers/seerr_api_provider.dart';
import 'package:kinos/providers/seerr_service_provider.dart';
import 'package:kinos/providers/user_provider.dart';
import 'package:kinos/seerr/seerr_chopper_service.dart';
import 'package:kinos/seerr/seerr_json_converter.dart';

class _FakeUser extends User {
  _FakeUser(this._account);
  final AccountModel? _account;

  @override
  AccountModel? build() => _account;
}

/// Same wiring as seerr_request_headers_test.dart/
/// seerr_service_error_handling_test.dart: a real [SeerrService] through a
/// [ChopperClient] backed by [MockClient], so the request body asserted on
/// is exactly what chopper would put on the wire (JSON-encoded by
/// SeerrJsonConverter.convertRequest, inherited unmodified from
/// JsonConverter), not a hand re-derivation of `SeerrCreateRequestBody.
/// toJson()`.
(SeerrService, ProviderContainer) _service(
  Future<http.Response> Function(http.Request) handler,
) {
  final container = ProviderContainer(
    overrides: [
      userProvider.overrideWith(() => _FakeUser(AccountModel(
            name: 'test',
            id: 'user-1',
            avatar: '',
            lastUsed: DateTime(2024, 1, 1),
            credentials: CredentialsModel.internal(serverId: 'server-1'),
            seerrCredentials: const SeerrCredentialsModel(
              serverUrl: 'https://seerr.example.com',
              apiKey: 'test-key',
            ),
          ))),
    ],
  );
  final ref = container.read(Provider<Ref>((ref) => ref));

  final chopperClient = chopper.ChopperClient(
    client: MockClient(handler),
    converter: const SeerrJsonConverter(),
    interceptors: [SeerrRequest(ref)],
  );

  final service = SeerrService(ref, SeerrChopperService.create(chopperClient));
  return (service, container);
}

void main() {
  group('SeerrService — request creation body construction', () {
    test('requestMovie: mediaType movie, mediaId is the tmdbId, no seasons '
        'key at all (includeIfNull: false)', () async {
      late Map<String, dynamic> sentBody;
      final (service, container) = _service((request) async {
        sentBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          '{"id": 512, "status": 1}',
          201,
          headers: {'content-type': 'application/json'},
        );
      });
      addTearDown(container.dispose);

      await service.requestMovie(tmdbId: 603692, profileId: 6, rootFolder: '/movies');

      expect(sentBody['mediaType'], 'movie');
      expect(sentBody['mediaId'], 603692);
      expect(sentBody.containsKey('seasons'), isFalse);
      expect(sentBody['profileId'], 6);
      expect(sentBody['rootFolder'], '/movies');
      expect(sentBody['is4k'], false); // is4k defaults to false, not omitted
    });

    test('requestSeries: mediaType tv, seasons list is sent verbatim',
        () async {
      late Map<String, dynamic> sentBody;
      final (service, container) = _service((request) async {
        sentBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          '{"id": 513, "status": 1}',
          201,
          headers: {'content-type': 'application/json'},
        );
      });
      addTearDown(container.dispose);

      await service.requestSeries(tmdbId: 355567, seasons: [1, 2]);

      expect(sentBody['mediaType'], 'tv');
      expect(sentBody['mediaId'], 355567);
      expect(sentBody['seasons'], [1, 2]);
    });

    test('requestSeries with an empty seasons list: omitted entirely, not '
        'sent as []', () async {
      late Map<String, dynamic> sentBody;
      final (service, container) = _service((request) async {
        sentBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          '{"id": 513, "status": 1}',
          201,
          headers: {'content-type': 'application/json'},
        );
      });
      addTearDown(container.dispose);

      await service.requestSeries(tmdbId: 355567, seasons: []);

      expect(sentBody.containsKey('seasons'), isFalse);
    });

    test('requestMovie with is4k true and tags: both carried through',
        () async {
      late Map<String, dynamic> sentBody;
      final (service, container) = _service((request) async {
        sentBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          '{"id": 512, "status": 1}',
          201,
          headers: {'content-type': 'application/json'},
        );
      });
      addTearDown(container.dispose);

      await service.requestMovie(tmdbId: 603692, is4k: true, tags: [1, 2]);

      expect(sentBody['is4k'], true);
      expect(sentBody['tags'], [1, 2]);
    });

    test('neither requestMovie nor requestSeries body ever contains the '
        'apiKey or sessionCookie - only auth headers carry credentials, '
        'never the JSON body', () async {
      late Map<String, dynamic> sentBody;
      final (service, container) = _service((request) async {
        sentBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          '{"id": 512, "status": 1}',
          201,
          headers: {'content-type': 'application/json'},
        );
      });
      addTearDown(container.dispose);

      await service.requestMovie(tmdbId: 603692);

      expect(sentBody.toString(), isNot(contains('test-key')));
    });
  });

  group('SeerrService — request creation error responses', () {
    test('quota exceeded (409, Jellyseerr\'s real shape) does not throw; '
        '.error carries the raw message, caller must check isSuccessful',
        () async {
      final (service, container) = _service((request) async => http.Response(
            '{"message":"Request quota exceeded"}',
            409,
            headers: {'content-type': 'application/json'},
          ));
      addTearDown(container.dispose);

      final response = await service.requestMovie(tmdbId: 603692);

      expect(response.isSuccessful, isFalse);
      expect(response.statusCode, 409);
      expect(response.error, contains('quota'));
    });

    test('already requested (409 with a different message) - same shape, '
        'no exception', () async {
      final (service, container) = _service((request) async => http.Response(
            '{"message":"Movie already requested"}',
            409,
            headers: {'content-type': 'application/json'},
          ));
      addTearDown(container.dispose);

      final response = await service.requestMovie(tmdbId: 603692);

      expect(response.isSuccessful, isFalse);
      expect(response.error, contains('already requested'));
    });

    test('refused/declined by an admin policy (403) does not throw',
        () async {
      final (service, container) = _service((request) async => http.Response(
            '{"message":"Not authorized to request 4K media"}',
            403,
            headers: {'content-type': 'application/json'},
          ));
      addTearDown(container.dispose);

      final response = await service.requestMovie(tmdbId: 603692, is4k: true);

      expect(response.isSuccessful, isFalse);
      expect(response.statusCode, 403);
    });

    test('401 (session expired mid-request) does not throw', () async {
      final (service, container) = _service((request) async => http.Response(
            '{"message":"You must be logged in to request media."}',
            401,
            headers: {'content-type': 'application/json'},
          ));
      addTearDown(container.dispose);

      final response = await service.requestSeries(tmdbId: 355567, seasons: [1]);

      expect(response.isSuccessful, isFalse);
      expect(response.statusCode, 401);
    });

    test('no error response, for any of the above, ever contains the '
        'apiKey', () async {
      final (service, container) = _service((request) async => http.Response(
            '{"message":"Request quota exceeded"}',
            409,
            headers: {'content-type': 'application/json'},
          ));
      addTearDown(container.dispose);

      final response = await service.requestMovie(tmdbId: 603692);

      expect(response.error.toString(), isNot(contains('test-key')));
    });

    test('a network failure during request creation is wrapped as '
        'HttpException, not an unhandled exception type', () async {
      final (service, container) = _service((request) async {
        throw const SocketException('Connection refused');
      });
      addTearDown(container.dispose);

      await expectLater(
        service.requestMovie(tmdbId: 603692),
        throwsA(isA<HttpException>()),
      );
    });
  });
}
