import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/letterboxd/letterboxd_model.dart';
import 'package:kinos/letterboxd/letterboxd_providers.dart';
import 'package:kinos/recommendations/providers/home_catalog_providers.dart';
import 'package:kinos/recommendations/providers/recommendation_providers.dart';

void main() {
  for (final inventory in [true, false]) {
    testWidgets(
        'async home dependencies settle without recreating registry, inventory=$inventory',
        (tester) async {
      var registryStarts = 0;
      final registryIds = StateProvider<List<String>>((ref) => const []);
      final container = ProviderContainer(overrides: [
        letterboxdSnapshotProvider
            .overrideWithValue(const AsyncData(LetterboxdSnapshot())),
        playedItemsProvider.overrideWith((ref) async => []),
        resumableItemsProvider.overrideWith((ref) async => []),
        unwatchedLibraryProvider.overrideWith((ref) async => []),
        recommendationRegistrySeedProvider.overrideWith((ref) async {
          registryStarts++;
          return (
            forYouIds: ref.watch(registryIds),
            arrOnlyIds: const <String>[]
          );
        }),
      ]);
      try {
        await tester.pumpWidget(UncontrolledProviderScope(
            container: container,
            child: Consumer(builder: (context, ref, child) {
              if (inventory) {
                ref.watch(homeCatalogInventoryResultProvider);
              } else {
                ref.watch(homeSeedRowsResultProvider);
              }
              return const SizedBox();
            })));
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(registryStarts, lessThan(5));
        final settled = registryStarts;
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(registryStarts, settled);
        container.read(registryIds.notifier).state = ['fresh'];
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(registryStarts, settled + 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      } finally {
        container.dispose();
      }
    });
  }
}
