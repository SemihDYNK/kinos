import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kinos/screens/shared/outlined_text_field.dart';
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
  testWidgets('a reused field writes to its new controller', (tester) async {
    final first = TextEditingController();
    final second = TextEditingController();
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    Widget app(TextEditingController controller) => ProviderScope(
          child: AdaptiveLayout(
            data: _layout,
            child: MaterialApp(
              theme: buildAppTheme(),
              home: Scaffold(
                  body: OutlinedTextField(
                      controller: controller, label: 'E-mail')),
            ),
          ),
        );
    await tester.pumpWidget(app(first));
    // Comme un onglet qui en remplace un autre : même place, autre contrôleur.
    await tester.pumpWidget(app(second));
    await tester.enterText(find.byType(TextField), 'a@b.c');
    expect(second.text, 'a@b.c');
    expect(first.text, isEmpty);
  });
}
