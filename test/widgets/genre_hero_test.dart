import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/screens/dashboard/genre_hero.dart';
import 'package:kinos/theme/app_theme.dart';

const _tag = ('genre-image', 'movie', null, 'Action');
const _titleTag = ('genre-title', 'movie', null, 'Action');

Widget _app() => MaterialApp(
      theme: buildAppTheme(density: AppDensity.desk),
      home: Builder(
        builder: (context) => Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: GestureDetector(
              onTap: () => Navigator.of(context).push(PageRouteBuilder<void>(
                  transitionDuration: const Duration(milliseconds: 400),
                  reverseTransitionDuration: const Duration(milliseconds: 400),
                  pageBuilder: (_, __, ___) => Scaffold(
                        body: Column(children: [
                          SizedBox(
                              height: 400,
                              width: 800,
                              child: genreBackdropHero(context,
                                  tag: _tag, image: null, mix: 1)),
                          genreTitleHero(context,
                              tag: _titleTag, label: 'Action', big: true),
                        ]),
                      ))),
              child: SizedBox(
                width: 200,
                height: 110,
                child: Stack(children: [
                  genreBackdropHero(context, tag: _tag, image: null, mix: 0),
                  Center(
                      child: genreTitleHero(context,
                          tag: _titleTag, label: 'Action', big: false)),
                ]),
              ),
            ),
          ),
        ),
      ),
    );

void main() {
  /// Voiles (mix) des fonds visibles à l'instant.
  List<double> mixes(WidgetTester tester) => tester
      .widgetList<GenreBackdrop>(find.byType(GenreBackdrop))
      .map((b) => b.mix)
      .toList();

  testWidgets('the tile image flies up into the banner, and back',
      (tester) async {
    await tester.pumpWidget(_app());
    expect(mixes(tester), [0.0]);

    await tester.tap(find.byType(GestureDetector).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    final during = mixes(tester);
    expect(during.any((m) => m > 0 && m < 1), isTrue,
        reason: 'the flying backdrop is between tile (0) and banner (1)');

    await tester.pumpAndSettle();
    expect(mixes(tester).where((m) => m == 1), isNotEmpty);
    expect(find.text('Action'), findsOneWidget);

    // Retour : le bandeau redescend vers la tuile.
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(mixes(tester).any((m) => m > 0 && m < 1), isTrue,
        reason: 'the way back flies too');
    await tester.pumpAndSettle();
    expect(mixes(tester), [0.0]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no flight without motion', (tester) async {
    await tester.pumpWidget(MediaQuery(
        data: const MediaQueryData(disableAnimations: true), child: _app()));
    await tester.tap(find.byType(GestureDetector).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(Hero), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
