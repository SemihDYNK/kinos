import 'dart:io';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/models/library_filter_model.dart';
import 'package:kinos/models/item_base_model.dart';
import 'package:kinos/providers/library_search_provider.dart';
import 'package:kinos/providers/user_provider.dart';
import 'package:kinos/screens/library_search/library_search_screen.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/adaptive_layout/adaptive_layout.dart';
import 'package:kinos/widgets/shared/frosted_surface.dart';
import 'package:kinos/widgets/shared/item_actions.dart';
import 'seerr_discovery_section_test.dart'
    show shell, TestUser, PendingDetailsRouter;

const libraryKey = ValueKey('header-test');

class Library extends LibrarySearchNotifier {
  Library(super.ref) {
    state = state.copyWith(
        filters: const LibraryFilterModel(
            types: {KinosItemType.movie: true},
            genres: {'Science-fiction': true},
            years: {2024: false}));
  }
}

void main() {
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => Directory.systemTemp.path);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('flutter_keyboard_visibility'),
            (_) async => null);
  });
  Future<void> mount(WidgetTester tester,
      {double scale = 1, double reservedTop = 0}) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = PendingDetailsRouter();
    addTearDown(router.dispose);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          librarySearchProvider(libraryKey).overrideWith(Library.new),
          userProvider.overrideWith(TestUser.new)
        ],
        child: StackRouterScope(
            controller: router,
            stateHash: 0,
            child: shell(
                SliverMainAxisGroup(slivers: [
                  SliverToBoxAdapter(
                      child: Consumer(
                          builder: (context, ref, _) => AdaptiveLayout(
                              data: AdaptiveLayout.of(context)
                                  .copyWith(topBarHeight: reservedTop),
                              child: MediaQuery(
                                  data: MediaQuery.of(context).copyWith(
                                      padding: MediaQuery.paddingOf(context)
                                          .copyWith(top: reservedTop)),
                                  child: LibraryAppBar(
                                      toolbarHeight:
                                          AppPageLayout.toolbarHeight,
                                      menuActions: [
                                        ItemActionButton(
                                            label: const Text('Actualiser'),
                                            action: () {})
                                      ],
                                      librarySearchResults: ref.watch(
                                          librarySearchProvider(libraryKey)),
                                      isEmptySearchScreen: false,
                                      refreshKey:
                                          GlobalKey<RefreshIndicatorState>(),
                                      uniqueKey: libraryKey,
                                      libraryProvider: ref.read(librarySearchProvider(libraryKey).notifier),
                                      scrollController: controller))))),
                  SliverList.builder(
                      itemCount: 40,
                      itemBuilder: (_, i) =>
                          SizedBox(height: 100, child: Text('Affiche $i'))),
                ]),
                textScale: scale))));
    await tester.pumpAndSettle();
  }

  test('clearing refinements preserves the catalogue scope', () {
    final container = ProviderContainer(overrides: [
      librarySearchProvider(libraryKey).overrideWith(Library.new)
    ]);
    addTearDown(container.dispose);
    final notifier = container.read(librarySearchProvider(libraryKey).notifier);
    notifier.clearRefinements();
    final state = container.read(librarySearchProvider(libraryKey));
    expect(state.filters.types[KinosItemType.movie], isTrue);
    expect(state.filters.genres['Science-fiction'], isFalse);
  });
  testWidgets('compact controls group advanced filters and scroll away',
      (tester) async {
    await mount(tester);
    expect(find.text('Trier : Nom'), findsOneWidget);
    expect(find.text('Vu / Non vu'), findsOneWidget);
    expect(find.text('Récursif'), findsNothing);
    await tester.tap(find.text('Filtres'));
    await tester.pumpAndSettle();
    expect(find.text('Récursif'), findsOneWidget);
    await tester.tap(find.byTooltip('Fermer'));
    await tester.pumpAndSettle();
    await tester.drag(
        find.byType(CustomScrollView).first, const Offset(0, -650));
    await tester.pumpAndSettle();
    expect(find.text('Trier : Nom').hitTestable(), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('active genre can be removed and large text fits',
      (tester) async {
    await mount(tester, scale: 1.5);
    final chip = find.widgetWithText(InputChip, 'Science-fiction');
    expect(chip, findsOneWidget);
    await tester
        .tap(find.descendant(of: chip, matching: find.byTooltip('Supprimer')));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(InputChip, 'Science-fiction'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('action group reaches the content edge and uses rounded hover',
      (tester) async {
    await mount(tester);
    final header = tester.getRect(find.byType(LibraryAppBar));
    final actions = find.byWidgetPredicate((widget) =>
        widget is GlassPopupMenuButton && widget.tooltip == 'Actions');
    expect(tester.getRect(actions).right,
        closeTo(header.right - AppSpacing.screenPadding, 1));
    expect(tester.widget<GlassPopupMenuButton>(actions).borderRadius,
        AppNavigation.border);
  });
  testWidgets(
      'initial header reserves the floating bar space inside the scroll',
      (tester) async {
    await mount(tester, reservedTop: AppTopNavigation.contentInset);
    expect(tester.getTopLeft(find.text('Films')).dy,
        greaterThanOrEqualTo(AppTopNavigation.contentInset + AppSpacing.lg));
    expect(
        tester.getTopLeft(find.text('Films')).dy,
        lessThan(
            AppTopNavigation.contentInset + AppSpacing.lg + AppSpacing.xl));
    await tester.drag(
        find.byType(CustomScrollView).first, const Offset(0, -650));
    await tester.pumpAndSettle();
    expect(find.text('Films').hitTestable(), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
