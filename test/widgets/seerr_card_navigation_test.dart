import 'package:kinos/util/focus_provider.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/models/items/images_models.dart';
import 'package:kinos/models/seerr/seerr_dashboard_model.dart';
import 'package:kinos/providers/seerr_user_provider.dart';
import 'package:kinos/routes/auto_router.gr.dart';
import 'package:kinos/screens/seerr/widgets/seerr_poster_card.dart';
import 'package:kinos/screens/shared/media_navigation.dart';
import 'package:kinos/seerr/seerr_models.dart';
import 'seerr_discovery_section_test.dart' show shell, PendingDetailsRouter;
import 'support/home_visual_fixture.dart' show homeArtwork;

class _User extends SeerrUser {
  @override
  SeerrUserModel? build() => null;
}

void main() {
  for (final type in [SeerrMediaType.movie, SeerrMediaType.tvshow]) {
    for (final available in [false, true]) {
      testWidgets(
          'discovery card $type available=$available transmits its hero and image',
          (tester) async {
        final router = PendingDetailsRouter();
        addTearDown(router.dispose);
        final poster = SeerrDashboardPosterModel(
            id: 'poster',
            type: type,
            tmdbId: 42,
            title: 'Titre',
            overview: 'Résumé',
            images: ImagesData(primary: homeArtwork),
            mediaStatus: SeerrMediaStatus.unknown,
            jellyfinItemId: available ? 'library' : null);
        await tester.pumpWidget(ProviderScope(
            overrides: [seerrUserProvider.overrideWith(_User.new)],
            child: StackRouterScope(
                controller: router,
                stateHash: 0,
                child: shell(SliverToBoxAdapter(
                    child: SizedBox(
                        width: 220,
                        height: 400,
                        child: SeerrPosterCard(poster: poster)))))));
        await tester.pumpAndSettle();
        final hero = tester.widget<Hero>(find.byType(Hero));
        await tester.tap(find.byType(FocusButton));
        await tester.pump();
        final Object? tag;
        if (available) {
          final route = router.opened as DetailsRoute;
          expect(route.args!.item!.id, 'library');
          tag = route.args!.tag;
        } else {
          final route = router.opened as SeerrDetailsRoute;
          expect(route.args!.poster, same(poster));
          expect(route.args!.mediaType,
              type == SeerrMediaType.tvshow ? 'tvshow' : 'movie');
          tag = route.args!.tag;
        }
        expect(hero.tag, (tag, false));
        expect((tag as MediaNavigationOrigin).image, same(homeArtwork));
        router.returned.complete();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
