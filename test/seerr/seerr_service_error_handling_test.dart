import 'dart:async';
import 'dart:io';

import 'package:chopper/chopper.dart' as chopper;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:kinos/models/account_model.dart';
import 'package:kinos/models/api_result.dart';
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
    {http.Client? client}) {
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
    client: client ?? MockClient(handler),
    converter: const SeerrJsonConverter(),
    interceptors: [SeerrRequest(ref)],
  );

  final service = SeerrService(ref, SeerrChopperService.create(chopperClient));
  return (service, container);
}

void main() {
  group('SeerrService — HTTP error status handling', () {
    // Non-2xx responses keep Chopper's raw error body; the converter handles 2xx only.
    test(
        '401 with a JSON error body: does not throw, .error is the raw '
        'undecoded string (never parsed into a structured object, since '
        'no errorConverter is configured) - callers must check '
        'isSuccessful/statusCode, not try to read fields off .error', () async {
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

    test(
        '403 for me(): same shape, service.me() returns the response '
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

    test(
        '502 with an HTML error body (reverse proxy in front of a down '
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

  group('SeerrService — invalid successful responses', () {
    for (final body in ['', '{"version": {"nested": "not-a-string"}}']) {
      test(
          'invalid 200 response is returned as an error and not an API success ($body)',
          () async {
        final (service, container) = _service((_) async => http.Response(
            body, 200,
            headers: {'content-type': 'application/json'}));
        addTearDown(container.dispose);
        final response = await service.status();
        expect(response.statusCode, 200);
        expect(response.body, isNull);
        expect(response.error, isA<FormatException>());
        expect(response.apiResult.isSuccess, isFalse);
        expect((await Future.value(response).apiResult).isSuccess, isFalse);
      });
    }
  });

  group('SeerrService — transport failures', () {
    for (final stallBody in [false, true]) {
      testWidgets(
          'a stalled ${stallBody ? 'body' : 'connection'} is aborted after 30 seconds',
          (tester) async {
        final pending = Completer<http.StreamedResponse>();
        final body = StreamController<List<int>>();
        var aborted = false;
        var calls = 0;
        var sawAbortable = false;
        final client = MockClient.streaming((request, _) async {
          calls++;
          sawAbortable = request is http.Abortable;
          unawaited((request as http.Abortable).abortTrigger!.then((_) {
            aborted = true;
            if (stallBody) {
              body.addError(http.RequestAbortedException(request.url));
              unawaited(body.close());
            }
          }));
          if (stallBody) return http.StreamedResponse(body.stream, 200);
          return await pending.future;
        });
        final (service, container) = _service(
            (_) async => throw StateError('Unused transport'),
            client: client);
        addTearDown(container.dispose);
        Object? failure;
        unawaited(service.status().then((_) {}, onError: (Object error) {
          failure = error;
        }));
        await tester.pump();
        await tester.pump(const Duration(seconds: 29));
        expect(failure, isNull);
        expect(aborted, isFalse);
        await tester.pump(const Duration(seconds: 2));
        expect(failure, isA<HttpException>());
        expect(failure.toString(), contains('TimeoutException'));
        expect(aborted, isTrue);
        expect(sawAbortable, isTrue);
        expect(calls, 1);
        if (!stallBody) {
          pending.complete(http.StreamedResponse(Stream.value([]), 200));
        }
        await tester.pump();
      });
    }

    test(
        'connection refused / unreachable host: wrapped as HttpException '
        'by SeerrRequest, not left as a raw SocketException', () async {
      final (service, container) = _service((request) async {
        throw const SocketException('Connection refused');
      });
      addTearDown(container.dispose);

      await expectLater(service.status(), throwsA(isA<HttpException>()));
    });

    test('a transport timeout is exposed as HttpException', () async {
      final (service, container) = _service((request) async {
        throw TimeoutException('timed out', const Duration(seconds: 30));
      });
      addTearDown(container.dispose);

      await expectLater(service.status(), throwsA(isA<HttpException>()));
    });

    test(
        'the wrapped HttpException for a transport failure does not leak '
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
