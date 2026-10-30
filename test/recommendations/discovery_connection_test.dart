import 'dart:async';
import 'package:chopper/chopper.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/jellyfin/jellyfin_open_api.swagger.dart';
import 'package:kinos/models/account_model.dart';
import 'package:kinos/models/credentials_model.dart';
import 'package:kinos/models/seerr_credentials_model.dart';
import 'package:kinos/models/syncing/database_item.dart';
import 'package:kinos/providers/api_provider.dart';
import 'package:kinos/providers/database_provider.dart';
import 'package:kinos/providers/service_provider.dart';
import 'package:kinos/providers/user_provider.dart';
import 'package:kinos/recommendations/seerr/discovery_providers.dart';

class Profile extends User {
  @override
  AccountModel build() => AccountModel(
      name: 'Profil',
      id: 'user',
      avatar: '',
      lastUsed: DateTime(2026),
      credentials: CredentialsModel.internal(serverId: 'server'),
      seerrCredentials: const SeerrCredentialsModel(
          serverUrl: 'https://seerr', apiKey: 'secret'));
  void refresh() => state =
      state!.copyWith(name: 'Profil actualisé', lastUsed: DateTime.now());
}

class BlockingLibrary implements JellyService {
  int requests = 0;
  final pending = Completer<Response<BaseItemDtoQueryResult>>();
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #usersUserIdItemsGet) {
      requests++;
      return pending.future;
    }
    return super.noSuchMethod(invocation);
  }
}

class Api extends JellyApi {
  Api(this.library);
  final BlockingLibrary library;
  @override
  JellyService build() => library;
}

void main() {
  test('refreshing profile information preserves an in-flight discovery',
      () async {
    final library = BlockingLibrary();
    final container = ProviderContainer(overrides: [
      userProvider.overrideWith(Profile.new),
      jellyApiProvider.overrideWith(() => Api(library)),
      appDatabaseProvider
          .overrideWith((ref) => AppDatabase(ref, NativeDatabase.memory())),
    ]);
    addTearDown(container.dispose);
    final db = container.read(appDatabaseProvider);
    addTearDown(db.close);
    const scope = (
      serverId: 'server',
      userId: 'user',
      seerrUrl: 'https://seerr',
      language: 'fr',
      cacheDays: 7
    );
    final subscription =
        container.listen(seerrDiscoveryProvider(scope), (_, __) {});
    addTearDown(subscription.close);
    for (var i = 0; i < 100 && library.requests == 0; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(library.requests, 1);
    (container.read(userProvider.notifier) as Profile).refresh();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    final requests = library.requests;
    library.pending.completeError(StateError('End pending request'));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(requests, 1,
        reason:
            'The periodic profile refresh must not restart library pagination');
  });
}
