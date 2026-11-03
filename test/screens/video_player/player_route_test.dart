import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/wrappers/players/lib_mpv.dart';

class _Routes extends NavigatorObserver {
  Route<dynamic>? latest;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    latest = route;
  }
}

void main() {
  testWidgets('mpv entry never snapshots the external video texture',
      (tester) async {
    final routes = _Routes();
    final navigator = GlobalKey<NavigatorState>();
    final player = LibMPV();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigator,
      navigatorObservers: [routes],
      home: Builder(
          builder: (context) => TextButton(
                onPressed: () => unawaited(player.open(context)),
                child: const Text('Play'),
              )),
    ));
    await tester.tap(find.text('Play'));
    final route = routes.latest! as PageRoute;
    expect(route.allowSnapshotting, isFalse);
    navigator.currentState!.pop();
    await tester.pumpWidget(const SizedBox.shrink());
    await player.dispose();
  });
}
