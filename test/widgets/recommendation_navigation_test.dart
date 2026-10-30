import 'dart:async';
import 'package:kinos/arr/providers/arr_jellyfin_link_provider.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/models/item_base_model.dart';
import 'package:kinos/routes/auto_router.gr.dart';
import 'package:kinos/screens/dashboard/recommendation_tile.dart';
import 'package:kinos/screens/shared/media_navigation.dart';
import 'seerr_discovery_section_test.dart' show shell, PendingDetailsRouter;
import 'support/home_visual_fixture.dart' show homeArtwork;

void main() {
  for (final isMovie in [true, false]) {
    testWidgets('cached recommendation has a typed seed and its source hero',
        (tester) async {
      final router = PendingDetailsRouter();
      addTearDown(router.dispose);
      final tile = RecommendationTile.cachedJellyfin(
          itemId: 'cached',
          title: 'Titre',
          image: homeArtwork,
          isMovie: isMovie);
      await tester.pumpWidget(ProviderScope(
          child: StackRouterScope(
              controller: router,
              stateHash: 0,
              child: shell(RecommendationRowGrid(
                  title: 'Pour vous',
                  tiles: [tile],
                  contentPadding: EdgeInsets.zero)))));
      await tester.pumpAndSettle();
      final tag = tester.widget<Hero>(find.byType(Hero)).tag;
      await tester.tap(find.byType(MediaArtwork));
      await tester.pump();
      final route = router.opened as DetailsRoute;
      expect(route.args!.item!.type,
          isMovie ? KinosItemType.movie : KinosItemType.series);
      expect(route.args!.item!.images!.primary, same(homeArtwork));
      expect(tag, (route.args!.tag, false));
      expect(
          (route.args!.tag as MediaNavigationOrigin).image, same(homeArtwork));
      router.returned.complete();
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  for (final isMovie in [true, false]) {
    testWidgets(
        'set-aside cache resolves the native film or series before opening, movie=$isMovie',
        (tester) async {
      final router = PendingDetailsRouter();
      addTearDown(router.dispose);
      final response = Completer<ArrJellyfinLinkMatch?>();
      var calls = 0;
      final tile = RecommendationTile.cachedArr(
          arrId: 7,
          isMovie: isMovie,
          title: 'Film',
          year: 2024,
          posterUrl: '',
          apiKey: '');
      await tester.pumpWidget(ProviderScope(
          overrides: [
            arrJellyfinLinkProvider(
                    (title: 'Film', year: 2024, isMovie: isMovie))
                .overrideWith((ref) {
              calls++;
              return response.future;
            }),
          ],
          child: StackRouterScope(
              controller: router,
              stateHash: 0,
              child: shell(RecommendationRowGrid(
                  title: 'Mis de côté',
                  tiles: [tile],
                  contentPadding: EdgeInsets.zero)))));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(MediaArtwork));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byType(MediaArtwork));
      await tester.pump();
      expect(calls, 1);
      expect(router.opened, isNull);
      response.complete((id: 'native', name: 'Film'));
      await tester.pump();
      final route = router.opened as DetailsRoute;
      expect(route.args!.item!.id, 'native');
      expect(route.args!.item!.type,
          isMovie ? KinosItemType.movie : KinosItemType.series);
      expect(
          tester.widget<Hero>(find.byType(Hero)).tag, (route.args!.tag, false));
      router.returned.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets('set-aside cache opens the media page, with its source hero',
      (tester) async {
    final router = PendingDetailsRouter();
    addTearDown(router.dispose);
    final tile = RecommendationTile.cachedArr(
        arrId: 7, isMovie: true, title: 'Film', posterUrl: '', apiKey: '');
    await tester.pumpWidget(ProviderScope(
        overrides: [
          arrJellyfinLinkProvider((title: 'Film', year: null, isMovie: true))
              .overrideWith((ref) async => null)
        ],
        child: StackRouterScope(
            controller: router,
            stateHash: 0,
            child: shell(RecommendationRowGrid(
                title: 'Mis de côté',
                tiles: [tile],
                contentPadding: EdgeInsets.zero)))));
    await tester.pumpAndSettle();
    final tag = tester.widget<Hero>(find.byType(Hero)).tag;
    await tester.tap(find.byType(MediaArtwork));
    await tester.pump();
    final route = router.opened as ArrTitleDetailsRoute;
    expect(route.args!.id, 7);
    expect(tag, (route.args!.tag, false));
    router.returned.complete();
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
