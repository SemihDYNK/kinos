import 'dart:io';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinos/jellyfin/jellyfin_open_api.swagger.dart';
import 'package:kinos/l10n/generated/app_localizations.dart';
import 'package:kinos/models/items/images_models.dart';
import 'package:kinos/models/items/movie_model.dart';
import 'package:kinos/providers/theme/app_theme_provider.dart';
import 'package:kinos/providers/theme/palette_service_provider.dart';
import 'package:kinos/providers/user_provider.dart';
import 'package:kinos/providers/settings/client_settings_provider.dart';
import 'package:kinos/models/settings/client_settings_model.dart';
import 'package:kinos/screens/dashboard/home_hero_section.dart';
import 'package:kinos/screens/dashboard/single_row_section.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/theme/palette_service.dart';
import 'package:kinos/util/adaptive_layout/adaptive_layout.dart';
import 'package:kinos/util/adaptive_layout/adaptive_layout_model.dart';
import 'package:kinos/util/poster_defaults.dart';
import 'package:kinos/widgets/navigation_scaffold/components/side_navigation_bar.dart';
import '../seerr_discovery_section_test.dart' show TestUser;

class _ExpandedSettings extends ClientSettingsNotifier {
  _ExpandedSettings(super.ref);
  @override
  ClientSettingsModel get state => super.state.copyWith(expandSideBar: true);
}

final homeArtwork = ImageData(
    path: File('test/widgets/fixtures/home/coast.png').absolute.path,
    key: 'coast');

List<MovieModel> fixtureMovies({bool longTitle = false}) => List.generate(
    8,
    (index) => MovieModel.fromBaseDto(
            BaseItemDto(
                id: 'fixture-$index',
                name: index == 0
                    ? (longTitle
                        ? 'Éternels voyages à travers les océans et les montagnes oubliées'
                        : 'Le Chant du Large')
                    : 'Voyage ${index + 1}',
                productionYear: 2025,
                genres: const ['Drame'],
                overview:
                    'Une île, un retour. Et tout ce que la mer n’a pas emporté.'),
            null)
        .copyWith(
            images: ImagesData(
                primary: homeArtwork,
                thumb: homeArtwork,
                backDrop: [homeArtwork])));

Widget homeVisualFixture(
    {required Size viewport,
    required RootStackRouter router,
    double textScale = 1,
    AppDensity density = AppDensity.desk,
    bool emptyResume = false,
    bool longTitle = false,
    bool emptyHero = false,
    bool reducedMotion = false,
    bool expandedNavigation = false}) {
  final movies = fixtureMovies(longTitle: longTitle);
  final cache = InMemoryPaletteCache();
  for (final movie in movies) {
    cache.write(movie.id, const Color(0xFF245E61).toARGB32());
  }
  return ProviderScope(
      overrides: [
        userProvider.overrideWith(TestUser.new),
        if (expandedNavigation)
          clientSettingsProvider.overrideWith((ref) => _ExpandedSettings(ref)),
        sideBarForceCollapsedProvider.overrideWith((ref) => false),
        paletteServiceProvider.overrideWithValue(PaletteService(cache)),
      ],
      child: Consumer(builder: (context, ref, _) {
        final palette = ref.watch(heroPaletteProvider);
        return MaterialApp(
          locale: const Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: buildAppTheme(density: density, heroTint: palette.tint),
          home: MediaQuery(
              data: MediaQueryData(
                  size: viewport,
                  textScaler: TextScaler.linear(textScale),
                  disableAnimations: reducedMotion),
              child: StackRouterScope(
                  controller: router,
                  stateHash: 0,
                  child: AdaptiveLayout(
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
                    child: Scaffold(body:
                        SideNavigationRail(child: Builder(builder: (context) {
                      final padding = EdgeInsets.fromLTRB(
                          AdaptiveLayout.of(context).sideBarWidth + 32,
                          0,
                          32,
                          0);
                      return CustomScrollView(slivers: [
                        HomeHeroSection(
                            heroItems: emptyHero ? [] : movies,
                            resumeItems:
                                emptyResume ? [] : movies.take(4).toList(),
                            contentPadding: padding),
                        SliverPadding(
                            padding: const EdgeInsets.only(top: 32),
                            sliver: SingleRowSection(
                                title: 'Ajouts récents',
                                items: movies,
                                contentPadding: padding)),
                      ]);
                    }))),
                  ))),
        );
      }));
}
