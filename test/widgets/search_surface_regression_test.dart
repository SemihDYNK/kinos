import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/screens/shared/outlined_text_field.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/widgets/shared/app_page_header.dart';
import 'seerr_discovery_section_test.dart' show shell;

void main() {
  testWidgets('custom search decoration never inherits a second inner frame',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
        child: shell(const SliverToBoxAdapter(
            child: OutlinedTextField(
      decoration: InputDecoration(
          hintText: 'Rechercher',
          icon: Icon(Icons.search),
          border: InputBorder.none),
    )))));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 's');
    await tester.pump();
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.decoration?.enabledBorder, InputBorder.none);
    expect(field.decoration?.focusedBorder, InputBorder.none);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
  testWidgets('pinned search header hides artwork scrolling underneath',
      (tester) async {
    final boundaryKey = GlobalKey();
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: RepaintBoundary(
                key: boundaryKey,
                child: CustomScrollView(
                  controller: controller,
                  slivers: [
                    const PinnedHeaderSliver(
                        child: SearchHeaderSurface(
                            child: SizedBox(
                                height: 100,
                                child: Center(child: Text('Rechercher'))))),
                    SliverList.builder(
                        itemCount: 40,
                        itemBuilder: (_, __) => const SizedBox(
                            height: 120,
                            child: ColoredBox(color: Colors.white))),
                  ],
                )))));
    controller.jumpTo(300);
    await tester.pumpAndSettle();
    final boundary = boundaryKey.currentContext!.findRenderObject()!
        as RenderRepaintBoundary;
    final pixel = await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final offset = (30 * image.width + 30) * 4;
      final color = Color.fromARGB(255, bytes!.getUint8(offset),
          bytes.getUint8(offset + 1), bytes.getUint8(offset + 2));
      image.dispose();
      return color;
    });
    expect(pixel, AppColors.background);
    expect(tester.getTopLeft(find.text('Rechercher')).dy, lessThan(100));
    expect(tester.takeException(), isNull);
  });
}
