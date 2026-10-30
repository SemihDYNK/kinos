import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/widgets/shared/page_motion.dart';

void main() {
  testWidgets('page motion is interruptible and reduced motion snaps',
      (tester) async {
    var index = 0;
    var disabled = false;
    late StateSetter update;
    await tester.pumpWidget(
        MaterialApp(home: StatefulBuilder(builder: (context, setState) {
      update = setState;
      return MediaQuery(
          data: MediaQueryData(disableAnimations: disabled),
          child: CatalogPageMotion(index: index, child: Text('page $index')));
    })));
    update(() => index = 1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    expect(
        tester
            .widget<Opacity>(find.byKey(const ValueKey('catalog-page-opacity')))
            .opacity,
        lessThan(1));
    final beforeInterrupt = tester
        .widget<Opacity>(find.byKey(const ValueKey('catalog-page-opacity')))
        .opacity;
    update(() => index = 2);
    await tester.pump();
    expect(
        tester
            .widget<Opacity>(find.byKey(const ValueKey('catalog-page-opacity')))
            .opacity,
        greaterThanOrEqualTo(beforeInterrupt));
    update(() => disabled = true);
    await tester.pump();
    expect(
        tester
            .widget<Opacity>(find.byKey(const ValueKey('catalog-page-opacity')))
            .opacity,
        1);
    await tester.pumpAndSettle();
    expect(find.text('page 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
