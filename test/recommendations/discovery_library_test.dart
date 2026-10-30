import 'dart:async';
import 'package:chopper/chopper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:kinos/jellyfin/jellyfin_open_api.swagger.dart';
import 'package:kinos/providers/service_provider.dart';
import 'package:kinos/recommendations/seerr/discovery_library.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinos/models/syncing/database_item.dart';
import 'package:kinos/providers/database_provider.dart';
import 'package:kinos/recommendations/seerr/discovery_cache.dart';

class IncrementalLibrary implements JellyService {
  final calls = <Invocation>[];
  var changed = false;
  var failInventory = false;
  @override
  dynamic noSuchMethod(Invocation call) {
    calls.add(call);
    final args = call.namedArguments;
    final lean = (args[#fields] as List).length == 1;
    if (lean && failInventory) throw StateError('Inventory unavailable');
    final delta = args[#minDateLastSaved] != null;
    final ids = args[#ids] as List<String>?;
    final items = lean
        ? [
            const BaseItemDto(
                id: 'b', name: 'B', userData: UserItemDataDto(played: true))
          ]
        : delta
            ? (changed
                ? [
                    const BaseItemDto(id: 'b', name: 'B', genres: ['Comedy'])
                  ]
                : <BaseItemDto>[])
            : ids != null
                ? [
                    const BaseItemDto(
                        id: 'b',
                        name: 'B',
                        genres: ['Drama'],
                        providerIds: {'Tmdb': '123'})
                  ]
                : [
                    const BaseItemDto(id: 'a', name: 'A', genres: ['Drama'])
                  ];
    return Future.value(Response(http.Response('', 200),
        BaseItemDtoQueryResult(items: items, totalRecordCount: items.length)));
  }
}

class SlowLibrary implements JellyService {
  SlowLibrary({this.truncated = false});
  final bool truncated;
  int active = 0;
  int maximumActive = 0;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName != #usersUserIdItemsGet) {
      return super.noSuchMethod(invocation);
    }
    return page(invocation.namedArguments[#startIndex] as int,
        invocation.namedArguments[#limit] as int);
  }

  Future<Response<BaseItemDtoQueryResult>> page(int start, int limit) async {
    active++;
    if (active > maximumActive) maximumActive = active;
    try {
      // A metadata-heavy server cannot serve large pages within the deadline.
      if (limit > 50) throw TimeoutException('Large metadata page');
      await Future<void>.delayed(Duration.zero);
      return Response(
          http.Response('', 200),
          BaseItemDtoQueryResult(
            totalRecordCount: 123,
            items: [
              if (!truncated || start == 0)
                for (var i = start; i < start + limit && i < 123; i++)
                  BaseItemDto(id: '$i'),
            ],
          ));
    } finally {
      active--;
    }
  }
}

void main() {
  test(
      'warm cache queries fresh IDs, merges additions/deletions/history and metadata changes',
      () async {
    final container = ProviderContainer(overrides: [
      appDatabaseProvider
          .overrideWith((ref) => AppDatabase(ref, NativeDatabase.memory())),
    ]);
    addTearDown(container.dispose);
    final db = container.read(appDatabaseProvider);
    addTearDown(db.close);
    final cache = DiscoveryCache(db, 'profile', const Duration(days: 7));
    final server = IncrementalLibrary();
    await loadDiscoveryLibrary(server, cache: cache, check: () {});
    server.calls.clear();
    var result = await loadDiscoveryLibrary(server, cache: cache, check: () {});
    expect(result.single.id, 'b');
    expect(result.single.genres, ['Drama']);
    expect(result.single.providerIds, isNull);
    expect(result.single.userData?.played, true);
    expect(
        server.calls.every((c) =>
            (c.namedArguments[#fields] as List).length == 1 ||
            c.namedArguments[#minDateLastSaved] != null ||
            c.namedArguments[#ids] != null),
        true);
    server.changed = true;
    result = await loadDiscoveryLibrary(server, cache: cache, check: () {});
    expect(result.single.genres, ['Comedy']);
    expect(result.single.userData?.played, true);
    final saved = await cache.read('jellyfin-metadata:v1');
    expect((saved!['items'] as List).single, isNot(contains('UserData')));
    server.failInventory = true;
    await expectLater(loadDiscoveryLibrary(server, cache: cache, check: () {}),
        throwsStateError);
  });
  test('loads the entire slow library with sequential bounded metadata pages',
      () async {
    final server = SlowLibrary();
    final result = await loadDiscoveryLibrary(server, check: () {});
    expect(result.map((item) => item.id), [for (var i = 0; i < 123; i++) '$i']);
    expect(server.maximumActive, 1);
  });

  test('never accepts an incomplete exclusion snapshot', () async {
    await expectLater(
        loadDiscoveryLibrary(SlowLibrary(truncated: true), check: () {}),
        throwsException);
  });
}
