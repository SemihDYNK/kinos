import 'package:kinos/recommendations/seerr/discovery_registry.dart';
import 'package:kinos/screens/shared/media_navigation.dart';
import 'package:kinos/routes/auto_router.gr.dart';
import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/l10n/generated/app_localizations.dart';
import 'package:kinos/models/account_model.dart';
import 'package:kinos/models/credentials_model.dart';
import 'package:kinos/models/seerr_credentials_model.dart';
import 'package:kinos/models/settings/home_row_model.dart';
import 'package:kinos/providers/user_provider.dart';
import 'package:kinos/providers/connectivity_provider.dart'
    show offlineStateProvider;
import 'package:kinos/recommendations/seerr/discovery_models.dart';
import 'package:kinos/recommendations/seerr/discovery_providers.dart';
import 'package:kinos/screens/dashboard/seerr_discovery_section.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/adaptive_layout/adaptive_layout.dart';
import 'package:kinos/util/adaptive_layout/adaptive_layout_model.dart';
import 'package:kinos/util/poster_defaults.dart';

AccountModel account(String id) => AccountModel(
    name: id,
    id: id,
    avatar: '',
    lastUsed: DateTime(2026),
    credentials: CredentialsModel.internal(serverId: 'server'),
    seerrCredentials: const SeerrCredentialsModel(
        serverUrl: 'https://seerr', apiKey: 'secret'));

class TestUser extends User {
  @override
  AccountModel? build() => account('a');
  void change(String id) {
    state = account(id);
  }
}

class PendingDetailsRouter extends RootStackRouter {
  final returned = Completer<void>();
  PageRouteInfo? opened;
  @override
  List<AutoRoute> get routes => [];
  @override
  Future<T?> push<T extends Object?>(PageRouteInfo route,
      {OnNavigationFailure? onFailure}) async {
    opened = route;
    await returned.future;
    return null;
  }
}

const scope = (
  serverId: 'server',
  userId: 'a',
  seerrUrl: 'https://seerr',
  language: 'fr',
  cacheDays: 7
);
const row = HomeRowModel(
    id: 'discovery',
    type: HomeRowType.seerrDiscovery,
    title: 'À découvrir',
    order: 0);
const items = [
  DiscoveryItem(key: (type: 'movie', id: 1), title: 'Premier', traits: []),
  DiscoveryItem(key: (type: 'tv', id: 1), title: 'Deuxième', traits: []),
];
Widget shell(Widget sliver,
        {double textScale = 1, AppDensity density = AppDensity.desk}) =>
    MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildAppTheme(density: density),
      home: MediaQuery(
          data: MediaQueryData(
              size: const Size(1400, 900),
              textScaler: TextScaler.linear(textScale)),
          child: AdaptiveLayout(
              data: const AdaptiveLayoutModel(
                  viewSize: ViewSize.desktop,
                  layoutMode: LayoutMode.single,
                  inputDevice: InputDevice.pointer,
                  platform: TargetPlatform.linux,
                  isDesktop: true,
                  posterDefaults: PosterDefaults(size: 180, ratio: 2 / 3),
                  controller: {},
                  sideBarWidth: 0,
                  topBarHeight: 0,
                  statusBarHeight: 0),
              child: Scaffold(body: CustomScrollView(slivers: [sliver])))),
    );
void main() {
  testWidgets('two retained discovery sections stop publishing once settled',
      (tester) async {
    final container = ProviderContainer(overrides: [
      userProvider.overrideWith(TestUser.new),
      offlineStateProvider.overrideWith((ref) => false),
      seerrDiscoveryProvider(scope).overrideWith((ref) async => items),
    ]);
    var publications = 0;
    final subscription = container.listen(
        discoveryRegistryProvider(
            discoveryAccountScope('server', 'a', 'https://seerr')),
        (_, __) => publications++);
    try {
      Widget page(bool movies) => UncontrolledProviderScope(
          container: container,
          child: shell(SliverMainAxisGroup(slivers: [
            if (movies)
              const SeerrDiscoverySection(
                  key: ValueKey('movies'),
                  row: row,
                  contentPadding: EdgeInsets.zero,
                  mediaType: 'movie'),
            const SeerrDiscoverySection(
                key: ValueKey('series'),
                row: row,
                contentPadding: EdgeInsets.zero,
                mediaType: 'tv'),
          ])));
      Set<String> registered() => container
          .read(discoveryRegistryProvider(
              discoveryAccountScope('server', 'a', 'https://seerr')))
          .values
          .expand((ids) => ids)
          .toSet();
      await tester.pumpWidget(page(true));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(publications, lessThan(8));
      final settled = publications;
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(publications, settled);
      expect(registered(), {'tmdb:movie:1', 'tmdb:tv:1'});
      await tester.pumpWidget(page(false));
      await tester.pumpAndSettle();
      expect(registered(), {'tmdb:tv:1'});
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(registered(), isEmpty);
    } finally {
      subscription.close();
      container.dispose();
    }
  });

  for (final type in ['movie', 'tv']) {
    testWidgets('$type home discovery hides other media and descriptions',
        (tester) async {
      final container = ProviderContainer(overrides: [
        userProvider.overrideWith(TestUser.new),
        offlineStateProvider.overrideWith((ref) => false),
        seerrDiscoveryProvider(scope).overrideWith((ref) async => items),
      ]);
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
          container: container,
          child: shell(SeerrDiscoverySection(
              row: row, contentPadding: EdgeInsets.zero, mediaType: type))));
      await tester.pumpAndSettle();
      expect(
          find.text(
              type == 'movie' ? 'Films à découvrir' : 'Séries à découvrir'),
          findsOneWidget);
      expect(
          find.text(
              type == 'movie' ? 'Séries à découvrir' : 'Films à découvrir'),
          findsNothing);
      expect(find.textContaining('Hors de votre bibliothèque'), findsNothing);
      expect(find.textContaining('Maj+F10'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final type in ['movie', 'tv']) {
    testWidgets(
        '$type discovery row carries its artwork and transition identity',
        (tester) async {
      final router = PendingDetailsRouter();
      addTearDown(router.dispose);
      final item = DiscoveryItem(
          key: (type: type, id: 42),
          title: 'Transition',
          posterPath: '/poster.jpg',
          year: 2024,
          traits: []);
      await tester.pumpWidget(ProviderScope(
          overrides: [
            userProvider.overrideWith(TestUser.new),
            offlineStateProvider.overrideWith((ref) => false),
            seerrDiscoveryProvider(scope).overrideWith((ref) async => [item]),
          ],
          child: StackRouterScope(
              controller: router,
              stateHash: 0,
              child: shell(const SeerrDiscoverySection(
                  row: row, contentPadding: EdgeInsets.zero)))));
      await tester.pumpAndSettle();
      final hero = tester.widget<Hero>(find.byType(Hero));
      final ring = tester.widget<FocusRing>(find
          .ancestor(
              of: find.text('Transition'), matching: find.byType(FocusRing))
          .first);
      await tester.tap(find.text('Transition'));
      await tester.pump();
      final args = (router.opened as SeerrDetailsRoute).args!;
      expect(args.mediaType, type == 'tv' ? 'tvshow' : 'movie');
      expect(args.tmdbId, 42);
      expect(args.poster!.title, item.title);
      expect(args.poster!.releaseYear, '2024');
      expect(hero.tag, (args.tag, false));
      final origin = args.tag as MediaNavigationOrigin;
      expect(origin.image!.path, 'https://image.tmdb.org/t/p/w500/poster.jpg');
      expect(args.poster!.images.primary, same(origin.image));
      final context = tester.element(find.byType(MediaArtwork));
      expect(MediaNavigationScope.focusOf(context), same(ring.focusNode));
      router.returned.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
      'fifteen films and series scroll horizontally with visible keyboard focus',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final cards = [
      for (final type in ['movie', 'tv'])
        for (var i = 0; i < 15; i++)
          DiscoveryItem(
              key: (type: type, id: i + 1), title: '$type $i', traits: [])
    ];
    DiscoveryItem? opened;
    await tester.pumpWidget(ProviderScope(
        child: shell(DiscoveryRowGrid(
            items: cards,
            padding: EdgeInsets.zero,
            onOpen: (_, item) => opened = item))));
    await tester.pumpAndSettle();
    expect(find.text('Films à découvrir'), findsOneWidget);
    expect(find.text('Séries à découvrir'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    for (var i = 0; i < 14; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(opened?.title, 'movie 14');
    expect(
        tester.getRect(find.text('movie 14')).right, lessThanOrEqualTo(1400));
    final previous = find.byTooltip('Défiler vers la gauche').first;
    final next = find.byTooltip('Défiler vers la droite').first;
    expect(tester.getCenter(previous).dy,
        tester.getCenter(find.text('Films à découvrir')).dy);
    final before = tester.getRect(find.text('movie 0')).left;
    await tester.tap(previous);
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('movie 0')).left, greaterThan(before));
    final shifted = tester.getRect(find.text('movie 0')).left;
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('movie 0')).left, lessThan(shifted));
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'visiting a request detail preserves discovery without recomputing',
      (tester) async {
    final router = PendingDetailsRouter();
    addTearDown(router.dispose);
    var starts = 0;
    final container = ProviderContainer(overrides: [
      userProvider.overrideWith(TestUser.new),
      offlineStateProvider.overrideWith((ref) => false),
      seerrDiscoveryProvider(scope).overrideWith((ref) async {
        starts++;
        return items;
      }),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: StackRouterScope(
          controller: router,
          stateHash: 0,
          child: shell(const SeerrDiscoverySection(
              row: row, contentPadding: EdgeInsets.zero))),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Premier'));
    await tester.pumpAndSettle();
    expect(router.opened?.routeName, 'SeerrDetailsRoute');
    expect(find.text('Films à découvrir'), findsOneWidget);
    container
        .read(discoveryRequestedProvider(
                discoveryAccountScope('server', 'a', 'https://seerr'))
            .notifier)
        .update((ids) => {...ids, 'tmdb:movie:1'});
    router.returned.complete();
    await tester.pumpAndSettle();
    expect(starts, 1,
        reason: 'A detail visit must not reload the full library');
    expect(find.text('Premier'), findsNothing);
    expect(find.text('Deuxième'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
  testWidgets(
      'keyboard reaches cards, activates typed media and opens context menu',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    DiscoveryItem? opened;
    await tester.pumpWidget(ProviderScope(
        child: shell(DiscoveryRowGrid(
            items: items,
            padding: const EdgeInsets.all(AppSpacing.md),
            onOpen: (_, item) => opened = item))));
    await tester.pumpAndSettle();
    expect(find.text('À demander'), findsNWidgets(2));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(opened?.key, items.first.key);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(opened?.key, items.last.key);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.f10);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
    expect(find.byType(PopupMenuItem<bool>), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final density in AppDensity.values) {
    testWidgets('no overflow with large text in ${density.name}',
        (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(ProviderScope(
          child: shell(
              DiscoveryRowGrid(
                  items: items,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  onOpen: (_, __) {}),
              textScale: 2,
              density: density)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('first frame and a hanging computation never delay the home',
      (tester) async {
    final pending = Completer<List<DiscoveryItem>>();
    var starts = 0;
    final container = ProviderContainer(overrides: [
      userProvider.overrideWith(TestUser.new),
      offlineStateProvider.overrideWith((ref) => false),
      seerrDiscoveryProvider(scope).overrideWith((ref) {
        starts++;
        return pending.future;
      }),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: shell(const SliverMainAxisGroup(slivers: [
          SliverToBoxAdapter(child: Text('Accueil prêt')),
          SeerrDiscoverySection(row: row, contentPadding: EdgeInsets.zero),
        ]))));
    expect(find.text('Accueil prêt'), findsOneWidget);
    expect(starts, 0);
    await tester.pump();
    expect(starts, 1);
    expect(find.text('Films à découvrir'), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(starts, 1,
        reason: 'Returning focus must not cancel an unfinished calculation');
    pending.complete(items);
    await tester.pumpAndSettle();
    expect(find.text('Films à découvrir'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(starts, 1,
        reason: 'Returning focus must preserve completed discovery results');
    container
        .read(discoveryRequestedProvider(
                discoveryAccountScope('server', 'a', 'https://seerr'))
            .notifier)
        .update((ids) => {...ids, 'tmdb:movie:1'});
    await tester.pumpAndSettle();
    expect(find.text('Premier'), findsNothing);
    expect(find.text('Deuxième'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
  testWidgets(
      'refresh failure hides previous successful data without an error label',
      (tester) async {
    var fail = false;
    final container = ProviderContainer(overrides: [
      userProvider.overrideWith(TestUser.new),
      offlineStateProvider.overrideWith((ref) => false),
      seerrDiscoveryProvider(scope).overrideWith((ref) async {
        if (fail) throw const FormatException('secret error');
        return items;
      }),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: shell(const SeerrDiscoverySection(
            row: row, contentPadding: EdgeInsets.zero))));
    await tester.pumpAndSettle();
    expect(find.text('Premier'), findsOneWidget);
    fail = true;
    container.invalidate(seerrDiscoveryProvider(scope));
    await tester.pumpAndSettle();
    expect(find.text('Premier'), findsNothing);
    expect(find.text('Films à découvrir'), findsNothing);
    expect(find.textContaining('secret error'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
  testWidgets('offline transition removes the row and disposes discovery work',
      (tester) async {
    final offline = StateProvider((ref) => false);
    var disposed = false;
    final container = ProviderContainer(overrides: [
      userProvider.overrideWith(TestUser.new),
      offlineStateProvider.overrideWith((ref) => ref.watch(offline)),
      seerrDiscoveryProvider(scope).overrideWith((ref) async {
        ref.onDispose(() => disposed = true);
        return items;
      }),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: shell(const SeerrDiscoverySection(
            row: row, contentPadding: EdgeInsets.zero))));
    await tester.pumpAndSettle();
    expect(find.text('Premier'), findsOneWidget);
    container.read(offline.notifier).state = true;
    await tester.pumpAndSettle();
    expect(find.text('Films à découvrir'), findsNothing);
    expect(disposed, true);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
  testWidgets('disabled row never starts work', (tester) async {
    var starts = 0;
    final container = ProviderContainer(overrides: [
      userProvider.overrideWith(TestUser.new),
      offlineStateProvider.overrideWith((ref) => false),
      seerrDiscoveryProvider(scope).overrideWith((ref) async {
        starts++;
        return items;
      }),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: shell(SeerrDiscoverySection(
            row: row.copyWith(enabled: false),
            contentPadding: EdgeInsets.zero))));
    await tester.pumpAndSettle();
    expect(starts, 0);
    expect(find.text('Films à découvrir'), findsNothing);
  });
  testWidgets('profile switch disposes work and never displays late old data',
      (tester) async {
    final pending = Completer<List<DiscoveryItem>>();
    var disposed = false;
    final container = ProviderContainer(overrides: [
      userProvider.overrideWith(TestUser.new),
      offlineStateProvider.overrideWith((ref) => false),
      seerrDiscoveryProvider(scope).overrideWith((ref) {
        ref.onDispose(() => disposed = true);
        return pending.future;
      }),
      seerrDiscoveryProvider((
        serverId: 'server',
        userId: 'b',
        seerrUrl: 'https://seerr',
        language: 'fr',
        cacheDays: 7
      )).overrideWith((ref) async => []),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: shell(const SeerrDiscoverySection(
            row: row, contentPadding: EdgeInsets.zero))));
    await tester.pumpAndSettle();
    (container.read(userProvider.notifier) as TestUser).change('b');
    await tester.pumpAndSettle();
    expect(disposed, true);
    pending.complete(items);
    await tester.pumpAndSettle();
    expect(find.text('Premier'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
