import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kinos/screens/shared/input_fields.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/adaptive_layout/adaptive_layout.dart';
import 'package:kinos/util/adaptive_layout/adaptive_layout_model.dart';
import 'package:kinos/util/poster_defaults.dart';

const _layout = AdaptiveLayoutModel(
  viewSize: ViewSize.desktop,
  layoutMode: LayoutMode.single,
  inputDevice: InputDevice.pointer,
  platform: TargetPlatform.linux,
  isDesktop: true,
  posterDefaults: PosterDefaults(size: 150, ratio: 1.5),
  controller: {},
  sideBarWidth: 0,
  topBarHeight: 0,
  statusBarHeight: 0,
);

void main() {
  Future<List<int?>> pump(WidgetTester tester) async {
    final submitted = <int?>[];
    await tester.pumpWidget(ProviderScope(
      child: AdaptiveLayout(
        data: _layout,
        child: MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: Column(children: [
              IntInputField(
                value: 10,
                suffix: 'Secondes',
                onSubmitted: submitted.add,
              ),
              const TextField(key: Key('other')),
            ]),
          ),
        ),
      ),
    ));
    return submitted;
  }

  testWidgets('la saisie reste visible à côté de l\'unité', (tester) async {
    await pump(tester);
    final field = find.byType(EditableText).first;
    expect(tester.getSize(field).width, greaterThan(24));
    expect(find.text('10'), findsOneWidget);
    expect(find.text('Secondes'), findsOneWidget);

    await tester.enterText(field, '30');
    await tester.pump();
    expect(find.text('30'), findsOneWidget);
  });

  testWidgets('la valeur est enregistrée quand le champ perd le focus',
      (tester) async {
    final submitted = await pump(tester);
    await tester.enterText(find.byType(EditableText).first, '25');
    await tester.tap(find.byKey(const Key('other')));
    await tester.pump();
    expect(submitted, [25]);
  });
}
