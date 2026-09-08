import 'package:flutter_test/flutter_test.dart';

import 'package:kinos/arr/models/arr_credentials.dart';
import 'package:kinos/arr/models/arr_service.dart';
import 'package:kinos/arr/services/arr_credentials_store.dart';

import '../support/fake_secure_storage_platform.dart';

void main() {
  late FakeSecureStoragePlatform fakePlatform;
  late ArrCredentialsStore store;

  setUp(() {
    fakePlatform = FakeSecureStoragePlatform.install();
    store = const ArrCredentialsStore();
  });

  group('ArrCredentialsStore', () {
    test('keyFor composes a service-scoped key', () {
      expect(ArrCredentialsStore.keyFor(ArrService.radarr), 'arr:radarr');
      expect(ArrCredentialsStore.keyFor(ArrService.sonarr), 'arr:sonarr');
    });

    test('round-trips baseUrl and apiKey', () async {
      const credentials = ArrCredentials(
        baseUrl: 'https://radarr.example.com',
        apiKey: 'super-secret-key',
      );

      await store.save(ArrService.radarr, credentials);
      final read = await store.read(ArrService.radarr);

      expect(read, credentials);
    });

    test('Radarr and Sonarr credentials do not collide', () async {
      const radarr =
          ArrCredentials(baseUrl: 'https://radarr.local', apiKey: 'radarr-key');
      const sonarr =
          ArrCredentials(baseUrl: 'https://sonarr.local', apiKey: 'sonarr-key');

      await store.save(ArrService.radarr, radarr);
      await store.save(ArrService.sonarr, sonarr);

      expect(await store.read(ArrService.radarr), radarr);
      expect(await store.read(ArrService.sonarr), sonarr);
    });

    test('reading a service that was never saved returns null', () async {
      expect(await store.read(ArrService.radarr), isNull);
    });

    test('delete removes only the targeted service', () async {
      await store.save(
          ArrService.radarr, const ArrCredentials(baseUrl: 'a', apiKey: 'a'));
      await store.save(
          ArrService.sonarr, const ArrCredentials(baseUrl: 'b', apiKey: 'b'));

      await store.delete(ArrService.sonarr);

      expect(await store.read(ArrService.radarr), isNotNull);
      expect(await store.read(ArrService.sonarr), isNull);
    });

    test(
        'never stores anything under a plain key: it always goes through the platform under arr:<service>',
        () async {
      await store.save(
          ArrService.radarr, const ArrCredentials(baseUrl: 'a', apiKey: 'a'));

      expect(fakePlatform.values.keys, ['arr:radarr']);
    });

    test('a corrupted vault entry is treated as missing rather than thrown',
        () async {
      await fakePlatform
          .write(key: 'arr:radarr', value: 'not valid json', options: const {});

      expect(await store.read(ArrService.radarr), isNull);
    });
  });
}
