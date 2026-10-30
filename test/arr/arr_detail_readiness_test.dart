import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kinos/arr/models/arr_credentials.dart';
import 'package:kinos/arr/models/arr_service.dart';
import 'package:kinos/arr/providers/arr_detail_providers.dart';
import 'package:kinos/arr/providers/arr_providers.dart';
import 'package:kinos/arr/providers/arr_search_providers.dart';
import 'package:kinos/arr/services/arr_api_client.dart';
import 'package:kinos/arr/services/arr_credentials_store.dart';

class _Store extends ArrCredentialsStore {
  final loaded = Completer<ArrCredentials?>();
  @override
  Future<ArrCredentials?> read(ArrService service) => loaded.future;
}

void main() {
  test('detail waits for credentials then fetches without a manual retry',
      () async {
    final store = _Store();
    final ready = StateProvider<bool>((ref) => false);
    var calls = 0;
    final client = RadarrApiClient(
        baseUrl: 'https://arr.test',
        apiKey: 'key',
        httpClient: MockClient((request) async {
          calls++;
          return http.Response(jsonEncode({'id': 7, 'title': 'Film'}), 200);
        }));
    final container = ProviderContainer(overrides: [
      arrCredentialsStoreProvider.overrideWithValue(store),
      radarrClientProvider
          .overrideWith((ref) => ref.watch(ready) ? client : null),
    ]);
    addTearDown(container.dispose);
    const key = (service: ArrService.radarr, id: 7);
    final subscription = container.listen(arrDetailProvider(key), (_, __) {});
    addTearDown(subscription.close);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(arrDetailProvider(key)).loading, isTrue);
    expect(container.read(arrDetailProvider(key)).error, isNull);
    container.read(ready.notifier).state = true;
    await Future<void>.delayed(Duration.zero);
    expect(container.read(arrDetailProvider(key)).entry!.title, 'Film');
    expect(calls, 1);
    store.loaded.complete(ArrCredentials.empty);
    await Future<void>.delayed(Duration.zero);
  });
}
