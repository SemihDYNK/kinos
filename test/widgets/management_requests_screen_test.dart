import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/models/items/images_models.dart';
import 'package:kinos/models/seerr/seerr_dashboard_model.dart';
import 'package:kinos/providers/seerr_dashboard_provider.dart';
import 'package:kinos/providers/seerr_user_provider.dart';
import 'package:kinos/screens/seerr/seerr_screen.dart';
import 'package:kinos/screens/seerr/widgets/seerr_request_banner_card.dart';
import 'package:kinos/seerr/seerr_models.dart';
import 'seerr_discovery_section_test.dart' show shell, PendingDetailsRouter;
import 'seerr_discover_screen_test.dart' show User;

class RequestsDashboard extends SeerrDashboard {
  @override
  SeerrDashboardModel build() => SeerrDashboardModel(recentRequests: [
        for (final name in ['Disponible', 'En attente'])
          SeerrDashboardPosterModel(
              id: name,
              type: SeerrMediaType.movie,
              tmdbId: 1,
              title: 'Film $name',
              overview: '',
              images: ImagesData(),
              mediaStatus: name == 'Disponible'
                  ? SeerrMediaStatus.available
                  : SeerrMediaStatus.pending,
              jellyfinItemId: null),
      ]);
  @override
  Future<void> fetchDashboard() async {}
}

void main() {
  testWidgets('request filters and title search operate on the actual screen',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = PendingDetailsRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          seerrDashboardProvider.overrideWith(RequestsDashboard.new),
          seerrUserProvider.overrideWith(User.new),
        ],
        child: StackRouterScope(
            controller: router,
            stateHash: 0,
            child: shell(const SliverFillRemaining(child: SeerrScreen())))));
    await tester.pumpAndSettle();
    expect(find.byType(SeerrRequestBannerCard), findsNWidgets(2));
    await tester.tap(find.text('En attente 1'));
    await tester.pumpAndSettle();
    expect(find.byType(SeerrRequestBannerCard), findsOneWidget);
    expect(find.text('Film En attente'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'absent');
    await tester.pumpAndSettle();
    expect(find.byType(SeerrRequestBannerCard), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
