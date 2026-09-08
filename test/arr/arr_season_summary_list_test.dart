import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kinos/arr/models/arr_media_detail.dart';
import 'package:kinos/arr/screens/widgets/arr_season_summary_list.dart';

void main() {
  testWidgets('renders seasons sorted, with episode counts and monitoring',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: ArrSeasonSummaryList(seasons: [
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
        ]),
      ),
    ));

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
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: ArrSeasonSummaryList(seasons: [
          ArrSeasonSummary(
              seasonNumber: 0,
              monitored: false,
              episodeCount: 2,
              episodeFileCount: 1),
        ]),
      ),
    ));

    expect(find.text('Épisodes spéciaux'), findsOneWidget);
  });

  testWidgets('empty list renders nothing', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: ArrSeasonSummaryList(seasons: [])),
    ));

    expect(find.byType(ArrSeasonSummaryList), findsOneWidget);
    expect(find.text('Saison 1'), findsNothing);
  });
}
