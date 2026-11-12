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
import 'package:kinos/providers/seerr_api_provider.dart';
import 'package:kinos/providers/seerr_service_provider.dart';
import 'package:kinos/seerr/seerr_models.dart';
import 'package:kinos/models/items/images_models.dart';
import 'package:kinos/models/seerr/seerr_dashboard_model.dart';
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

/// Jellyfin ne connaît que le titre original ; les identifiants demandés
/// explicitement sont renvoyés tels quels.
class TitleApi extends CatalogApi {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName != #itemsGet) {
      return super.noSuchMethod(invocation);
    }
    calls.add(invocation.namedArguments);
    final ids = invocation.namedArguments[#ids] as List<String>?;
    final term = invocation.namedArguments[#searchTerm] as String?;
    final found = ids != null
        ? [for (final id in ids) movie(id)]
        : term == 'Slow Horses'
            ? [movie('slow-horses')]
            : <ItemBaseModel>[];
    return Future.value(
        Response(http.Response('', 200), ServerQueryResult(items: found)));
  }
}

ItemBaseModel movie(String id) =>
    MovieModel.fromBaseDto(BaseItemDto(id: id, name: id), null);

class FakeSeerrService implements SeerrService {
  FakeSeerrService(this.results, {this.fails = false});
  final List<SeerrDashboardPosterModel> results;
  final bool fails;
  final queries = <(String, String?)>[];
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName != #searchPosters) {
      return super.noSuchMethod(invocation);
    }
    queries.add((
      invocation.namedArguments[#query] as String,
      invocation.namedArguments[#language] as String?
    ));
    if (fails) return Future<List<SeerrDashboardPosterModel>>.error('down');
    return Future.value(results);
  }
}

class FakeSeerrApi extends SeerrApi {
  FakeSeerrApi(this.service);
  final FakeSeerrService service;
  @override
  SeerrService build() => service;
}

SeerrDashboardPosterModel seerrHit(String? jellyfinId,
        {String title = 'Titre', int tmdbId = 1}) =>
    SeerrDashboardPosterModel(
        id: '$tmdbId',
        type: SeerrMediaType.tvshow,
        tmdbId: tmdbId,
        title: title,
        overview: '',
        images: ImagesData(),
        mediaStatus: SeerrMediaStatus.unknown,
        jellyfinItemId: jellyfinId);

const fr = 'fr';

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
    final seerr = FakeSeerrService([]);
    final container = ProviderContainer(overrides: [
      userProvider.overrideWith(TestUser.new),
      jellyApiProvider.overrideWith(() => Api(api)),
      seerrApiProvider.overrideWith(() => FakeSeerrApi(seerr)),
    ]);
    addTearDown(container.dispose);
    await container
        .read(quickSearchProvider((query: '   ', language: fr)).future);
    expect(api.calls, isEmpty);
    expect(seerr.queries, isEmpty);
    await container
        .read(quickSearchProvider((query: 'Dune', language: fr)).future);
    expect(api.calls.single[#searchTerm], 'Dune');
    expect(api.calls.single[#includeItemTypes],
        [BaseItemKind.movie, BaseItemKind.series]);
    (container.read(userProvider.notifier) as TestUser).change('b');
    await container
        .read(quickSearchProvider((query: 'Dune', language: fr)).future);
    expect(api.calls, hasLength(2));
  });

  group('translated titles', () {
    Future<(QuickSearchResults, TitleApi, FakeSeerrService)> run(
        String query, FakeSeerrService seerr) async {
      final api = TitleApi();
      final container = ProviderContainer(overrides: [
        userProvider.overrideWith(TestUser.new),
        jellyApiProvider.overrideWith(() => Api(api)),
        seerrApiProvider.overrideWith(() => FakeSeerrApi(seerr)),
      ]);
      addTearDown(container.dispose);
      final results = await container
          .read(quickSearchProvider((query: query, language: fr)).future);
      return (results, api, seerr);
    }

    test('a French title finds the library entry through Seerr', () async {
      final (results, api, seerr) = await run('Les Déshonorés',
          FakeSeerrService([seerrHit('slow-horses'), seerrHit('')]));
      expect(seerr.queries, [('Les Déshonorés', fr)]);
      expect(results.library.map((item) => item.id), ['slow-horses']);
      expect(api.calls.last[#ids], ['slow-horses']);
    });

    test('titles already found by Jellyfin are not duplicated', () async {
      final (results, api, _) = await run('Slow Horses',
          FakeSeerrService([seerrHit('SLOW-HORSES'), seerrHit('other')]));
      expect(results.library.map((item) => item.id), ['slow-horses', 'other']);
      expect(results.outside, isEmpty);
      expect(api.calls.last[#ids], ['other']);
    });

    test('titles Jellyfin does not have are grouped apart, in Seerr order',
        () async {
      final (results, _, _) = await run(
          'Dune',
          FakeSeerrService([
            for (var i = 0; i < 10; i++)
              seerrHit(i == 3 ? 'dune' : null, title: 'Dune $i', tmdbId: i),
          ]));
      expect(results.library.map((item) => item.id), ['dune']);
      expect(results.outside.map((poster) => poster.title), [
        for (final i in [0, 1, 2, 4, 5, 6, 7, 8]) 'Dune $i'
      ]);
    });

    test('a Seerr failure keeps the Jellyfin results', () async {
      final (results, api, _) = await run(
          'Slow Horses', FakeSeerrService([seerrHit('x')], fails: true));
      expect(results.library.map((item) => item.id), ['slow-horses']);
      expect(results.outside, isEmpty);
      expect(api.calls, hasLength(1));
    });
  });
}
