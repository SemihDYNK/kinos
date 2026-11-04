import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final configuration in ['DebugProfile', 'Release']) {
    test('$configuration supports local Keychain access without a profile', () {
      final entitlements =
          File('macos/Runner/$configuration.entitlements').readAsStringSync();
      expect(entitlements, isNot(contains('<key>keychain-access-groups</key>')),
          reason: 'Ad hoc builds cannot claim a provisioned Keychain group');
      expect(entitlements,
          isNot(contains('<key>com.apple.security.app-sandbox</key>')),
          reason:
              'The sandboxed Keychain needs an Apple-provisioned entitlement');
    });
  }
}
