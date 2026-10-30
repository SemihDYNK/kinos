import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/arr/models/arr_library_entry.dart';
import 'package:kinos/arr/models/arr_library_item.dart';
import 'package:kinos/arr/screens/widgets/arr_library_grid.dart';
import 'package:kinos/screens/settings/settings_list_tile.dart';
import 'package:kinos/theme/app_theme.dart';

void main() {
  testWidgets('setting toggle responds once to pointer and keyboard',
      (tester) async {
    var value = false;
    var changes = 0;
    await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
            body: StatefulBuilder(
                builder: (context, update) => SettingsListTileCheckbox(
                    label: const Text('Option'),
                    value: value,
                    onChanged: (next) => update(() {
                          value = next!;
                          changes++;
                        }))))));
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(value, isTrue);
    expect(changes, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(value, isFalse);
    expect(changes, 2);
  });
  testWidgets('Arr posters expose metadata and keyboard opens the next entry',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final entries = List.generate(
        48,
        (i) => ArrLibraryEntry.movie(ArrMovie(
            id: i,
            title: 'Film $i',
            year: 2024,
            posterUrl: null,
            monitored: true,
            hasFile: false,
            qualityName: null,
            added: null,
            raw: const {})));
    ArrLibraryEntry? opened;
    await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
            body: ArrLibraryGrid(
                entries: entries,
                header: const SizedBox(height: 160, child: Text('Arr header')),
                contentPadding: const EdgeInsets.fromLTRB(110, 110, 24, 24),
                baseUrl: '',
                apiKey: '',
                onOpenDetail: (entry) => opened = entry,
                onSearch: (_) {},
                onToggleMonitored: (_) {},
                onEdit: (_) {},
                onRemove: (_) {}))));
    await tester.pumpAndSettle();
    expect(find.text('Film 0'), findsOneWidget);
    expect(find.text('2024'), findsWidgets);
    expect(find.text('Manquant'), findsWidgets);
    expect(find.byType(ColorFiltered), findsNothing);
    final gridFocus = tester
        .widgetList<Focus>(find.byType(Focus))
        .firstWhere((focus) => focus.focusNode?.debugLabel == 'ArrLibraryGrid')
        .focusNode!;
    gridFocus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(opened?.id, 1);
    final initialHeaderY = tester.getTopLeft(find.text('Arr header')).dy;
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.text('Arr header').hitTestable(), findsNothing);
    expect(
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .pixels,
        greaterThan(initialHeaderY + 300));
    final viewport = tester.getRect(find.byType(CustomScrollView));
    expect(viewport.top, 0);
    expect(viewport.left, 0);
    expect(tester.takeException(), isNull);
  });
}
