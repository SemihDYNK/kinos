import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/letterboxd/letterboxd_model.dart';
import 'package:kinos/letterboxd/letterboxd_providers.dart';
import 'package:kinos/models/settings/home_row_model.dart';
import 'package:kinos/providers/database_provider.dart';
import 'package:kinos/recommendations/providers/recommendation_providers.dart';
import 'package:kinos/screens/dashboard/recommendation_row_section.dart';

void main() {
  for (final failed in [false, true]) {
    testWidgets(
        'obsolete cache stays hidden after Letterboxd import, failed=$failed',
        (tester) async {
      var cacheReads = 0;
      final pending = Completer<RecommendationResult>();
      await tester.pumpWidget(ProviderScope(
          overrides: [
            letterboxdSnapshotProvider
                .overrideWithValue(const AsyncData(LetterboxdSnapshot(records: [
              LetterboxdRecord(
                  LetterboxdFilm(
                      uri: 'https://boxd.it/a',
                      title: 'English title',
                      year: 2000),
                  work: LetterboxdWork(
                      title: 'English title',
                      year: 2000,
                      tmdbId: 1,
                      traits: [])),
            ]))),
            recommendationRecomputeNeededProvider
                .overrideWith((ref) async => true),
            recommendationResultProvider.overrideWith((ref) async {
              if (failed) throw StateError('offline');
              return pending.future;
            }),
            appDatabaseProvider.overrideWith((ref) {
              cacheReads++;
              throw StateError('old cache must not be read');
            }),
          ],
          child: const MaterialApp(
              home: Scaffold(
                  body: CustomScrollView(slivers: [
            ForYouRowSection(
                row: HomeRowModel(
                    id: 'for-you',
                    type: HomeRowType.forYou,
                    title: 'Pour vous',
                    order: 0),
                contentPadding: EdgeInsets.zero),
          ])))));
      await tester.pump();
      await tester.pump();
      expect(cacheReads, 0);
      expect(find.text('Pour vous'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
