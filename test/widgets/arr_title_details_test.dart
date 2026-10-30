import 'dart:async';
import 'dart:convert';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kinos/arr/models/arr_service.dart';
import 'package:kinos/arr/providers/arr_search_providers.dart';
import 'package:kinos/arr/screens/arr_title_details_screen.dart';
import 'package:kinos/arr/services/arr_api_client.dart';
import 'package:kinos/providers/theme/palette_service_provider.dart';
import 'package:kinos/screens/shared/media_detail_scaffold.dart';
import 'package:kinos/screens/shared/media_navigation.dart';
import 'package:kinos/theme/palette_service.dart';
import 'seerr_discovery_section_test.dart' show shell, PendingDetailsRouter;
import 'support/home_visual_fixture.dart' show homeArtwork;

void main() {
  for (final success in [true, false]) {
    testWidgets(
        'set-aside media view retains artwork before response, success=$success',
        (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('window_manager'), (_) async => null);
      final response = Completer<http.Response>();
      final client = RadarrApiClient(
          baseUrl: 'https://arr.test',
          apiKey: 'key',
          httpClient: MockClient((request) async {
            expect(request.url.path, '/api/v3/movie/7');
            return response.future;
          }));
      final router = PendingDetailsRouter();
      addTearDown(router.dispose);
      final cache = InMemoryPaletteCache();
      await cache.write('arr-radarr-7', const Color(0xFF245E61).toARGB32());
      final origin = MediaNavigationOrigin()..image = homeArtwork;
      await tester.pumpWidget(ProviderScope(
          overrides: [
            radarrClientProvider.overrideWithValue(client),
            paletteServiceProvider.overrideWithValue(PaletteService(cache)),
          ],
          child: StackRouterScope(
              controller: router,
              stateHash: 0,
              child: shell(SliverToBoxAdapter(
                  child: SizedBox(
                      height: 900,
                      child: ArrTitleDetailsScreen(
                          service: ArrService.radarr,
                          id: 7,
                          title: 'Film',
                          image: homeArtwork,
                          tag: origin)))))));
      await tester.pump();
      expect(find.byType(MediaDetailScaffold), findsOneWidget);
      expect(
          tester
              .widgetList<Hero>(find.byType(Hero))
              .any((hero) => hero.tag == (origin, false)),
          isTrue);
      response.complete(success
          ? http.Response(
              jsonEncode({
                'id': 7,
                'title': 'Film',
                'year': 2024,
                'overview': 'Résumé du film',
                'monitored': true,
                'images': []
              }),
              200)
          : http.Response('', 500));
      await tester.pumpAndSettle();
      expect(
          find.text('Résumé du film'), success ? findsOneWidget : findsNothing);
      expect(find.text('Fiche indisponible · Réessayer'),
          success ? findsNothing : findsOneWidget);
      expect(
          tester
              .widget<MediaDetailScaffold>(find.byType(MediaDetailScaffold))
              .onPlay,
          isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
