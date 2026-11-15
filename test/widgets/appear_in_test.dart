import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/widgets/shared/appear_in.dart';

void main() {
  double opacity(WidgetTester tester) => tester
      .widget<Opacity>(find.descendant(
          of: find.byType(AppearIn), matching: find.byType(Opacity)))
      .opacity;

  testWidgets('an element arriving after the page fades in', (tester) async {
    final late = ValueNotifier(false);
    addTearDown(late.dispose);
    await tester.pumpWidget(MaterialApp(
      home: ValueListenableBuilder<bool>(
        valueListenable: late,
        builder: (_, value, __) => value
            ? const AppearIn(child: Text('amis'))
            : const SizedBox.shrink(),
      ),
    ));
    await tester.pumpAndSettle();
    late.value = true;
    await tester.pump();
    await tester.pump();
    expect(opacity(tester), lessThan(.05));
    await tester.pump(AppDurations.unroll ~/ 2);
    expect(opacity(tester), allOf(greaterThan(0), lessThan(1)));
    await tester.pumpAndSettle();
    expect(opacity(tester), 1);
  });

  testWidgets('an element already there when the page opens shows at once',
      (tester) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
        MaterialApp(navigatorKey: navigator, home: const SizedBox.shrink()));
    navigator.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const AppearIn(child: Text('titre'))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    // En pleine transition d'ouverture : déjà opaque, pas de second fondu.
    expect(
        ModalRoute.of(tester.element(find.byType(AppearIn)))!
            .animation!
            .isCompleted,
        isFalse);
    expect(opacity(tester), 1);
    await tester.pumpAndSettle();
  });

  testWidgets('SmoothSize follows size changes with or without motion',
      (tester) async {
    for (final reduced in [false, true]) {
      final big = ValueNotifier(false);
      await tester.pumpWidget(MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: ValueListenableBuilder<bool>(
              valueListenable: big,
              builder: (_, value, __) => SmoothSize(
                  child: SizedBox(width: 100, height: value ? 200 : 100)),
            ),
          ),
        ),
      ));
      big.value = true;
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(SmoothSize)), const Size(100, 200));
      expect(tester.takeException(), isNull);
      big.dispose();
    }
  });
}
