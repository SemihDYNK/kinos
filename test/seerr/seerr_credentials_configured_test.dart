import 'package:flutter_test/flutter_test.dart';

import 'package:kinos/models/seerr_credentials_model.dart';

/// [SeerrCredentialsModel.isConfigured] is the single source of truth for
/// "is Seerr visible on this profile" - gated on it at three call sites
/// (`side_navigation_bar.dart`, `home_screen.dart`,
/// `library_filter_chips.dart`, all `user?.seerrCredentials?.isConfigured
/// ?? false`). Testing the getter once here covers all three without
/// pumping three separate widget trees.
void main() {
  group('SeerrCredentialsModel.isConfigured', () {
    test('false when nothing is set', () {
      expect(const SeerrCredentialsModel().isConfigured, isFalse);
    });

    test('false when only serverUrl is set (no way to authenticate yet)',
        () {
      expect(
        const SeerrCredentialsModel(serverUrl: 'https://seerr.example.com')
            .isConfigured,
        isFalse,
      );
    });

    test('false when only apiKey is set without a serverUrl - nothing to '
        'point it at', () {
      expect(
        const SeerrCredentialsModel(apiKey: 'key').isConfigured,
        isFalse,
      );
    });

    test('false when only sessionCookie is set without a serverUrl', () {
      expect(
        const SeerrCredentialsModel(sessionCookie: 'cookie').isConfigured,
        isFalse,
      );
    });

    test('true with serverUrl + apiKey', () {
      expect(
        const SeerrCredentialsModel(
          serverUrl: 'https://seerr.example.com',
          apiKey: 'key',
        ).isConfigured,
        isTrue,
      );
    });

    test('true with serverUrl + sessionCookie (no apiKey needed)', () {
      expect(
        const SeerrCredentialsModel(
          serverUrl: 'https://seerr.example.com',
          sessionCookie: 'cookie',
        ).isConfigured,
        isTrue,
      );
    });

    test('true with both apiKey and sessionCookie set', () {
      expect(
        const SeerrCredentialsModel(
          serverUrl: 'https://seerr.example.com',
          apiKey: 'key',
          sessionCookie: 'cookie',
        ).isConfigured,
        isTrue,
      );
    });

    test('false again after logoutSeerr-style clearing (serverUrl kept, '
        'both secrets blanked) - mirrors UserNotifier.logoutSeerr', () {
      const afterLogout = SeerrCredentialsModel(
        serverUrl: 'https://seerr.example.com',
        apiKey: '',
        sessionCookie: '',
      );
      expect(afterLogout.isConfigured, isFalse);
    });
  });
}
