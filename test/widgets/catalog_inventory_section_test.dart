import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/jellyfin/jellyfin_open_api.swagger.dart';
import 'package:kinos/models/item_base_model.dart';
import 'package:kinos/models/items/movie_model.dart';
import 'package:kinos/models/items/series_model.dart';
import 'package:kinos/recommendations/providers/home_catalog_providers.dart';
import 'package:kinos/screens/dashboard/catalog_inventory_section.dart';
import 'seerr_discovery_section_test.dart' show shell;

void main() {
  for (final type in [KinosItemType.movie, KinosItemType.series]) {
    testWidgets(
        'catalog categories isolate $type and share their heading style',
        (tester) async {
      final movie = MovieModel.fromBaseDto(
          const BaseItemDto(
              id: 'movie', name: 'Un film', type: BaseItemKind.movie),
          null);
      final series = SeriesModel.fromBaseDto(
          const BaseItemDto(
              id: 'series', name: 'Une série', type: BaseItemKind.series),
          null);
      await tester.pumpWidget(ProviderScope(
          overrides: [
            homeCatalogInventoryResultProvider.overrideWith((ref) async => (
                  wellRatedMovies: <ItemBaseModel>[movie],
                  wellRatedSeries: <ItemBaseModel>[series],
                  narrowGenres: {
                    'Action': <ItemBaseModel>[movie, series],
                    'Films seuls': <ItemBaseModel>[movie]
                  },
                  decades: {
                    1990: <ItemBaseModel>[movie, series]
                  },
                  longFilms: <ItemBaseModel>[movie],
                  isComplete: true,
                )),
          ],
          child: shell(CatalogInventorySection(
              mediaType: type, contentPadding: EdgeInsets.zero))));
      await tester.pumpAndSettle();
      expect(find.text('Action'), findsOneWidget);
      expect(find.text(type == KinosItemType.movie ? 'Une série' : 'Un film'),
          findsNothing);
      expect(
          find.text(type == KinosItemType.movie
              ? 'Films bien notés'
              : 'Séries bien notées'),
          findsOneWidget);
      final heading = tester.widget<Text>(find.text('Action'));
      expect(
          heading.style,
          Theme.of(tester.element(find.text('Action')))
              .textTheme
              .headlineMedium);
      if (type == KinosItemType.series) {
        expect(find.text('Films seuls'), findsNothing);
        expect(find.text('Plus de 2h30'), findsNothing);
      }
      await tester.scrollUntilVisible(find.text('Les 1990s'), 300,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('Les 1990s'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
