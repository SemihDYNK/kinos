import 'package:kinos/providers/user_provider.dart';
import '../widgets/seerr_discovery_section_test.dart' show TestUser;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/arr/providers/arr_jellyfin_link_provider.dart';
import 'package:kinos/jellyfin/jellyfin_open_api.swagger.dart' show BaseItemDto;
import 'package:kinos/models/items/movie_model.dart';
import 'package:kinos/providers/api_provider.dart';
import '../providers/catalog_navigation_test.dart' show CatalogApi, Api;

MovieModel movie(String id, String title, int year, {String original = ''}) =>
    MovieModel.fromBaseDto(
            BaseItemDto(id: id, name: title, productionYear: year), null)
        .copyWith(originalTitle: original);
void main() {
  test('profile change invalidates a retained link lookup', () async {
    final api = CatalogApi()..items = [movie('first', 'Film', 2024)];
    final container = ProviderContainer(overrides: [
      jellyApiProvider.overrideWith(() => Api(api)),
      userProvider.overrideWith(TestUser.new),
    ]);
    addTearDown(container.dispose);
    final provider =
        arrJellyfinLinkProvider((title: 'Film', year: 2024, isMovie: true));
    final subscription = container.listen(provider, (_, __) {});
    addTearDown(subscription.close);
    expect((await container.read(provider.future))?.id, 'first');
    api.items = [movie('second', 'Film', 2024)];
    (container.read(userProvider.notifier) as TestUser).change('second-user');
    expect((await container.read(provider.future))?.id, 'second');
    expect(api.calls.length, 2);
  });

  for (final scenario in [
    (items: [movie('one', 'Film', 2024)], id: 'one'),
    (items: [movie('one', 'Film traduit', 2024, original: 'Film')], id: 'one'),
    (items: [movie('one', 'Film', 2023)], id: null),
    (items: [movie('one', 'Film', 2024), movie('two', 'Film', 2024)], id: null),
  ]) {
    test(
        'only a unique exact work is linked: ${scenario.id}, ${scenario.items.length} results',
        () async {
      final api = CatalogApi()..items = scenario.items;
      final container = ProviderContainer(
          overrides: [jellyApiProvider.overrideWith(() => Api(api))]);
      addTearDown(container.dispose);
      final result = await container.read(
          arrJellyfinLinkProvider((title: 'Film', year: 2024, isMovie: true))
              .future);
      expect(result?.id, scenario.id);
    });
  }
}
