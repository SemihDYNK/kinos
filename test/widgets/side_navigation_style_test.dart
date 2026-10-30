import 'package:kinos/theme/app_icons.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/motion_input.dart';
import 'package:kinos/util/adaptive_layout/adaptive_layout.dart';
import 'package:kinos/screens/shared/kinos_icon.dart';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/providers/user_provider.dart';
import 'package:kinos/providers/shared_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kinos/providers/dashboard/catalog_navigation_provider.dart';
import 'package:kinos/providers/settings/client_settings_provider.dart';
import 'package:kinos/jellyfin/jellyfin_open_api.enums.swagger.dart';
import 'package:kinos/providers/views_provider.dart';
import 'package:kinos/routes/auto_router.gr.dart';
import 'catalog_navigation_test.dart' show Views, CatalogRouter;
import 'package:kinos/screens/shared/user_icon.dart';
import 'package:kinos/widgets/navigation_scaffold/components/side_navigation_bar.dart';
import 'seerr_discovery_section_test.dart'
    show shell, TestUser, PendingDetailsRouter;

void main() {
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => Directory.systemTemp.path);
  });
  testWidgets(
      'logo returns to all home and a dedicated button expands the rail',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = CatalogRouter();
    addTearDown(router.dispose);
    await router.navigate(LibrarySearchRoute());
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(ProviderScope(
        overrides: [
          sharedUtilityProvider.overrideWith(
              (ref) => SharedUtility(ref: ref, sharedPreferences: preferences)),
          userProvider.overrideWith(TestUser.new),
          sideBarForceCollapsedProvider.overrideWith((ref) => false)
        ],
        child: StackRouterScope(
            controller: router,
            stateHash: 0,
            child: shell(const SliverToBoxAdapter(
                child: SizedBox(
                    height: 750,
                    child: SideNavigationRail(child: _ContentAnchor())))))));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
        tester.element(find.byType(SideNavigationRail)));
    container.read(catalogScopeProvider.notifier).state =
        (kind: BaseItemKind.movie, libraryId: null);
    final initiallyExpanded =
        container.read(clientSettingsProvider).expandSideBar;
    await tester.tap(find.byType(KinosIcon));
    await tester.pumpAndSettle();
    expect(router.current.name, DashboardRoute.name);
    expect(container.read(catalogScopeProvider), allCatalog);
    expect(container.read(clientSettingsProvider).expandSideBar,
        initiallyExpanded);
    final toggle = tester.getRect(find.byIcon(Icons.chevron_right));
    expect(
        toggle.top, greaterThan(tester.getRect(find.byType(KinosIcon)).bottom));
    expect(toggle.bottom,
        lessThan(tester.getRect(find.byType(Divider).first).top));
    final collapsedBounds = tester.getRect(find.byType(BackdropFilter));
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    final openingBounds = tester.getRect(find.byType(BackdropFilter));
    expect(openingBounds.width, greaterThan(collapsedBounds.width));
    expect(openingBounds.width, lessThan(240));
    expect(
        tester.getTopLeft(find.byKey(const ValueKey('rail-content-anchor'))).dx,
        closeTo(openingBounds.width + AppNavigation.inset * 2, .01));
    final labelOpacity =
        find.ancestor(of: find.text('Réduire'), matching: find.byType(Opacity));
    expect(labelOpacity, findsOneWidget);
    expect(tester.widget<Opacity>(labelOpacity).opacity, lessThan(1));
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pump();
    expect(tester.getRect(find.byType(BackdropFilter)).width,
        closeTo(openingBounds.width, .01));
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(container.read(clientSettingsProvider).expandSideBar, isTrue);
    expect(find.byType(KinosWordmark), findsOneWidget);
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    expect(container.read(clientSettingsProvider).expandSideBar, isFalse);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
  for (final keyboard in [false, true]) {
    testWidgets(
        'rail expansion is immediate for ${keyboard ? 'keyboard' : 'reduced motion'}',
        (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final router = PendingDetailsRouter();
      addTearDown(router.dispose);
      await tester.pumpWidget(ProviderScope(
          overrides: [
            sharedUtilityProvider.overrideWith((ref) =>
                SharedUtility(ref: ref, sharedPreferences: preferences)),
            userProvider.overrideWith(TestUser.new),
            sideBarForceCollapsedProvider.overrideWith((ref) => false),
          ],
          child: StackRouterScope(
            controller: router,
            stateHash: 0,
            child: shell(SliverToBoxAdapter(
                child: SizedBox(
              height: 750,
              child: Builder(
                  builder: (context) => MediaQuery(
                        data: MediaQuery.of(context)
                            .copyWith(disableAnimations: !keyboard),
                        child: const MotionInputBoundary(
                            child:
                                SideNavigationRail(child: SizedBox.expand())),
                      )),
            ))),
          )));
      await tester.pumpAndSettle();
      if (keyboard) await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      final container = ProviderScope.containerOf(
          tester.element(find.byType(SideNavigationRail)));
      container.read(clientSettingsProvider.notifier).toggleSideBar();
      await tester.pump();
      await tester.pump();
      expect(tester.getSize(find.byType(BackdropFilter)).width,
          AppNavigation.expandedWidth);
      final labelOpacity = find.ancestor(
          of: find.text('Réduire'), matching: find.byType(Opacity));
      expect(tester.widget<Opacity>(labelOpacity).opacity, 1);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }

  testWidgets('server libraries are directly reachable in the rail by keyboard',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = CatalogRouter();
    addTearDown(router.dispose);
    await router.navigate(const DashboardRoute());
    await tester.pumpWidget(ProviderScope(
        overrides: [
          userProvider.overrideWith(TestUser.new),
          viewsProvider.overrideWith(Views.new),
          sideBarForceCollapsedProvider.overrideWith((ref) => false)
        ],
        child: StackRouterScope(
            controller: router,
            stateHash: 0,
            child: shell(const SliverToBoxAdapter(
                child: SizedBox(
                    height: 750,
                    child: SideNavigationRail(child: SizedBox.expand())))))));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(router.current.name, LibrarySearchRoute.name);
    expect((router.current.args as LibrarySearchRouteArgs).parentId,
        ['animation']);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
  testWidgets('short rail keeps Arr and footer reachable by arrow keys',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = PendingDetailsRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          userProvider.overrideWith(TestUser.new),
          sideBarForceCollapsedProvider.overrideWith((ref) => false),
        ],
        child: StackRouterScope(
            controller: router,
            stateHash: 0,
            child: shell(
                const SliverToBoxAdapter(
                    child: SizedBox(
                        height: 400,
                        child: SideNavigationRail(child: SizedBox.expand()))),
                textScale: 1.5))));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    for (var i = 0; i < 3; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
    }
    final arr = tester.getRect(find.byIcon(AppIcons.activity));
    final viewport = tester.getRect(find.byType(SingleChildScrollView));
    expect(viewport.contains(arr.topLeft), isTrue);
    expect(viewport.contains(arr.bottomRight), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    final profile =
        find.ancestor(of: find.byType(UserIcon), matching: find.byType(Focus));
    expect(
        profile.evaluate().any((element) =>
            (element.widget as Focus).focusNode?.hasFocus ?? false),
        isTrue);
    final capsule = tester.getRect(find.byType(BackdropFilter));
    expect(capsule.contains(tester.getRect(find.byType(UserIcon)).bottomRight),
        isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('floating capsule diffuses the image behind its glass',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = PendingDetailsRouter();
    addTearDown(router.dispose);
    final key = GlobalKey();
    const content = SliverToBoxAdapter(
        child: SizedBox(
            height: 750,
            child: SideNavigationRail(
                child: CustomPaint(
                    painter: _Stripes(), child: SizedBox.expand()))));
    await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: ProviderScope(
            overrides: [
              userProvider.overrideWith(TestUser.new),
              sideBarForceCollapsedProvider.overrideWith((ref) => false)
            ],
            child: StackRouterScope(
                controller: router, stateHash: 0, child: shell(content)))));
    await tester.pumpAndSettle();
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final bytes = await tester.runAsync(() async {
      final image = await boundary.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      return data!;
    });
    final sampleY =
        tester.getRect(find.byType(BackdropFilter)).top.round() + 22;
    final samples = [
      for (var x = 30; x < 46; x++) bytes!.getUint8((sampleY * 1400 + x) * 4)
    ];
    final mean = samples.reduce((a, b) => a + b) / samples.length;
    expect(mean, greaterThan(40),
        reason: 'The backdrop must remain perceptible through the graphite');
    expect(
        samples.reduce((a, b) => a > b ? a : b) -
            samples.reduce((a, b) => a < b ? a : b),
        lessThan(8),
        reason: 'Sharp backdrop stripes must be diffused by the frosted glass');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
  testWidgets('profile is the single bottom action in floating navigation',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = PendingDetailsRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          userProvider.overrideWith(TestUser.new),
          sideBarForceCollapsedProvider.overrideWith((ref) => false),
        ],
        child: StackRouterScope(
            controller: router,
            stateHash: 0,
            child: shell(const SliverToBoxAdapter(
                child: SizedBox(
                    height: 750,
                    child: SideNavigationRail(child: SizedBox.expand())))))));
    await tester.pumpAndSettle();
    expect(find.byType(UserIcon), findsOneWidget);
    final avatar = tester.getRect(find.byType(UserIcon));
    final settings = tester.getRect(find.byIcon(AppIcons.settings));
    final capsule = tester.getRect(find.byType(BackdropFilter));
    expect(capsule.center.dy,
        closeTo(tester.getRect(find.byType(SideNavigationRail)).center.dy, .5),
        reason: 'The compact capsule must be vertically centered');
    expect(capsule.bottom, lessThan(720),
        reason:
            'The capsule must stop after its content rather than fill the viewport');
    expect(capsule.bottom - avatar.bottom, lessThan(32));
    final dividers = find.byType(Divider);
    expect(dividers, findsNWidgets(2));
    expect(tester.getRect(dividers.first).top,
        greaterThan(tester.getRect(find.byType(KinosIcon)).bottom));
    expect(tester.getRect(dividers.last).top,
        greaterThan(tester.getRect(find.byIcon(AppIcons.activity)).bottom));
    expect(tester.getRect(dividers.last).bottom, lessThan(settings.top));
    expect(avatar.center.dy, greaterThan(settings.center.dy));
    expect(avatar.left, greaterThan(12));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Arr', findRichText: true), findsOneWidget,
        reason: 'Collapsed navigation must show its label at keyboard focus');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

class _Stripes extends CustomPainter {
  const _Stripes();
  @override
  void paint(Canvas canvas, Size size) {
    for (var x = 0.0; x < size.width; x += 4) {
      canvas.drawRect(
          Rect.fromLTWH(x, 0, 4, size.height),
          Paint()
            ..color = (x / 4).round().isEven ? Colors.white : Colors.black);
    }
  }

  @override
  bool shouldRepaint(_Stripes oldDelegate) => false;
}

class _ContentAnchor extends StatelessWidget {
  const _ContentAnchor();
  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsetsDirectional.only(
            start: AdaptiveLayout.of(context).sideBarWidth),
        child: const Align(
            alignment: AlignmentDirectional.topStart,
            child: SizedBox(
                key: ValueKey('rail-content-anchor'), width: 20, height: 20)),
      );
}
