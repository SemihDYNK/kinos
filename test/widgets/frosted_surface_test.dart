import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/adaptive_layout/adaptive_layout.dart';
import 'package:kinos/util/adaptive_layout/adaptive_layout_model.dart';
import 'package:kinos/util/poster_defaults.dart';
import 'package:kinos/theme/app_icons.dart';
import 'package:kinos/widgets/shared/item_actions.dart';
import 'package:kinos/widgets/shared/frosted_surface.dart';

void main() {
  testWidgets('dialogs clip blur to the panel and preserve dismissal',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(),
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) => const GlassAlertDialog(
                            title: Text('Trier par'), content: Text('Nom'))),
                    child: const Text('Ouvrir'))))));
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
    expect(find.byType(FrostedSurface), findsOneWidget);
    expect(
        find.descendant(
            of: find.byType(ClipRRect), matching: find.byType(BackdropFilter)),
        findsOneWidget);
    expect(tester.getSize(find.byType(BackdropFilter)).width, lessThan(800));
    expect(tester.takeException(), isNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(FrostedSurface), findsNothing);
  });
  testWidgets('glass menu keeps keyboard selection and route result',
      (tester) async {
    String? result;
    await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
            body: GlassPopupMenuButton<String>(
          tooltip: 'Actions',
          onSelected: (value) => result = value,
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'one', child: Text('Première')),
            PopupMenuItem(value: 'two', child: Text('Deuxième'))
          ],
        ))));
    await tester.tap(find.byTooltip('Actions'));
    await tester.pumpAndSettle();
    expect(find.byType(FrostedSurface), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    expect(find.byType(FrostedSurface), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('high contrast uses an opaque panel without blur',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: MediaQuery(
            data: MediaQueryData(highContrast: true),
            child: FrostedSurface(child: Text('Menu')))));
    expect(find.byType(BackdropFilter), findsNothing);
    final decoration = tester
        .widget<DecoratedBox>(find.byType(DecoratedBox))
        .decoration as BoxDecoration;
    expect(decoration.color, AppColors.surfaceHigh);
  });
  testWidgets('selected context action retains its check beside an icon',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
            body: GlassPopupMenuButton<void>(
                tooltip: 'Choix',
                itemBuilder: (_) => [
                      ItemActionButton(
                              selected: true,
                              icon: const Icon(AppIcons.audio),
                              label: const Text('Français'),
                              action: () {})
                          .toPopupMenuItem(useIcons: true),
                    ]))));
    await tester.tap(find.byTooltip('Choix'));
    await tester.pumpAndSettle();
    expect(find.byIcon(AppIcons.watched), findsOneWidget);
  });
  testWidgets('disabled sheet action cannot dismiss its dialog',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(),
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    child: const Text('Ouvrir'),
                    onPressed: () => showDialog<void>(
                        context: context,
                        builder: (context) => AdaptiveLayout(
                            data: const AdaptiveLayoutModel(
                                viewSize: ViewSize.desktop,
                                layoutMode: LayoutMode.single,
                                inputDevice: InputDevice.pointer,
                                platform: TargetPlatform.linux,
                                isDesktop: true,
                                posterDefaults:
                                    PosterDefaults(size: 180, ratio: 2 / 3),
                                controller: {},
                                sideBarWidth: 0,
                                topBarHeight: 0,
                                statusBarHeight: 0),
                            child: Builder(
                                builder: (context) => GlassDialog(
                                    child: ItemActionButton(
                                            label: const Text('Indisponible'))
                                        .toListItem(context))))))))));
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Indisponible'));
    await tester.pumpAndSettle();
    expect(find.byType(GlassDialog), findsOneWidget);
  });
}
