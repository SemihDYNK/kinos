import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kinos/theme/app_theme.dart';

void main() {
  Future<List<int>> pump(WidgetTester tester, {bool reduced = false}) async {
    final taps = <int>[];
    await tester.pumpWidget(MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: MaterialApp(
        theme: buildAppTheme(),
        home: Center(
          child: SizedBox(
            width: 120,
            height: 180,
            child: FocusRing(
              onActivate: () => taps.add(1),
              posterMotion: true,
              child: const ColoredBox(color: AppColors.surface),
            ),
          ),
        ),
      ),
    ));
    return taps;
  }

  double scale(WidgetTester tester) => tester
      .widget<ScaleTransition>(find.descendant(
          of: find.byType(PressBounce), matching: find.byType(ScaleTransition)))
      .scale
      .value;

  testWidgets(
      'la tuile s\'enfonce et l\'action part de la taille enfoncée, '
      'sans rebond ni attente au relâchement', (tester) async {
    final taps = await pump(tester);
    final gesture =
        await tester.startGesture(tester.getCenter(find.byType(FocusRing)));
    await tester.pump();
    await tester.pump(AppDurations.pressIn);
    expect(scale(tester), closeTo(AppMotion.pressScale, .005));

    await gesture.up();
    await tester.pump();
    expect(taps, [1], reason: 'déjà enfoncée : la page part au relâchement');
    expect(scale(tester), closeTo(AppMotion.pressScale, .005),
        reason: 'la transition doit mesurer la tuile enfoncée');

    await tester.pumpAndSettle();
    expect(scale(tester), 1);
    expect(taps, [1]);
  });

  testWidgets('un clic bref termine l\'enfoncement avant l\'action',
      (tester) async {
    final taps = await pump(tester);
    await tester.tap(find.byType(FocusRing));
    await tester.pump();
    expect(taps, isEmpty);
    await tester.pump(AppDurations.pressIn);
    await tester.pump(const Duration(milliseconds: 1));
    expect(taps, [1]);
    await tester.pumpAndSettle();
    expect(scale(tester), 1);
  });

  testWidgets('sans animation, l\'action part tout de suite', (tester) async {
    final taps = await pump(tester, reduced: true);
    await tester.tap(find.byType(FocusRing));
    await tester.pump();
    expect(taps, [1]);
  });
}
