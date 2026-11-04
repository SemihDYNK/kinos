import 'dart:convert';
import 'package:chopper/chopper.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kinos/anilist/anilist_account.dart';
import 'package:kinos/anilist/anilist_catalog.dart';
import 'package:kinos/anilist/anilist_client.dart';
import 'package:kinos/anilist/anilist_providers.dart';
import 'package:kinos/anilist/anilist_runtime.dart';
import 'package:kinos/anilist/episode_store.dart';
import 'package:kinos/jellyfin/jellyfin_open_api.swagger.dart';
import 'package:kinos/providers/api_provider.dart';
import 'package:kinos/providers/service_provider.dart';
import 'package:kinos/providers/database_provider.dart';
import 'package:kinos/providers/user_provider.dart';
import 'package:kinos/providers/incognito_mode_provider.dart';
import 'package:kinos/providers/connectivity_provider.dart';
import 'package:kinos/models/syncing/database_item.dart';
import '../widgets/seerr_discovery_section_test.dart' show TestUser;

class _Source implements JellyService {
  final pageStarts = <int>[];
  bool watched = true;
  @override
  dynamic noSuchMethod(Invocation call) {
    if (call.memberName == #usersUserIdItemsItemIdGetBaseItem) {
      final id = call.namedArguments[#itemId] as String;
      return Future.value(Response(
          http.Response('', 200),
          id == 'series'
              ? const BaseItemDto(
                  id: 'series',
                  name: 'Anime',
                  type: BaseItemKind.series,
                  providerIds: {'Tvdb': '900'})
              : BaseItemDto(
                  id: 'episode',
                  type: BaseItemKind.episode,
                  seriesId: 'series',
                  indexNumber: 25,
                  parentIndexNumber: 2,
                  userData: UserItemDataDto(played: watched))));
    }
    if (call.memberName == #showsSeriesIdEpisodesGet) {
      final start = call.namedArguments[#startIndex] as int;
      pageStarts.add(start);
      return Future.value(Response(
          http.Response('', 200),
          const BaseItemDtoQueryResult(items: [
            BaseItemDto(
                id: 'episode',
                indexNumber: 25,
                parentIndexNumber: 2,
                userData: UserItemDataDto(played: true)),
          ], totalRecordCount: 1)));
    }
    return super.noSuchMethod(call);
  }
}

class _Api extends JellyApi {
  final JellyService service;
  _Api(this.service);
  @override
  JellyService build() => service;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('manual marking queues AniList progress after Jellyfin confirms it',
      () async {
    final source = _Source();
    final writes = <Map>[];
    late AppDatabase db;
    final container = ProviderContainer(overrides: [
      userProvider.overrideWith(TestUser.new),
      incognitoProvider.overrideWithValue(false),
      offlineStateProvider.overrideWith((ref) => false),
      appDatabaseProvider.overrideWith((ref) {
        db = AppDatabase(ref, NativeDatabase.memory());
        return db;
      }),
      jellyApiProvider.overrideWith(() => _Api(source)),
      anilistConnectionProvider.overrideWith((ref) async =>
          const AnilistConnection(
              id: 9, name: 'Viewer', token: 'private', enabled: true)),
      anilistCatalogProvider.overrideWith((ref) => AnilistCatalog(
          read: () async => null,
          write: (_) async {},
          fetch: () async =>
              '[{"anilist_id":1,"tvdb_id":900,"season":{"tvdb":2}},{"anilist_id":2,"tvdb_id":900,"season":{"tvdb":2},"episode_offset":{"tvdb":24}}]')),
      anilistClientFactoryProvider
          .overrideWithValue(({String? token}) => AnilistClient(
              token: token,
              interval: Duration.zero,
              client: MockClient((r) async {
                final j = jsonDecode(r.body) as Map;
                final q = j['query'] as String;
                if (q.contains('SaveMediaListEntry')) {
                  writes.add(j['variables'] as Map);
                  return http.Response(
                      '{"data":{"SaveMediaListEntry":{"mediaId":2,"progress":1,"status":"CURRENT"}}}',
                      200);
                }
                if (q.contains('MediaList(')) return http.Response('', 404);
                if (q.contains('Page(')) {
                  return http.Response(
                      '{"data":{"Page":{"media":[{"id":1,"type":"ANIME","episodes":24},{"id":2,"type":"ANIME","episodes":24}]}}}',
                      200);
                }
                return http.Response(
                    '{"data":{"Media":{"id":2,"type":"ANIME","episodes":24}}}',
                    200);
              }))),
    ]);
    final listener = container.listen(anilistRuntimeProvider, (_, __) {});
    addTearDown(() async {
      listener.close();
      container.dispose();
      await db.close();
    });
    final runtime = container.read(anilistRuntimeProvider);
    final playbackRef = container.read(Provider<Ref>((ref) => ref));
    final initialScope = anilistScopeFor(playbackRef)!;
    await container.read(appDatabaseProvider).setSetting('configured',
        jsonEncode({'id': 9, 'enabled': true, 'generation': 'original'}),
        scope: '$initialScope:account');
    await captureAnilistMarkedPlayed(playbackRef, 'episode',
        responseSuccessful: true);
    await runtime.drain();
    await runtime.drain();
    expect(writes.single['mediaId'], 2);
    expect(writes.single['progress'], 1);
    expect(source.pageStarts, [0]);
    source.watched = false;
    await runtime.capture('episode')();
    await runtime.drain();
    await runtime.drain();
    expect(writes, hasLength(1));
    final scope = anilistScopeFor(container.read(Provider<Ref>((ref) => ref)))!;
    await db.setSetting('configured',
        jsonEncode({'id': 9, 'enabled': true, 'generation': 'original'}),
        scope: '$scope:account');
    final provenance = await runtime.provenance();
    expect(provenance, jsonEncode([scope, 9, true, 'original']));
    await runtime.capture('must-not-leak',
        expectedProvenance: jsonEncode([scope, 10, true, 'original']))();
    expect(await EpisodeStore(db, scope).pending(), isEmpty);
    await db.setSetting('configured',
        jsonEncode({'id': 9, 'enabled': false, 'generation': 'original'}),
        scope: '$scope:account');
    expect(await runtime.provenance(), isNull);
    await db.setSetting('configured',
        jsonEncode({'id': 9, 'enabled': true, 'generation': 'new-session'}),
        scope: '$scope:account');
    await runtime.capture('old-session', expectedProvenance: provenance)();
    expect(await EpisodeStore(db, scope).pending(), isEmpty);
    final remember = runtime.capture('episode');
    (container.read(userProvider.notifier) as TestUser).change('b');
    await container.pump();
    await remember();
    expect(runtime.current, isFalse);
    expect(container.read(anilistRuntimeProvider), isNot(same(runtime)));
  });
}
