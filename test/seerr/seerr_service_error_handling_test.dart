import 'dart:async';
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

/// Builds a real [SeerrService] wired through a [ChopperClient] whose
/// underlying transport is a [MockClient] - same interceptor stack
/// (`SeerrRequest`) and converter (`SeerrJsonConverter`) as production, only
/// the HTTP transport and the account are swapped out.
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
  group('SeerrService — HTTP error status handling', () {
    // No `errorConverter` is configured on the ChopperClient (see
    // seerr_api_provider.dart's SeerrApi.build()). chopper's
    // ResponseConverterInterceptor._handleErrorResponse (chopper-8.4.0/lib/
    // src/interceptors/response_converter_interceptor.dart:71-82) only
    // consults `_errorConverter` when it's non-null; without one, ANY
    // non-2xx response short-circuits straight to
    // `Response(base, null, error: response.body)` using the RAW,
    // UNDECODED body string - `SeerrJsonConverter.convertResponse` is never
    // called at all for error statuses. That also means the converter's
    // `body: null` bug (documented in seerr_json_converter_test.dart) is
    // NOT reachable through this path - it only bites on a *successful*
    // (2xx) response whose body fails to decode, see the group below.
    test('401 with a JSON error body: does not throw, .error is the raw '
        'undecoded string (never parsed into a structured object, since '
        'no errorConverter is configured) - callers must check '
        'isSuccessful/statusCode, not try to read fields off .error',
        () async {
      final (service, container) = _service((request) async => http.Response(
            '{"message":"Unauthorized"}',
            401,
            headers: {'content-type': 'application/json'},
          ));
      addTearDown(container.dispose);

      final response = await service.status();

      expect(response.isSuccessful, isFalse);
      expect(response.statusCode, 401);
      expect(response.error, '{"message":"Unauthorized"}');
      expect(response.body, isNull);
    });

    test('403 for me(): same shape, service.me() returns the response '
        'unmodified rather than throwing (user is null, so me() returns '
        'the raw response without touching response.body)', () async {
      final (service, container) = _service((request) async => http.Response(
            '{"message":"Forbidden"}',
            403,
            headers: {'content-type': 'application/json'},
          ));
      addTearDown(container.dispose);

      final response = await service.me();

      expect(response.isSuccessful, isFalse);
      expect(response.statusCode, 403);
    });

    test('502 with an HTML error body (reverse proxy in front of a down '
        'Seerr instance): also just surfaces as the raw string in .error, '
        'not a crash - confirms non-JSON error bodies are as harmless as '
        'JSON ones, since neither is ever parsed without an errorConverter',
        () async {
      final (service, container) = _service((request) async => http.Response(
            '<html><body>502 Bad Gateway</body></html>',
            502,
            headers: {'content-type': 'text/html'},
          ));
      addTearDown(container.dispose);

      final response = await service.status();

      expect(response.isSuccessful, isFalse);
      expect(response.error, contains('502 Bad Gateway'));
    });
  });

  group('SeerrService — the converter bug IS reachable through a 2xx '
      'response (unlike the 401/502 cases above)', () {
    // Through the full stack, SeerrRequest.intercept's own catch-all
    // (seerr_api_provider.dart:83-90) wraps whatever exception comes back
    // up the chain - including this TypeError - into an HttpException
    // (message preserved via string interpolation, original type lost).
    // seerr_json_converter_test.dart exercises the converter directly and
    // sees the bare TypeError; this is what a real caller of SeerrService
    // actually receives.
    test('a 200 OK with an empty body currently throws instead of '
        'returning a null body - hits seerr_json_converter.dart:60 through '
        'the full service stack, not just the converter in isolation. A '
        'real Seerr instance returning 200 with an empty body (e.g. a '
        'misbehaving proxy stripping the body) would crash the caller.',
        () async {
      final (service, container) = _service((request) async => http.Response(
            '',
            200,
          ));
      addTearDown(container.dispose);

      await expectLater(
        service.status(),
        throwsA(isA<HttpException>().having(
          (e) => e.message,
          'message',
          contains('type \'String\' is not a subtype'),
        )),
      );
    });

    test('a 200 OK with a malformed field currently throws instead of '
        'surfacing response.error - hits seerr_json_converter.dart:75 '
        'through the full service stack', () async {
      final (service, container) = _service((request) async => http.Response(
            '{"version": {"nested": "not-a-string"}}',
            200,
            headers: {'content-type': 'application/json'},
          ));
      addTearDown(container.dispose);

      await expectLater(
        service.status(),
        throwsA(isA<HttpException>().having(
          (e) => e.message,
          'message',
          contains('type \'String\' is not a subtype'),
        )),
      );
    });
  });

  group('SeerrService — transport failures', () {
    test('connection refused / unreachable host: wrapped as HttpException '
        'by SeerrRequest, not left as a raw SocketException', () async {
      final (service, container) = _service((request) async {
        throw const SocketException('Connection refused');
      });
      addTearDown(container.dispose);

      await expectLater(service.status(), throwsA(isA<HttpException>()));
    });

    test('a timeout from the underlying transport is wrapped the same way '
        '- there is no Seerr-specific timeout policy '
        '(lib/util/seerr_http_client.dart just returns a plain '
        'http.Client(), no .timeout() anywhere in lib/providers/seerr_*. '
        'dart or lib/seerr/) so a slow/hanging server currently has no '
        'client-side cutoff at all; this documents what happens if the '
        'transport itself ever throws one', () async {
      final (service, container) = _service((request) async {
        throw TimeoutException('timed out', const Duration(seconds: 30));
      });
      addTearDown(container.dispose);

      await expectLater(service.status(), throwsA(isA<HttpException>()));
    });

    test('the wrapped HttpException for a transport failure does not leak '
        'the apiKey', () async {
      final (service, container) = _service((request) async {
        throw const SocketException('Connection refused');
      });
      addTearDown(container.dispose);

      try {
        await service.status();
        fail('expected an exception');
      } catch (e) {
        expect(e.toString(), isNot(contains('test-key')));
      }
    });
  });
}
