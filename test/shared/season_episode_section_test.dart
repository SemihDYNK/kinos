import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kinos/l10n/generated/app_localizations.dart';
import 'package:kinos/localization_delegates.dart';
import 'package:kinos/models/items/episode_model.dart';
import 'package:kinos/models/items/item_shared_models.dart';
import 'package:kinos/models/items/media_streams_model.dart';
import 'package:kinos/models/items/overview_model.dart';
import 'package:kinos/models/items/season_model.dart';
import 'package:kinos/screens/shared/media/season_episode_section.dart';
import 'package:kinos/theme/app_theme.dart';

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
    images: null,
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
    images: null,
    childCount: episodeCount,
    primaryRatio: null,
    userData: const UserData(),
    canDelete: false,
    canDownload: false,
  );
}

Widget _harness({required List<SeasonModel> seasons, required double width}) {
  return MaterialApp(
    theme: buildAppTheme(),
    localizationsDelegates: KinosLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MediaQuery(
      data: MediaQueryData(size: Size(width, 2000)),
      child: Scaffold(
        body: SingleChildScrollView(
          child: SeasonEpisodeSection(
            seasons: seasons,
            contentPadding: const EdgeInsets.symmetric(horizontal: 24),
          ),
        ),
      ),
    ),
  );
}

void main() {
  for (final width in [900.0, 1280.0, 1920.0]) {
    testWidgets(
        'une seule saison, largeur $width : aucun débordement de la grille '
        'd\'épisodes', (tester) async {
      await tester.pumpWidget(_harness(
        seasons: [_season('s1', 1, episodeCount: 8)],
        width: width,
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Sans sélecteur de saison (une seule saison) : le libellé "N.
      // Titre" du premier épisode est directement visible.
      expect(find.textContaining('1. Un titre'), findsOneWidget);
    });

    testWidgets(
        'plusieurs saisons, largeur $width : aucun débordement de la '
        'grille d\'épisodes', (tester) async {
      await tester.pumpWidget(_harness(
        seasons: [
          _season('s1', 1, episodeCount: 8),
          _season('s2', 2, episodeCount: 6),
        ],
        width: width,
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  }
}
