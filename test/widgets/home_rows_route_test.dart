import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/routes/auto_router.dart';
import 'package:kinos/routes/auto_router.gr.dart';

void main() {
  testWidgets('home row settings resolves inside the settings navigator',
      (tester) async {
    late AutoRouter router;
    await tester.pumpWidget(ProviderScope(
      child: Consumer(builder: (context, ref, child) {
        router = AutoRouter(ref: ref);
        return const SizedBox.shrink();
      }),
    ));
    addTearDown(router.dispose);

    final match = router.matcher.matchByRoute(const HomeRoute(children: [
      SettingsRoute(children: [HomeRowsSettingsRoute()]),
    ]));

    expect(match, isNotNull,
        reason: 'The home row settings action must resolve under SettingsRoute');
    expect(match!.children!.single.children!.single.name,
        HomeRowsSettingsRoute.name);
  });
}
