import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/jellyfin/jellyfin_open_api.swagger.dart';
import 'package:kinos/l10n/generated/app_localizations.dart';
import 'package:kinos/letterboxd/friends/letterboxd_friends_parser.dart';
import 'package:kinos/letterboxd/home/letterboxd_home_providers.dart';
import 'package:kinos/letterboxd/home/letterboxd_watchlist_screen.dart';
import 'package:kinos/models/items/movie_model.dart';
import 'package:kinos/providers/user_provider.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/adaptive_layout/adaptive_layout.dart';
import 'package:kinos/util/adaptive_layout/adaptive_layout_model.dart';
import 'package:kinos/util/poster_defaults.dart';

import '../../widgets/seerr_discovery_section_test.dart' show TestUser;

LetterboxdHomeEntry entry(String slug, {bool owned = false}) => (
      film: LetterboxdFilmPage(
          slug: slug,
          tmdbId: '${slug.hashCode.abs()}',
          isMovie: true,
          title: slug),
      item: owned
          ? MovieModel.fromBaseDto(BaseItemDto(id: slug, name: slug), null)
          : null,
    );

void main() {
  testWidgets(
      'full watchlist: available first, then to request; Escape returns',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        userProvider.overrideWith(TestUser.new),
        letterboxdWatchlistProvider.overrideWith((ref) async => (
              library: [entry('owned', owned: true)],
              request: [entry('wanted-1'), entry('wanted-2')],
              pending: 3,
            )),
      ],
      child: MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildAppTheme(density: AppDensity.desk),
        builder: (context, child) => AdaptiveLayout(
            data: const AdaptiveLayoutModel(
                viewSize: ViewSize.desktop,
                layoutMode: LayoutMode.single,
                inputDevice: InputDevice.pointer,
                platform: TargetPlatform.linux,
                isDesktop: true,
                posterDefaults: PosterDefaults(size: 180, ratio: 2 / 3),
                controller: {},
                sideBarWidth: 0,
                topBarHeight: 0,
                statusBarHeight: 0),
            child: child!),
        home: Builder(
            builder: (context) => TextButton(
                onPressed: () => openLetterboxdWatchlist(context),
                child: const Text('ouvrir'))),
      ),
    ));
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
    expect(find.text('Votre watchlist'), findsOneWidget);
    final available = tester.getTopLeft(find.textContaining('Disponibles')).dy;
    final toRequest =
        tester.getTopLeft(find.textContaining('À demander').first).dy;
    expect(available, lessThan(toRequest));
    expect(find.text('À demander'), findsNWidgets(2),
        reason: 'two request tiles');
    expect(find.textContaining('3 films encore'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('ouvrir'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
