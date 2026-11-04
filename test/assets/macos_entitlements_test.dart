import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final configuration in ['DebugProfile', 'Release']) {
    test('$configuration supports local signing without a provisioning profile',
        () {
      final entitlements =
          File('macos/Runner/$configuration.entitlements').readAsStringSync();
      expect(entitlements, isNot(contains('<key>keychain-access-groups</key>')),
          reason: 'The login Keychain needs no restricted sharing entitlement');
      expect(
          entitlements, contains('<key>com.apple.security.app-sandbox</key>'));
      expect(entitlements,
          contains('<key>com.apple.security.network.client</key>'));
    });
  }
}
