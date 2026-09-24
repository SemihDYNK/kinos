import 'package:chopper/chopper.dart' as chopper;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:kinos/models/account_model.dart';
import 'package:kinos/models/credentials_model.dart';
import 'package:kinos/models/seerr_credentials_model.dart';
import 'package:kinos/providers/seerr_api_provider.dart';
import 'package:kinos/providers/seerr_service_provider.dart' show kBrowserManagedCookie;
import 'package:kinos/providers/user_provider.dart';
import 'package:kinos/seerr/seerr_chopper_service.dart';
import 'package:kinos/seerr/seerr_json_converter.dart';

/// Only overrides `build()` - never touches `User.api` (a `late final`
/// field reading `jellyApiProvider`, which would drag in an unrelated
/// Jellyfin client setup this test has no use for). `late final` isn't
/// evaluated until read, and nothing here reads it.
class _FakeUser extends User {
  _FakeUser(this._account);
  final AccountModel? _account;

  @override
  AccountModel? build() => _account;
}

AccountModel _account({
  String serverUrl = 'https://seerr.example.com',
  String apiKey = '',
  String sessionCookie = '',
  Map<String, String> customHeaders = const {},
}) =>
    AccountModel(
      name: 'test',
      id: 'user-1',
      avatar: '',
      lastUsed: DateTime(2024, 1, 1),
      credentials: CredentialsModel.internal(serverId: 'server-1'),
      seerrCredentials: SeerrCredentialsModel(
        serverUrl: serverUrl,
        apiKey: apiKey,
        sessionCookie: sessionCookie,
        customHeaders: customHeaders,
      ),
    );

/// Drives a real [SeerrRequest] interceptor through a [ChopperClient] backed
/// by [MockClient], the same way `seerr_api_provider.dart`'s real
/// `SeerrApi.build()` wires it - only the underlying `http.Client` and the
/// account are swapped out. Returns the outgoing [http.Request] chopper
/// actually sent, so headers/URL can be inspected directly rather than
/// re-deriving them from the (private) `_authHeaders` helper.
Future<http.Request> _capturedRequest({
  required AccountModel? account,
  String path = '/status',
}) async {
  late http.Request captured;
  final container = ProviderContainer(
    overrides: [userProvider.overrideWith(() => _FakeUser(account))],
  );
  addTearDown(container.dispose);
  // SeerrRequest's constructor wants a Ref, not a ProviderContainer - this
  // throwaway provider is the standard trick to hand it one bound to our
  // container, without needing a full widget tree.
  final ref = container.read(Provider<Ref>((ref) => ref));

  final chopperClient = chopper.ChopperClient(
    client: MockClient((request) async {
      captured = request;
      return http.Response('{}', 200);
    }),
    converter: const SeerrJsonConverter(),
    interceptors: [SeerrRequest(ref)],
  );

  final api = SeerrChopperService.create(chopperClient);
  await api.getStatus();
  return captured;
}

void main() {
  group('SeerrRequest — auth header selection', () {
    test('apiKey set: sends X-Api-Key, no Cookie header', () async {
      final request = await _capturedRequest(
        account: _account(apiKey: 'secret-key'),
      );

      expect(request.headers['X-Api-Key'], 'secret-key');
      expect(request.headers.containsKey('Cookie'), isFalse);
    });

    test('sessionCookie set (real cookie, apiKey empty): sends Cookie, no '
        'X-Api-Key', () async {
      final request = await _capturedRequest(
        account: _account(sessionCookie: 'connect.sid=abc123'),
      );

      expect(request.headers['Cookie'], 'connect.sid=abc123');
      expect(request.headers.containsKey('X-Api-Key'), isFalse);
    });

    test('apiKey takes priority over sessionCookie when both are set',
        () async {
      final request = await _capturedRequest(
        account: _account(apiKey: 'secret-key', sessionCookie: 'connect.sid=abc123'),
      );

      expect(request.headers['X-Api-Key'], 'secret-key');
      expect(request.headers.containsKey('Cookie'), isFalse);
    });

    test('sessionCookie == kBrowserManagedCookie: neither header is sent '
        '(the browser attaches its own cookie natively on web)', () async {
      final request = await _capturedRequest(
        account: _account(sessionCookie: kBrowserManagedCookie),
      );

      expect(request.headers.containsKey('X-Api-Key'), isFalse);
      expect(request.headers.containsKey('Cookie'), isFalse);
    });

    test('neither apiKey nor sessionCookie set: no auth header at all',
        () async {
      final request = await _capturedRequest(account: _account());

      expect(request.headers.containsKey('X-Api-Key'), isFalse);
      expect(request.headers.containsKey('Cookie'), isFalse);
    });

    test('customHeaders are merged in on top of the auth header', () async {
      final request = await _capturedRequest(
        account: _account(
          apiKey: 'secret-key',
          customHeaders: {'X-Custom-Trace': 'abc'},
        ),
      );

      expect(request.headers['X-Api-Key'], 'secret-key');
      expect(request.headers['X-Custom-Trace'], 'abc');
    });

    test('a customHeaders entry named X-Api-Key overrides the credential-'
        "derived one - documents current behavior (last-write-wins via "
        'map spread order in seerr_api_provider.dart, customHeaders is '
        'spread after authHeaders); not asserting this is desirable, just '
        'what happens today', () async {
      final request = await _capturedRequest(
        account: _account(
          apiKey: 'secret-key',
          customHeaders: {'X-Api-Key': 'overridden-by-custom-header'},
        ),
      );

      expect(request.headers['X-Api-Key'], 'overridden-by-custom-header');
    });
  });

  group('SeerrRequest — URL resolution', () {
    test('the request is resolved against the configured serverUrl, not a '
        'hardcoded host', () async {
      final request = await _capturedRequest(
        account: _account(serverUrl: 'https://my-seerr.example.net', apiKey: 'k'),
        path: '/status',
      );

      expect(request.url.host, 'my-seerr.example.net');
      expect(request.url.scheme, 'https');
    });

    test('a serverUrl with a trailing slash still resolves the API path '
        'correctly, not doubled', () async {
      final request = await _capturedRequest(
        account: _account(serverUrl: 'https://seerr.example.com/', apiKey: 'k'),
      );

      expect(request.url.host, 'seerr.example.com');
      expect(request.url.path, isNot(contains('//')));
    });

    test('no serverUrl configured: the interceptor throws before any '
        'network call is made (never sends a request to an empty/garbage '
        'host)', () async {
      await expectLater(
        _capturedRequest(account: _account(serverUrl: '', apiKey: 'k')),
        throwsA(anything),
      );
    });

    test('no account at all (logged out): the interceptor throws before '
        'any network call', () async {
      await expectLater(
        _capturedRequest(account: null),
        throwsA(anything),
      );
    });
  });

  group('SeerrRequest — no secret leakage on failure', () {
    test('the exception thrown when serverUrl is missing does not contain '
        'the apiKey or sessionCookie', () async {
      try {
        await _capturedRequest(
          account: _account(serverUrl: '', apiKey: 'super-secret-key', sessionCookie: 'super-secret-cookie'),
        );
        fail('expected an exception');
      } catch (e) {
        final message = e.toString();
        expect(message, isNot(contains('super-secret-key')));
        expect(message, isNot(contains('super-secret-cookie')));
      }
    });
  });
}
