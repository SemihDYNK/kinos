import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// The login Keychain supports ad hoc macOS builds without an Apple team ID.
const platformSecureStorage = FlutterSecureStorage(
  mOptions: MacOsOptions(usesDataProtectionKeychain: false),
);
