import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/jellyfin/jellyfin_open_api.swagger.dart';
import 'package:kinos/letterboxd/friends/letterboxd_friends_parser.dart';
import 'package:kinos/letterboxd/home/letterboxd_home_providers.dart';
import 'package:kinos/letterboxd/home/letterboxd_watchlist_screen.dart';
import 'package:kinos/models/items/movie_model.dart';
import 'package:kinos/providers/user_provider.dart';

import '../../widgets/seerr_discovery_section_test.dart' show TestUser;
import '../../widgets/support/page_shell.dart';

LetterboxdHomeEntry entry(String slug, {bool owned = false, int? year}) => (
      film: LetterboxdFilmPage(
          slug: slug,
          tmdbId: '${slug.hashCode.abs()}',
          isMovie: true,
          title: slug,
          year: year),
      item: owned
          ? MovieModel.fromBaseDto(BaseItemDto(id: slug, name: slug), null)
          : null,
    );

void main() {
  testWidgets('full watchlist: available first, then to request, with years',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = RecordingRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        userProvider.overrideWith(TestUser.new),
        letterboxdWatchlistProvider.overrideWith((ref) async => (
              library: [entry('owned', owned: true)],
              request: [entry('wanted-1', year: 1999), entry('wanted-2')],
              pending: 3,
            )),
      ],
      child: pageShell(const LetterboxdWatchlistScreen(), router),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Votre watchlist'), findsOneWidget);
    final available = tester.getTopLeft(find.textContaining('Disponibles')).dy;
    final toRequest =
        tester.getTopLeft(find.textContaining('À demander').first).dy;
    expect(available, lessThan(toRequest));
    expect(find.text('À demander'), findsNWidgets(2),
        reason: 'two request tiles');
    expect(find.text('wanted-1'), findsOneWidget);
    expect(find.text('1999'), findsOneWidget, reason: 'year under the poster');
    expect(find.textContaining('3 films encore'), findsOneWidget);
    await tester.tap(find.byTooltip('Retour · Échap'));
    await tester.pump();
    expect(router.popped, isTrue);
    expect(tester.takeException(), isNull);
  });
}
