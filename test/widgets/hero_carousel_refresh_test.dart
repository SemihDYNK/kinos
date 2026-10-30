import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/jellyfin/jellyfin_open_api.swagger.dart';
import 'package:kinos/models/items/movie_model.dart';
import 'package:kinos/screens/dashboard/hero_carousel.dart';
import 'seerr_discovery_section_test.dart' show shell;

void main() {
  testWidgets('refreshed hero reports its item outside the parent build',
      (tester) async {
    final first = MovieModel.fromBaseDto(
        const BaseItemDto(id: 'a', name: 'Premier'), null);
    final second = MovieModel.fromBaseDto(
        const BaseItemDto(id: 'b', name: 'Deuxième'), null);
    var current = first;
    String? reported;
    late StateSetter update;
    await tester.pumpWidget(ProviderScope(child: StatefulBuilder(
      builder: (context, setState) {
        update = setState;
        return shell(SliverToBoxAdapter(
            child: HeroCarousel(
          items: [current],
          onCurrentChanged: (item) => setState(() => reported = item.id),
        )));
      },
    )));
    await tester.pump();
    expect(reported, 'a');
    update(() => current = second);
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(reported, 'b');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
