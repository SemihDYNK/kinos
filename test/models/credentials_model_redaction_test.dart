import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kinos/models/credentials_model.dart';

void main() {
  group('CredentialsModel redaction', () {
    final creds = CredentialsModel.internal(
      token: 'super-secret-session-token',
      url: 'https://jellyfin.example.com',
      serverId: 'server-1',
      deviceId: 'device-1',
    );

    test('toString never prints the real token', () {
      final text = creds.toString();
      expect(text, isNot(contains('super-secret-session-token')));
      expect(text, contains('token: <redacted>'));
      // Non-secret fields still show through, unchanged.
      expect(text, contains('url: https://jellyfin.example.com'));
      expect(text, contains('serverId: server-1'));
    });

    test('toString on an empty token mentions nothing redacted', () {
      final empty = CredentialsModel.internal(serverId: 'server-1');
      expect(empty.toString(), isNot(contains('<redacted>')));
    });

    test('debugFillProperties (what DevTools reads) never exposes the real token', () {
      final builder = DiagnosticPropertiesBuilder();
      creds.debugFillProperties(builder);

      final tokenProperty = builder.properties.firstWhere((p) => p.name == 'token');
      expect(tokenProperty.value, isNot('super-secret-session-token'));
      expect(tokenProperty.value, '<redacted>');
    });
  });
}
