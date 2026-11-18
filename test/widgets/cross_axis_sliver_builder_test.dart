import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/widgets/shared/cross_axis_sliver_builder.dart';

void main() {
  testWidgets('scrolling does not rebuild the grid, a new width does',
      (tester) async {
    var builds = 0;
    Widget page(double width) => MaterialApp(
          home: Center(
            child: SizedBox(
              width: width,
              height: 400,
              child: CustomScrollView(slivers: [
                const SliverToBoxAdapter(child: SizedBox(height: 300)),
                CrossAxisSliverBuilder(builder: (context, crossAxisExtent) {
                  builds++;
                  return SliverList.builder(
                      itemCount: 50,
                      itemBuilder: (_, i) =>
                          SizedBox(height: 40, child: Text('$i')));
                }),
              ]),
            ),
          ),
        );
    await tester.pumpWidget(page(300));
    final first = builds;
    expect(first, greaterThan(0));
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(builds, first);
    await tester.pumpWidget(page(320));
    expect(builds, greaterThan(first));
  });
}
