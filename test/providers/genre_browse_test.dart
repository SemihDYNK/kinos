import 'package:chopper/chopper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:kinos/jellyfin/jellyfin_open_api.swagger.dart';
import 'package:kinos/models/item_base_model.dart';
import 'package:kinos/models/items/movie_model.dart';
import 'package:kinos/providers/api_provider.dart';
import 'package:kinos/providers/dashboard/catalog_navigation_provider.dart';
import 'package:kinos/providers/dashboard/genre_browse_provider.dart';
import 'package:kinos/providers/service_provider.dart';
import 'package:kinos/providers/user_provider.dart';

import '../widgets/seerr_discovery_section_test.dart' show TestUser;

class GenreApi implements JellyService {
  GenreApi(this.genres);
  final List<String> genres;
  final itemCalls = <Map<Symbol, dynamic>>[];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #genresGet) {
      return Future.value(Response(
          http.Response('', 200),
          BaseItemDtoQueryResult(
              items: [for (final g in genres) BaseItemDto(name: g)])));
    }
    if (invocation.memberName == #itemsGet) {
      itemCalls.add(invocation.namedArguments);
      return Future.value(Response(
          http.Response('', 200),
          ServerQueryResult(items: [
            MovieModel.fromBaseDto(const BaseItemDto(id: 'm', name: 'm'), null)
          ])));
    }
    return super.noSuchMethod(invocation);
  }
}

class _Api extends JellyApi {
  _Api(this.api);
  final GenreApi api;
  @override
  JellyService build() => api;
}

void main() {
  test('genre names merge across taxonomies and sort by label', () {
    final groups = groupGenreNames([
      'Drama',
      'Action & Adventure',
      'Adventure',
      'Action',
      'Aventure',
      'Action/Aventure',
      'Drame',
      '  ',
    ]);
    expect(groups.keys.toList(), ['Action', 'Aventure', 'Drame']);
    expect(groups['Action'],
        unorderedEquals(['Action', 'Action & Adventure', 'Action/Aventure']));
    expect(groups['Aventure'], unorderedEquals(['Adventure', 'Aventure']));
    expect(groups['Drame'], unorderedEquals(['Drama', 'Drame']));
  });

  test('a genre tile samples every merged name; a page keys on them', () async {
    final api = GenreApi(['Action', 'Action/Aventure', 'Drame']);
    final container = ProviderContainer(overrides: [
      userProvider.overrideWith(TestUser.new),
      jellyApiProvider.overrideWith(() => _Api(api)),
    ]);
    addTearDown(container.dispose);
    const scope = (kind: BaseItemKind.movie, libraryId: null);
    final genres = await container.read(browseGenresProvider(scope).future);
    expect(genres.map((g) => g.label), ['Action', 'Drame']);
    expect(genres.first.names, ['Action', 'Action/Aventure']);
    final sampled = api.itemCalls
        .map((call) => (call[#genres] as List<String>).join('|'))
        .toSet();
    expect(sampled, {'Action|Action/Aventure', 'Drame'});
    expect(api.itemCalls.every((c) => c[#includeItemTypes] is List), isTrue);

    api.itemCalls.clear();
    final page = await container.read(
        genrePageProvider(genrePageKey(scope, genres.first.names)).future);
    expect(page.topRated, hasLength(1));
    expect(page.movies, isEmpty, reason: 'not mixed outside « À la une »');
    expect(api.itemCalls, hasLength(4));
    expect(api.itemCalls.map((c) => (c[#genres] as List<String>).join('|')),
        everyElement('Action|Action/Aventure'));
  });

  test('« À la une » adds a movie row and a series row to the genre page',
      () async {
    final api = GenreApi(['Drame']);
    final container = ProviderContainer(overrides: [
      userProvider.overrideWith(TestUser.new),
      jellyApiProvider.overrideWith(() => _Api(api)),
    ]);
    addTearDown(container.dispose);
    final page = await container
        .read(genrePageProvider(genrePageKey(allCatalog, ['Drame'])).future);
    expect(api.itemCalls, hasLength(6));
    expect(page.movies, hasLength(1));
    expect(page.series, hasLength(1));
  });

  test('decades: newest first, small decades dropped, best rated kept', () {
    ItemBaseModel film(String id, int? year) => MovieModel.fromBaseDto(
        BaseItemDto(id: id, name: id, productionYear: year), null);
    final decades = groupByDecade([
      for (var i = 0; i < 20; i++) film('n$i', 2010 + i % 10),
      for (var i = 0; i < 6; i++) film('o$i', 1990 + i),
      for (var i = 0; i < 4; i++) film('s$i', 1980 + i),
      film('undated', null),
    ]);
    expect(decades.keys.toList(), [2010, 1990], reason: '1980s has only 4');
    expect(decades[2010]!, hasLength(16), reason: 'one row per decade');
    expect(decades[2010]!.first.id, 'n0',
        reason: 'input order is rating order');
    expect(
        decades[1990]!.map((f) => f.id), ['o0', 'o1', 'o2', 'o3', 'o4', 'o5']);
  });
}
