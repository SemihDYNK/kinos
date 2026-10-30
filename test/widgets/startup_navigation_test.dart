import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:auto_route/auto_route.dart';
import 'package:kinos/screens/shared/startup_curtain.dart';
import 'package:kinos/theme/app_theme.dart';

class StartupRouter extends RootStackRouter {
  bool authenticated = false;
  @override
  List<AutoRoute> get routes => [
        AutoRoute(
          initial: true,
          page: PageInfo('Home', builder: (_) => const AutoRouter()),
          guards: [
            AutoRouteGuard.simple((resolver, router) {
              if (authenticated) {
                resolver.next();
                return;
              }
              resolver.redirectUntil(PageRouteInfo('Splash', args: () {
                authenticated = true;
                resolver.next();
              }));
            })
          ],
          children: [
            AutoRoute(
                initial: true,
                page: PageInfo('Dashboard',
                    builder: (_) => GestureDetector(
                        key: const Key('destination'),
                        behavior: HitTestBehavior.opaque,
                        onTap: () {},
                        child: const ColoredBox(color: Colors.blue))))
          ],
        ),
        AutoRoute(
            page: PageInfo('Splash',
                builder: (data) => Builder(
                    builder: (context) => TextButton(
                        onPressed: () {
                          final overlay =
                              Overlay.of(context, rootOverlay: true);
                          late final OverlayEntry entry;
                          entry = OverlayEntry(
                              builder: (_) => Positioned.fill(
                                  child: StartupCurtain(
                                      onRevealed: () => entry.remove())));
                          overlay.insert(entry);
                          data.argsAs<VoidCallback>()();
                          data.router.maybePop(true);
                        },
                        child: const Text('Ready'))))),
      ];
}

void main() {
  testWidgets('guard redirect reveals the authenticated destination',
      (tester) async {
    final router = StartupRouter();
    final boundaryKey = GlobalKey();
    addTearDown(router.dispose);
    await tester.pumpWidget(RepaintBoundary(
        key: boundaryKey,
        child: MaterialApp.router(routerConfig: router.config())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ready'));
    await tester.pump();
    await tester.pump(AppDurations.startupReveal ~/ 2);
    final boundary = boundaryKey.currentContext!.findRenderObject()!
        as RenderRepaintBoundary;
    final image = (await tester.runAsync(() => boundary.toImage()))!;
    final pixels = await tester
        .runAsync(() => image.toByteData(format: ui.ImageByteFormat.rawRgba));
    Color pixel(int x, int y) {
      final offset = (y * image.width + x) * 4;
      return Color.fromARGB(
          pixels!.getUint8(offset + 3),
          pixels.getUint8(offset),
          pixels.getUint8(offset + 1),
          pixels.getUint8(offset + 2));
    }

    expect(pixel(1, 1), AppColors.background);
    expect(pixel(image.width ~/ 2, image.height ~/ 2),
        isNot(AppColors.background));
    image.dispose();
    final target = tester.renderObject(find.byKey(const Key('destination')));
    expect(
        tester
            .hitTestOnBinding(const Offset(1, 1))
            .path
            .any((entry) => identical(entry.target, target)),
        isFalse);
    await tester.pumpAndSettle();
    expect(
        tester
            .hitTestOnBinding(const Offset(1, 1))
            .path
            .any((entry) => identical(entry.target, target)),
        isTrue);
  });

  testWidgets('new route stays under the circular curtain until revealed',
      (tester) async {
    final navigator = GlobalKey<NavigatorState>();
    const destinationKey = Key('destination');
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigator,
      home: const SizedBox.expand(),
    ));
    final overlay = navigator.currentState!.overlay!;
    late OverlayEntry curtain;
    curtain = OverlayEntry(
        builder: (_) => Positioned.fill(
              child: StartupCurtain(onRevealed: () => curtain.remove()),
            ));
    overlay.insert(curtain);
    navigator.currentState!.pushReplacement(PageRouteBuilder<void>(
      transitionDuration: Duration.zero,
      pageBuilder: (_, __, ___) => GestureDetector(
        key: destinationKey,
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: const ColoredBox(color: Colors.blue),
      ),
    ));
    await tester.pump();
    await tester.pump(AppDurations.startupReveal ~/ 2);
    final target = tester.renderObject(find.byKey(destinationKey));
    final hits = tester.hitTestOnBinding(const Offset(1, 1)).path;
    expect(hits.any((entry) => identical(entry.target, target)), isFalse);
    await tester.pumpAndSettle();
    expect(
        tester
            .hitTestOnBinding(const Offset(1, 1))
            .path
            .any((entry) => identical(entry.target, target)),
        isTrue);
  });
}
