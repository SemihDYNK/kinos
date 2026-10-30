import 'package:chopper/chopper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:kinos/jellyfin/jellyfin_open_api.swagger.dart';
import 'package:kinos/providers/api_provider.dart';
import 'package:kinos/models/item_base_model.dart';
import 'package:kinos/models/items/movie_model.dart';
import 'package:kinos/providers/service_provider.dart';
import 'package:kinos/providers/user_provider.dart';
import 'package:kinos/providers/dashboard/catalog_navigation_provider.dart';
import '../widgets/seerr_discovery_section_test.dart' show TestUser;

class CatalogApi implements JellyService {
  final calls = <Map<Symbol, dynamic>>[];
  List<ItemBaseModel> items = [];
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName != #itemsGet) {
      return super.noSuchMethod(invocation);
    }
    calls.add(invocation.namedArguments);
    return Future.value(
        Response(http.Response('', 200), ServerQueryResult(items: items)));
  }
}

class Api extends JellyApi {
  Api(this.api);
  final CatalogApi api;
  @override
  JellyService build() => api;
}

void main() {
  test('series library home scopes hero, recents and resume on the server',
      () async {
    final api = CatalogApi();
    final container = ProviderContainer(overrides: [
      userProvider.overrideWith(TestUser.new),
      jellyApiProvider.overrideWith(() => Api(api))
    ]);
    addTearDown(container.dispose);
    const scope = (kind: BaseItemKind.series, libraryId: 'shows');
    await container.read(catalogHomeProvider(scope).future);
    expect(api.calls, hasLength(3));
    expect(
        api.calls.every(
            (call) => call[#parentId] == 'shows' && call[#recursive] == true),
        isTrue);
    expect(api.calls[0][#includeItemTypes], [BaseItemKind.series]);
    expect(api.calls[1][#includeItemTypes], [BaseItemKind.series]);
    expect(api.calls[2][#includeItemTypes], [BaseItemKind.episode]);
    expect(api.calls[2][#filters], [ItemFilter.isresumable]);
  });
  test(
      'resume excludes unstarted and completed titles even if the API returns them',
      () async {
    final api = CatalogApi()
      ..items = [
        for (final entry in [
          ('new', 0, false),
          ('started', 10000, false),
          ('done', 50000, true)
        ])
          MovieModel.fromBaseDto(
              BaseItemDto(
                  id: entry.$1,
                  name: entry.$1,
                  userData: UserItemDataDto(
                      playbackPositionTicks: entry.$2, played: entry.$3)),
              null),
      ];
    final container = ProviderContainer(overrides: [
      userProvider.overrideWith(TestUser.new),
      jellyApiProvider.overrideWith(() => Api(api))
    ]);
    addTearDown(container.dispose);
    final home = await container.read(
        catalogHomeProvider((kind: BaseItemKind.movie, libraryId: null))
            .future);
    expect(home.hero, hasLength(3));
    expect(home.resume.map((item) => item.id), ['started']);
  });
  test('empty quick search makes no request; results are profile scoped',
      () async {
    final api = CatalogApi();
    final container = ProviderContainer(overrides: [
      userProvider.overrideWith(TestUser.new),
      jellyApiProvider.overrideWith(() => Api(api))
    ]);
    addTearDown(container.dispose);
    await container.read(quickSearchProvider('   ').future);
    expect(api.calls, isEmpty);
    await container.read(quickSearchProvider('Dune').future);
    expect(api.calls.single[#searchTerm], 'Dune');
    expect(api.calls.single[#includeItemTypes],
        [BaseItemKind.movie, BaseItemKind.series]);
    (container.read(userProvider.notifier) as TestUser).change('b');
    await container.read(quickSearchProvider('Dune').future);
    expect(api.calls, hasLength(2));
  });
}
