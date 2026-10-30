import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/jellyfin/jellyfin_open_api.swagger.dart';
import 'package:kinos/models/items/movie_model.dart';
import 'package:kinos/models/library_search/library_search_options.dart';
import 'package:kinos/screens/library_search/widgets/library_views.dart';
import 'package:kinos/screens/shared/media/components/poster_image.dart';
import 'seerr_discovery_section_test.dart' show shell;

void main() {
  testWidgets('library grid uses local desktop width and portrait images',
      (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final movies = List.generate(
        8,
        (i) => MovieModel.fromBaseDto(
            BaseItemDto(
                id: 'film-$i', name: 'Le film $i', productionYear: 2025),
            null));
    await tester.pumpWidget(ProviderScope(
        child: shell(SliverPadding(
            padding: const EdgeInsets.only(left: 264, right: 32),
            sliver: LibraryViews(
                key: const ValueKey('library-design'),
                items: movies,
                groupByType: GroupBy.none)))));
    await tester.pumpAndSettle();
    final images = find.byType(PosterImage);
    final first = tester.getRect(images.first);
    expect(first.width / first.height, closeTo(2 / 3, .01));
    final firstRow = images
        .evaluate()
        .where((e) =>
            tester
                .getRect(find.byElementPredicate((candidate) => candidate == e))
                .top ==
            first.top)
        .length;
    expect(firstRow, inInclusiveRange(6, 8));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
