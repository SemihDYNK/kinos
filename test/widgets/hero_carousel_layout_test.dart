import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/jellyfin/jellyfin_open_api.swagger.dart';
import 'package:kinos/models/items/movie_model.dart';
import 'package:kinos/screens/dashboard/hero_carousel.dart';
import 'package:kinos/theme/app_theme.dart';
import 'seerr_discovery_section_test.dart' show shell;

void main() {
  testWidgets('hero actions remain reachable without changing the slide',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final movies = [
      MovieModel.fromBaseDto(const BaseItemDto(id: 'a', name: 'Premier'), null),
      MovieModel.fromBaseDto(
          const BaseItemDto(id: 'b', name: 'Deuxième'), null),
    ];
    String? current;
    var afterActivated = false;
    await tester.pumpWidget(ProviderScope(
        child: shell(SliverMainAxisGroup(slivers: [
      SliverToBoxAdapter(
          child: HeroCarousel(
              items: movies, onCurrentChanged: (item) => current = item.id)),
      SliverToBoxAdapter(
          child: FocusRing(
              onActivate: () => afterActivated = true,
              child:
                  const SizedBox(height: 48, child: Text('Après le bandeau')))),
    ]))));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(current, 'a',
        reason: 'Moving between actions must not turn the page');
    final focusedInfo = find.ancestor(
        of: find.byIcon(Icons.info_outline), matching: find.byType(FocusRing));
    expect(focusedInfo, findsOneWidget);
    var reached = false;
    FocusManager.instance.primaryFocus!.context!
        .visitAncestorElements((element) {
      if (element == tester.element(focusedInfo)) reached = true;
      return true;
    });
    expect(reached, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(current, 'b',
        reason: 'Previous slide remains reachable from the action row');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(current, 'a', reason: 'Next slide remains reachable');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(afterActivated, isTrue,
        reason: 'Focus can leave the hero downwards');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('long accented title leaves actions reachable at 150 percent',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const title =
        'Éternels voyages à travers les océans et les montagnes oubliées';
    final movie = MovieModel.fromBaseDto(
        const BaseItemDto(
            id: 'long',
            name: title,
            overview:
                'Un voyage à travers les paysages, les souvenirs et les retrouvailles.'),
        null);
    await tester.pumpWidget(ProviderScope(
        child: shell(SliverToBoxAdapter(child: HeroCarousel(items: [movie])),
            textScale: 1.5)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text(movie.overview.summary), findsOneWidget);
    final hero = tester.getRect(find.byType(HeroCarousel));
    final play = tester
        .getRect(find.byWidgetPredicate((widget) => widget is FilledButton));
    expect(hero.contains(play.bottomRight), isTrue);
    expect(hero.contains(play.topLeft), isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
