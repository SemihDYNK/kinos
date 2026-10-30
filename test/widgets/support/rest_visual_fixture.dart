import 'package:kinos/screens/details_screens/components/movie_hero_content.dart';
import 'package:kinos/screens/details_screens/components/media_info_section.dart';
import 'package:kinos/widgets/shared/frosted_surface.dart';
import 'package:kinos/util/kinos_image.dart';
import 'package:kinos/models/items/episode_model.dart';
import 'package:kinos/models/items/item_shared_models.dart';
import 'package:kinos/models/items/media_streams_model.dart';
import 'package:kinos/models/items/overview_model.dart';
import 'package:kinos/models/items/season_model.dart';
import 'package:kinos/screens/shared/media/season_episode_section.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinos/arr/models/arr_queue_item.dart';
import 'package:kinos/arr/screens/widgets/arr_queue_table.dart';
import 'package:kinos/l10n/generated/app_localizations.dart';
import 'package:kinos/models/item_base_model.dart';
import 'package:kinos/models/items/images_models.dart';
import 'package:kinos/models/items/movie_model.dart';
import 'package:kinos/models/library_filter_model.dart';
import 'package:kinos/models/library_search/library_search_options.dart';
import 'package:kinos/models/seerr/seerr_dashboard_model.dart';
import 'package:kinos/providers/library_search_provider.dart';
import 'package:kinos/providers/seerr_user_provider.dart';
import 'package:kinos/providers/theme/palette_service_provider.dart';
import 'package:kinos/providers/user_provider.dart';
import 'package:kinos/screens/library_search/library_search_screen.dart';
import 'package:kinos/screens/library_search/widgets/library_views.dart';
import 'package:kinos/screens/seerr/widgets/seerr_request_banner_card.dart';
import 'package:kinos/screens/settings/widgets/settings_list_group.dart';
import 'package:kinos/screens/settings/settings_scaffold.dart';
import 'package:kinos/screens/settings/settings_list_tile.dart';
import 'package:kinos/screens/shared/chips/filter_button.dart';
import 'package:kinos/screens/shared/media_detail_scaffold.dart';
import 'package:kinos/seerr/seerr_models.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/theme/palette_service.dart';
import 'package:kinos/util/adaptive_layout/adaptive_layout.dart';
import 'package:kinos/util/adaptive_layout/adaptive_layout_model.dart';
import 'package:kinos/util/poster_defaults.dart';
import 'package:kinos/widgets/navigation_scaffold/components/side_navigation_bar.dart';
import 'package:kinos/widgets/shared/app_page_header.dart';
import '../seerr_discovery_section_test.dart' show TestUser;
import 'home_visual_fixture.dart' show fixtureMovies, homeArtwork;

const _libraryKey = ValueKey('visual-library');

class _Library extends LibrarySearchNotifier {
  _Library(super.ref, List<MovieModel> movies) {
    state = state.copyWith(
        posters: movies,
        filters: const LibraryFilterModel(types: {KinosItemType.movie: true}));
  }
}

class _SeerrUser extends SeerrUser {
  @override
  SeerrUserModel? build() => null;
}

Widget restVisualFixture(
    {required String screen,
    required Size viewport,
    required RootStackRouter router,
    double textScale = 1}) {
  final movies = fixtureMovies();
  final cache = InMemoryPaletteCache();
  for (final movie in movies) {
    cache.write(movie.id, const Color(0xFF245E61).toARGB32());
  }
  return ProviderScope(
      overrides: [
        userProvider.overrideWith(TestUser.new),
        seerrUserProvider.overrideWith(_SeerrUser.new),
        sideBarForceCollapsedProvider.overrideWith((ref) => false),
        paletteServiceProvider.overrideWithValue(PaletteService(cache)),
        librarySearchProvider(_libraryKey)
            .overrideWith((ref) => _Library(ref, movies)),
      ],
      child: MaterialApp(
          locale: const Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: buildAppTheme(heroTint: const Color(0xFF245E61)),
          home: MediaQuery(
              data: MediaQueryData(
                  size: viewport,
                  textScaler: TextScaler.linear(textScale),
                  disableAnimations: true),
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
                          posterDefaults:
                              PosterDefaults(size: 180, ratio: 2 / 3),
                          controller: {},
                          sideBarWidth: 0,
                          topBarHeight: 0,
                          statusBarHeight: 0),
                      child: Scaffold(body: SideNavigationRail(
                          child: Consumer(builder: (context, ref, _) {
                        final padding = EdgeInsets.fromLTRB(
                            AdaptiveLayout.of(context).sideBarWidth + 32,
                            24,
                            32,
                            24);
                        switch (screen) {
                          case 'movie':
                          case 'series-detail':
                          case 'episode-detail':
                            final isEpisode = screen == 'episode-detail';
                            final isSeries = screen == 'series-detail';
                            return MediaDetailScaffold(
                              cinematic: true,
                              seriesLayout: isSeries,
                              item: movies.first,
                              label: movies.first.title,
                              title: isEpisode ? 'L’orage' : movies.first.title,
                              useTitleLogo: !isEpisode,
                              parentLink: isEpisode
                                  ? (label: 'Le Chant du large', onTap: () {})
                                  : null,
                              playLabel: isSeries
                                  ? 'Reprendre S1 · É7'
                                  : isEpisode
                                      ? 'Lire S1 · É2'
                                      : null,
                              backDrops: ImagesData(backDrop: [homeArtwork]),
                              metaLine: isSeries
                                  ? '2025 · 2 saisons · 7,1 · Drame'
                                  : isEpisode
                                      ? 'S1 · É2 · 13 février 2025 · 42 min · 7,1 · Drame'
                                      : '2025 · 2 h 08 · HD SDR · 7,1 · Drame',
                              onPlay: () {},
                              onToggleFavourite: () {},
                              onTogglePlayed: () {},
                              actions: (_) => [],
                              heroContent: MovieHeroContent(
                                  summary:
                                      'Une île, un retour. Et tout ce que la mer n’a pas emporté. Le voyage devient une rencontre avec les souvenirs et les visages du passé.',
                                  streams: MediaStreamsModel(
                                      defaultAudioStreamIndex: 0,
                                      versionStreams: [
                                        VersionStreamModel(
                                            name: 'HD',
                                            index: 0,
                                            defaultAudioStreamIndex: 0,
                                            defaultSubStreamIndex: null,
                                            videoStreams: [],
                                            subStreams: [],
                                            audioStreams: [
                                              AudioStreamModel(
                                                  displayTitle:
                                                      'Français · 5.1',
                                                  name: 'Français',
                                                  codec: 'eac3',
                                                  isDefault: true,
                                                  isExternal: false,
                                                  index: 0,
                                                  language: 'fra',
                                                  channelLayout: '5.1',
                                                  sampleRate: 48000,
                                                  channels: 6,
                                                  bitRate: 640000,
                                                  bitDepth: 24,
                                                  profile: null,
                                                  spatialFormat: null),
                                            ])
                                      ]),
                                  onStreamsChanged: (_) {}),
                              content: (context, inset) => [
                                if (isSeries)
                                  SliverPadding(
                                      padding: const EdgeInsets.only(
                                          top: AppSpacing.md,
                                          bottom: AppSpacing.xl),
                                      sliver: SliverToBoxAdapter(
                                          child: SeasonEpisodeSection(
                                              seriesPresentation: true,
                                              seasons: [
                                                _season('s1', 1,
                                                    episodeCount: 8),
                                                _season('s2', 2,
                                                    episodeCount: 4)
                                              ],
                                              contentPadding: inset))),
                                SliverToBoxAdapter(
                                    child: MediaInfoSection(
                                        cinematic: true,
                                        people: List.generate(
                                            8,
                                            (i) => Person(
                                                id: 'cast-$i',
                                                name: [
                                                  'Camille Moreau',
                                                  'Alexandre Martin',
                                                  'Louise Bernard',
                                                  'Gabriel Laurent',
                                                  'Léa Richard',
                                                  'Arthur Petit'
                                                ][i % 6],
                                                role: 'Personnage $i',
                                                image: homeArtwork)),
                                        info: const [
                                          (
                                            label: 'Réalisation',
                                            value: 'Camille Moreau'
                                          ),
                                          (
                                            label: 'Scénario',
                                            value:
                                                'Alexandre Martin, Louise Bernard'
                                          ),
                                          (
                                            label: 'Sortie',
                                            value: '13 février 2025'
                                          ),
                                          (
                                            label: 'Pays',
                                            value: 'France, Allemagne'
                                          )
                                        ],
                                        contentPadding: inset))
                              ],
                            );
                          case 'detail':
                            return MediaDetailScaffold(
                                item: movies.first,
                                label: movies.first.title,
                                title: movies.first.title,
                                backDrops: ImagesData(backDrop: [homeArtwork]),
                                metaLine: '2025 · Drame · 2 h 08',
                                onPlay: () {},
                                onToggleFavourite: () {},
                                onTogglePlayed: () {},
                                actions: (_) => [],
                                content: (context, inset) => [
                                      SliverPadding(
                                          padding: inset.copyWith(top: 24),
                                          sliver: const SliverToBoxAdapter(
                                              child: MediaSynopsis(
                                                  'Une île, un retour. Et tout ce que la mer n’a pas emporté. '
                                                  'Le voyage devient une rencontre avec les souvenirs et les visages du passé.')))
                                    ]);
                          case 'submenu':
                            return Stack(fit: StackFit.expand, children: [
                              KinosImage(image: homeArtwork, fit: BoxFit.cover),
                              GlassAlertDialog(
                                title: const Text('Trier par'),
                                content: SizedBox(
                                    width: AppDetailLayout.readingWidth,
                                    child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          CheckboxListTile(
                                              value: true,
                                              onChanged: (_) {},
                                              title: const Text('Nom')),
                                          CheckboxListTile(
                                              value: false,
                                              onChanged: (_) {},
                                              title:
                                                  const Text('Date d’ajout')),
                                          CheckboxListTile(
                                              value: false,
                                              onChanged: (_) {},
                                              title: const Text(
                                                  'Note de la communauté')),
                                        ])),
                              ),
                            ]);
                          case 'episodes':
                            return SingleChildScrollView(
                              padding: padding,
                              child: SeasonEpisodeSection(
                                seasons: [
                                  _season('visual-season', 1, episodeCount: 5)
                                ],
                                contentPadding: EdgeInsets.zero,
                              ),
                            );
                          case 'library':
                            return CustomScrollView(slivers: [
                              SliverToBoxAdapter(
                                  child: LibraryAppBar(
                                      toolbarHeight:
                                          AppPageLayout.toolbarHeight,
                                      menuActions: const [],
                                      librarySearchResults: ref.watch(
                                          librarySearchProvider(_libraryKey)),
                                      isEmptySearchScreen: false,
                                      refreshKey:
                                          GlobalKey<RefreshIndicatorState>(),
                                      uniqueKey: _libraryKey,
                                      libraryProvider: ref.read(
                                          librarySearchProvider(_libraryKey)
                                              .notifier),
                                      scrollController: ScrollController())),
                              SliverPadding(
                                  padding: padding.copyWith(top: 0),
                                  sliver: LibraryViews(
                                      key: _libraryKey,
                                      items: movies,
                                      groupByType: GroupBy.none)),
                            ]);
                          case 'settings':
                            return Padding(
                                padding: EdgeInsets.only(
                                    left: AdaptiveLayout.of(context)
                                        .sideBarWidth),
                                child: SettingsScaffold(
                                    label: 'Réglages',
                                    items: settingsListGroup(
                                        context, const Text('Apparence'), [
                                      SettingsListTile(
                                          label: const Text('Apparence'),
                                          subLabel: const Text(
                                              'Navigation, texte et disposition de l’interface.'),
                                          icon: Icons.desktop_windows_outlined,
                                          selected: true,
                                          onTap: () {}),
                                      SettingsListTileCheckbox(
                                          label:
                                              const Text('Navigation déployée'),
                                          subLabel: const Text(
                                              'Afficher les libellés dans la barre latérale.'),
                                          value: false,
                                          onChanged: (_) {}),
                                      SettingsListTileCheckbox(
                                          label: const Text(
                                              'Réduire les animations'),
                                          subLabel: const Text(
                                              'Limiter les mouvements de l’interface.'),
                                          value: true,
                                          onChanged: (_) {}),
                                      SettingsListTile(
                                          label: const Text('Lecture'),
                                          subLabel: const Text(
                                              'Pistes audio, sous-titres et raccourcis clavier.'),
                                          icon: Icons.play_arrow_rounded,
                                          onTap: () {}),
                                      SettingsListTile(
                                          label: const Text('Radarr et Sonarr'),
                                          subLabel: const Text(
                                              'URL, clé API et test de connexion.'),
                                          icon: Icons.cloud_outlined,
                                          onTap: () {}),
                                    ])));
                          case 'requests':
                            final requests = List.generate(
                                3,
                                (i) => SeerrDashboardPosterModel(
                                    id: 'request-$i',
                                    type: SeerrMediaType.movie,
                                    tmdbId: i + 1,
                                    title: movies[i].title,
                                    overview: movies[i].overview.summary,
                                    images: ImagesData(
                                        primary: homeArtwork,
                                        thumb: homeArtwork),
                                    jellyfinItemId: null,
                                    releaseYear: '2025',
                                    requestStatus: i == 0
                                        ? SeerrRequestStatus.pending
                                        : SeerrRequestStatus.approved,
                                    mediaStatus: i == 2
                                        ? SeerrMediaStatus.available
                                        : SeerrMediaStatus.processing));
                            return CustomScrollView(slivers: [
                              SliverPadding(
                                  padding: padding,
                                  sliver: const SliverToBoxAdapter(
                                      child: AppPageHeader(title: 'Seerr'))),
                              SliverPadding(
                                  padding: padding,
                                  sliver: SliverList.builder(
                                    itemCount: requests.length,
                                    itemBuilder: (context, index) =>
                                        SeerrRequestBannerCard(
                                            poster: requests[index],
                                            compact: true),
                                  )),
                            ]);
                          default:
                            return SingleChildScrollView(
                                padding: padding,
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const AppPageHeader(title: 'Arr'),
                                      const SizedBox(height: 24),
                                      Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            FilterButton(
                                                isSelected: false,
                                                label:
                                                    const Text('Bibliothèque'),
                                                onPressed: () {}),
                                            FilterButton(
                                                isSelected: true,
                                                label: const Text(
                                                    'File d’attente'),
                                                onPressed: () {}),
                                            FilterButton(
                                                isSelected: false,
                                                label: const Text('Calendrier'),
                                                onPressed: () {}),
                                          ]),
                                      const SizedBox(height: 24),
                                      ArrQueueTable(
                                          instanceLabel: 'Radarr',
                                          downloadClientReady: true,
                                          onPause: (_) {},
                                          onResume: (_) {},
                                          onForceImport: (_) {},
                                          onRemove: (_,
                                              {required removeFromClient,
                                              required blocklist}) {},
                                          items: List.generate(
                                              3,
                                              (i) => ArrQueueItem(
                                                  id: i,
                                                  title: movies[i].title,
                                                  size: 10000000000,
                                                  sizeLeft: 4000000000,
                                                  timeLeft: '00:12:00',
                                                  indexer: 'Indexeur',
                                                  qualityName: '1080p',
                                                  customFormatScore: 0,
                                                  status: ArrQueueStatus
                                                      .downloading,
                                                  statusMessages: const [],
                                                  errorMessage: null,
                                                  protocol: 'torrent',
                                                  downloadId: 'download-$i',
                                                  seasonNumber: null))),
                                    ]));
                        }
                      }))))))));
}

EpisodeModel _episode(int number, {Duration? runTime}) {
  return EpisodeModel(
    seriesName: 'Série de test',
    season: 1,
    episode: number,
    episodeEnd: null,
    name: 'Un titre d\'épisode assez long pour occuper toute la largeur '
        'de la cellule $number',
    id: 'ep-$number',
    overview: OverviewModel(runTime: runTime),
    parentId: 'season-1',
    playlistId: null,
    images: ImagesData(primary: homeArtwork, thumb: homeArtwork),
    childCount: null,
    primaryRatio: null,
    userData: const UserData(),
    parentImages: null,
    mediaStreams: MediaStreamsModel(versionStreams: const []),
  );
}

SeasonModel _season(String id, int number, {required int episodeCount}) {
  final episodes = [
    for (var i = 1; i <= episodeCount; i++)
      // Alterne avec/sans durée : la ligne de durée est optionnelle par
      // épisode, mais la hauteur de rangée est partagée par toute la
      // grille — doit rester correcte dans les deux cas.
      _episode(i, runTime: i.isEven ? const Duration(minutes: 42) : null),
  ];
  return SeasonModel(
    parentImages: null,
    seasonName: 'Saison $number',
    episodes: episodes,
    episodeCount: episodeCount,
    seriesId: 'series-1',
    season: number,
    seriesName: 'Série de test',
    name: 'Saison $number',
    id: id,
    overview: const OverviewModel(),
    parentId: 'series-1',
    playlistId: null,
    images: ImagesData(primary: homeArtwork, thumb: homeArtwork),
    childCount: episodeCount,
    primaryRatio: null,
    userData: const UserData(),
    canDelete: false,
    canDownload: false,
  );
}
