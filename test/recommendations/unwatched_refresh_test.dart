import 'package:chopper/chopper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:kinos/jellyfin/jellyfin_open_api.swagger.dart';
import 'package:kinos/providers/api_provider.dart';
import 'package:kinos/recommendations/providers/recommendation_providers.dart';
import 'discovery_connection_test.dart' show Api, BlockingLibrary;

void main() {
  test('refresh clears the preview without modifying a provider during build',
      () async {
    final library = BlockingLibrary();
    final container = ProviderContainer(overrides: [
      jellyApiProvider.overrideWith(() => Api(library)),
    ]);
    addTearDown(container.dispose);
    container.read(unwatchedLibraryFirstPageProvider.notifier).state = [];
    final preview =
        container.listen(unwatchedLibraryFirstPageProvider, (_, __) {});
    addTearDown(preview.close);
    final dependency = Provider((ref) => ref.watch(unwatchedLibraryProvider));
    final subscription = container.listen(dependency, (_, __) {});
    addTearDown(subscription.close);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(unwatchedLibraryFirstPageProvider), isNull);
    library.pending.complete(Response(http.Response('', 200),
        const BaseItemDtoQueryResult(items: [], totalRecordCount: 0)));
    expect(await container.read(unwatchedLibraryProvider.future), isEmpty);
  });
}
