import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kinos/arr/models/arr_library_item.dart';
import 'package:kinos/arr/models/arr_media_detail.dart';
import 'package:kinos/arr/screens/widgets/arr_season_summary_list.dart';

Widget _harness({
  required List<ArrSeasonSummary> seasons,
  List<ArrEpisode> episodes = const [],
  void Function(int)? onInteractiveSearchSeason,
  void Function(int)? onAutoSearchSeason,
  void Function(ArrEpisode)? onInteractiveSearchEpisode,
  void Function(ArrEpisode)? onAutoSearchEpisode,
}) {
  return MaterialApp(
    home: Scaffold(
      body: ArrSeasonSummaryList(
        seasons: seasons,
        episodes: episodes,
        onInteractiveSearchSeason: onInteractiveSearchSeason ?? (_) {},
        onAutoSearchSeason: onAutoSearchSeason ?? (_) {},
        onInteractiveSearchEpisode: onInteractiveSearchEpisode ?? (_) {},
        onAutoSearchEpisode: onAutoSearchEpisode ?? (_) {},
      ),
    ),
  );
}

void main() {
  testWidgets('renders seasons sorted, with episode counts and monitoring',
      (tester) async {
    await tester.pumpWidget(_harness(seasons: const [
      ArrSeasonSummary(
          seasonNumber: 2,
          monitored: false,
          episodeCount: 10,
          episodeFileCount: 0),
      ArrSeasonSummary(
          seasonNumber: 1,
          monitored: true,
          episodeCount: 9,
          episodeFileCount: 9),
    ]));

    // Triées : Saison 1 doit apparaître avant Saison 2 dans l'arbre.
    final season1 = tester.getTopLeft(find.text('Saison 1'));
    final season2 = tester.getTopLeft(find.text('Saison 2'));
    expect(season1.dy, lessThan(season2.dy));

    expect(find.text('9/9 épisodes'), findsOneWidget);
    expect(find.text('0/10 épisodes'), findsOneWidget);
    expect(find.text('Surveillé'), findsOneWidget);
    expect(find.text('Non surveillé'), findsOneWidget);
  });

  testWidgets('season 0 reads as "Épisodes spéciaux"', (tester) async {
    await tester.pumpWidget(_harness(seasons: const [
      ArrSeasonSummary(
          seasonNumber: 0,
          monitored: false,
          episodeCount: 2,
          episodeFileCount: 1),
    ]));

    expect(find.text('Épisodes spéciaux'), findsOneWidget);
  });

  testWidgets('empty list renders nothing', (tester) async {
    await tester.pumpWidget(_harness(seasons: const []));

    expect(find.byType(ArrSeasonSummaryList), findsOneWidget);
    expect(find.text('Saison 1'), findsNothing);
  });

  testWidgets('collapsed by default — episode rows not shown until expanded',
      (tester) async {
    await tester.pumpWidget(_harness(
      seasons: const [
        ArrSeasonSummary(
            seasonNumber: 1,
            monitored: true,
            episodeCount: 1,
            episodeFileCount: 1),
      ],
      episodes: const [
        ArrEpisode(
            id: 1,
            seriesId: 1,
            seasonNumber: 1,
            episodeNumber: 1,
            title: 'Pilote',
            episodeFileId: 5),
      ],
    ));

    expect(find.text('Pilote'), findsNothing);

    await tester.tap(find.text('Saison 1'));
    await tester.pumpAndSettle();

    expect(find.text('Pilote'), findsOneWidget);
    expect(find.text('Présent'), findsOneWidget);
  });

  testWidgets(
      'right arrow / enter expands the focused season, left arrow collapses it',
      (tester) async {
    await tester.pumpWidget(_harness(
      seasons: const [
        ArrSeasonSummary(
            seasonNumber: 1,
            monitored: true,
            episodeCount: 1,
            episodeFileCount: 0),
      ],
      episodes: const [
        ArrEpisode(
            id: 1,
            seriesId: 1,
            seasonNumber: 1,
            episodeNumber: 1,
            title: 'Pilote'),
      ],
    ));

    final focusNode = tester
        .widgetList<Focus>(find.byType(Focus))
        .map((f) => f.focusNode)
        .whereType<FocusNode>()
        .firstWhere((n) => n.debugLabel == 'ArrSeasonSummaryList');
    focusNode.requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.text('Pilote'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(find.text('Pilote'), findsNothing);
  });

  testWidgets('season header context menu triggers season-scoped callbacks',
      (tester) async {
    int? interactiveSeason;
    await tester.pumpWidget(_harness(
      seasons: const [
        ArrSeasonSummary(
            seasonNumber: 3,
            monitored: true,
            episodeCount: 1,
            episodeFileCount: 0),
      ],
      onInteractiveSearchSeason: (n) => interactiveSeason = n,
    ));

    await tester.tap(find.text('Saison 3'), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Recherche interactive'));
    await tester.pumpAndSettle();

    expect(interactiveSeason, 3);
  });
}
