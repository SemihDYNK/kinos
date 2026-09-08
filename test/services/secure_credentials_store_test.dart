import 'package:flutter_test/flutter_test.dart';

import 'package:kinos/models/credentials_model.dart';
import 'package:kinos/services/secure_credentials_store.dart';

import '../support/fake_secure_storage_platform.dart';

void main() {
  late FakeSecureStoragePlatform fakePlatform;
  late SecureCredentialsStore store;

  setUp(() {
    fakePlatform = FakeSecureStoragePlatform.install();
    store = const SecureCredentialsStore();
  });

  group('SecureCredentialsStore', () {
    test('keyFor composes a server:user key', () {
      expect(SecureCredentialsStore.keyFor('server-1', 'user-1'), 'server-1:user-1');
    });

    test('round-trips every CredentialsModel field, including localUrl', () async {
      final credentials = CredentialsModel.internal(
        token: 'super-secret-token',
        url: 'https://jellyfin.example.com',
        localUrl: 'http://192.168.1.10:8096',
        serverName: 'Home Server',
        serverId: 'server-1',
        deviceId: 'device-1',
      );

      await store.save('server-1', 'user-1', credentials);
      final read = await store.read('server-1', 'user-1');

      // CredentialsModel has no generated value equality (build.yaml turns
      // it off for Freezed classes), so compare field by field.
      expect(read, isNotNull);
      expect(read?.token, credentials.token);
      expect(read?.url, credentials.url);
      expect(read?.localUrl, credentials.localUrl);
      expect(read?.serverName, credentials.serverName);
      expect(read?.serverId, credentials.serverId);
      expect(read?.deviceId, credentials.deviceId);
    });

    test('two accounts on different servers do not collide', () async {
      final onServerA = CredentialsModel.internal(token: 'token-a', serverId: 'server-a');
      final onServerB = CredentialsModel.internal(token: 'token-b', serverId: 'server-b');

      // Same user id, different server: the multi-profile case the
      // composite key exists for.
      await store.save('server-a', 'user-1', onServerA);
      await store.save('server-b', 'user-1', onServerB);

      expect((await store.read('server-a', 'user-1'))?.token, 'token-a');
      expect((await store.read('server-b', 'user-1'))?.token, 'token-b');
    });

    test('two users on the same server do not collide', () async {
      final userA = CredentialsModel.internal(token: 'token-a', serverId: 'server-1');
      final userB = CredentialsModel.internal(token: 'token-b', serverId: 'server-1');

      await store.save('server-1', 'user-a', userA);
      await store.save('server-1', 'user-b', userB);

      expect((await store.read('server-1', 'user-a'))?.token, 'token-a');
      expect((await store.read('server-1', 'user-b'))?.token, 'token-b');
    });

    test('reading a key that was never saved returns null', () async {
      expect(await store.read('server-1', 'nobody'), isNull);
    });

    test('delete removes only the targeted entry', () async {
      await store.save('server-1', 'user-1', CredentialsModel.internal(token: 'keep-me', serverId: 'server-1'));
      await store.save('server-1', 'user-2', CredentialsModel.internal(token: 'delete-me', serverId: 'server-1'));

      await store.delete('server-1', 'user-2');

      expect(await store.read('server-1', 'user-1'), isNotNull);
      expect(await store.read('server-1', 'user-2'), isNull);
    });

    test('never stores anything under a plain key: it always goes through the platform under server:user', () async {
      await store.save('server-1', 'user-1', CredentialsModel.internal(token: 't', serverId: 'server-1'));

      expect(fakePlatform.values.keys, ['server-1:user-1']);
    });

    test('a corrupted vault entry is treated as missing rather than thrown', () async {
      await fakePlatform.write(key: 'server-1:user-1', value: 'not valid json', options: const {});

      expect(await store.read('server-1', 'user-1'), isNull);
    });
  });
}
