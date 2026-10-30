import 'package:chopper/chopper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:kinos/jellyfin/jellyfin_open_api.swagger.dart';
import 'package:kinos/providers/api_provider.dart';
import 'package:kinos/providers/dashboard/hero_items_provider.dart';
import 'package:kinos/providers/service_provider.dart';
import 'package:kinos/providers/user_provider.dart';
import '../widgets/seerr_discovery_section_test.dart' show TestUser;

class RandomLibrary implements JellyService {
  int calls = 0;
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName != #usersUserIdItemsGet) {
      return super.noSuchMethod(invocation);
    }
    expect(invocation.namedArguments[#sortBy], [ItemSortBy.random]);
    expect(invocation.namedArguments[#includeItemTypes], [BaseItemKind.movie]);
    expect(invocation.namedArguments[#recursive], true);
    calls++;
    return Future.value(Response(
        http.Response('', 200),
        BaseItemDtoQueryResult(items: [
          BaseItemDto(
              id: 'random$calls',
              name: 'Ancien film',
              type: BaseItemKind.movie,
              dateCreated: DateTime(2000),
              userData: const UserItemDataDto(played: true)),
        ])));
  }
}

class Api extends JellyApi {
  Api(this.library);
  final RandomLibrary library;
  @override
  JellyService build() => library;
}

void main() {
  test(
      'random films include old watched titles, stay stable, and isolate profiles',
      () async {
    final library = RandomLibrary();
    final container = ProviderContainer(overrides: [
      userProvider.overrideWith(TestUser.new),
      jellyApiProvider.overrideWith(() => Api(library)),
    ]);
    addTearDown(container.dispose);
    final first = await container.read(heroItemsProvider.future);
    expect(first.single.id, 'random1');
    expect(first.single.userData.played, true);
    expect(await container.read(heroItemsProvider.future), same(first));
    expect(library.calls, 1);
    (container.read(userProvider.notifier) as TestUser).change('b');
    final second = await container.read(heroItemsProvider.future);
    expect(second.single.id, 'random2');
    expect(library.calls, 2);
  });
}
