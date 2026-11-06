import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kinos/l10n/generated/app_localizations.dart';
import 'package:kinos/localization_delegates.dart';
import 'package:kinos/models/account_model.dart';
import 'package:kinos/models/credentials_model.dart';
import 'package:kinos/models/login_screen_model.dart';
import 'package:kinos/providers/auth_provider.dart';
import 'package:kinos/providers/discovery_provider.dart';
import 'package:kinos/screens/login/login_screen_credentials.dart';
import 'package:kinos/screens/login/widgets/login_server_step.dart';
import 'package:kinos/services/local_network_permission.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/adaptive_layout/adaptive_layout.dart';
import 'package:kinos/util/adaptive_layout/adaptive_layout_model.dart';
import 'package:kinos/util/poster_defaults.dart';

const _salon = DiscoveryInfo(
  id: 'server-salon',
  name: 'Salon',
  address: 'https://salon.local',
  endPointAddress: null,
);

const _bureau = DiscoveryInfo(
  id: 'server-bureau',
  name: 'Bureau',
  address: 'https://bureau.local',
  endPointAddress: null,
);

Widget _serverStepHarness({
  required AsyncValue<List<DiscoveryInfo>> discovered,
  List<DiscoveryInfo> saved = const [],
  ValueChanged<DiscoveryInfo>? onServerSelected,
  VoidCallback? onAddServer,
  VoidCallback? onRetryDiscovery,
  VoidCallback? onRequestPermission,
  Locale locale = const Locale('fr'),
}) {
  return MaterialApp(
    theme: buildAppTheme(),
    locale: locale,
    localizationsDelegates: KinosLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: LoginServerStep(
          savedServers: saved,
          discoveredServers: discovered,
          onServerSelected: onServerSelected ?? (_) {},
          onAddServer: onAddServer ?? () {},
          onRetryDiscovery: onRetryDiscovery ?? () {},
          onRequestPermission: onRequestPermission ?? () {},
        ),
      ),
    ),
  );
}

Widget _credentialsHarness(
  LoginScreenModel initial, {
  double textScale = 1.0,
}) {
  const layout = AdaptiveLayoutModel(
    viewSize: ViewSize.desktop,
    layoutMode: LayoutMode.single,
    inputDevice: InputDevice.pointer,
    platform: TargetPlatform.linux,
    isDesktop: true,
    posterDefaults: PosterDefaults(size: 180, ratio: 2 / 3),
    controller: {},
    sideBarWidth: 0,
    topBarHeight: 0,
    statusBarHeight: 0,
  );

  return ProviderScope(
    overrides: [
      authProvider
          .overrideWith((ref) => _FakeAuthNotifier(ref, initial: initial)),
      serverDiscoveryProvider
          .overrideWith(() => _FakeDiscovery(const [_bureau])),
    ],
    child: AdaptiveLayout(
      data: layout,
      child: MaterialApp(
        theme: buildAppTheme(),
        locale: const Locale('fr'),
        localizationsDelegates: KinosLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
            ),
            child: const Scaffold(
              body: SingleChildScrollView(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: LoginScreenCredentials(),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUp(() {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  });

  tearDown(() {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });

  testWidgets('étape serveur : rangées, ajout libellé et découverte',
      (tester) async {
    DiscoveryInfo? selected;
    var added = 0;

    await tester.pumpWidget(_serverStepHarness(
      saved: const [_salon],
      discovered: const AsyncData<List<DiscoveryInfo>>([_bureau]),
      onServerSelected: (server) => selected = server,
      onAddServer: () => added++,
    ));
    await tester.pumpAndSettle();

    expect(find.text('Étape 1 sur 2'), findsOneWidget);
    expect(find.text('Serveurs enregistrés'), findsOneWidget);
    expect(find.text('Serveurs découverts'), findsOneWidget);
    expect(find.text('Salon'), findsOneWidget);
    expect(find.text('Bureau'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Ajouter un serveur'),
        findsOneWidget);

    await tester.tap(find.text('Bureau'));
    expect(selected, _bureau);

    await tester.tap(find.byKey(const Key('login.addServer')));
    expect(added, 1);
  });

  testWidgets('english localization du parcours serveur', (tester) async {
    await tester.pumpWidget(_serverStepHarness(
      locale: const Locale('en'),
      saved: const [_salon],
      discovered: const AsyncData<List<DiscoveryInfo>>([_bureau]),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Step 1 of 2'), findsOneWidget);
    expect(find.text('Saved servers'), findsOneWidget);
    expect(find.text('Discovered servers'), findsOneWidget);
    expect(find.text('Add a server'), findsOneWidget);
  });

  testWidgets(
      'clavier : la première rangée prend le focus, Entrée la sélectionne',
      (tester) async {
    DiscoveryInfo? selected;

    await tester.pumpWidget(_serverStepHarness(
      saved: const [_salon],
      discovered: const AsyncData<List<DiscoveryInfo>>([_bureau]),
      onServerSelected: (server) => selected = server,
    ));
    await tester.pumpAndSettle();

    expect(FocusManager.instance.primaryFocus, isNotNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(selected, _salon);

    final ring = find
        .ancestor(of: find.text('Salon'), matching: find.byType(FocusRing))
        .first;
    final container = tester.widget<AnimatedContainer>(
      find.descendant(of: ring, matching: find.byType(AnimatedContainer)).first,
    );
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.border?.top.color, AppColors.focus);
  });

  testWidgets('découverte : recherche explicite', (tester) async {
    await tester.pumpWidget(_serverStepHarness(
      discovered: const AsyncLoading<List<DiscoveryInfo>>(),
    ));
    await tester.pump();

    expect(find.byKey(const Key('login.discovery.loading')), findsOneWidget);
    expect(find.text('Recherche de serveurs sur le réseau…'), findsOneWidget);
  });

  testWidgets('découverte : absence de serveur et relance', (tester) async {
    var retried = 0;

    await tester.pumpWidget(_serverStepHarness(
      discovered: const AsyncData<List<DiscoveryInfo>>([]),
      onRetryDiscovery: () => retried++,
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login.discovery.empty')), findsOneWidget);
    expect(find.text('Aucun nouveau serveur trouvé'), findsOneWidget);
    expect(
        find.text(
            'Vérifiez que le serveur est allumé et connecté au même réseau.'),
        findsOneWidget);

    await tester.tap(find.text('Relancer la recherche'));
    expect(retried, 1);
  });

  testWidgets('découverte : échec réseau et relance', (tester) async {
    var retried = 0;

    await tester.pumpWidget(_serverStepHarness(
      discovered: AsyncError<List<DiscoveryInfo>>(
        Exception('discovery failed'),
        StackTrace.empty,
      ),
      onRetryDiscovery: () => retried++,
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login.discovery.error')), findsOneWidget);
    expect(find.text('La découverte des serveurs a échoué.'), findsOneWidget);

    await tester.tap(find.text('Relancer la recherche'));
    expect(retried, 1);
  });

  testWidgets('découverte : permission réseau demandée explicitement',
      (tester) async {
    var requested = 0;

    await tester.pumpWidget(_serverStepHarness(
      discovered: AsyncError<List<DiscoveryInfo>>(
        LocalNetworkPermissionDeniedException(),
        StackTrace.empty,
      ),
      onRequestPermission: () => requested++,
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login.discovery.permission')), findsOneWidget);
    expect(find.text('Accès au réseau local requis'), findsOneWidget);

    await tester.tap(find.text('Demander l’autorisation'));
    expect(requested, 1);
  });

  testWidgets(
      'étape compte : le clavier y mène, lien primaire et code secondaire',
      (tester) async {
    final account = AccountModel(
      name: 'Camille',
      id: 'user-camille',
      avatar: '',
      lastUsed: DateTime(2026, 11, 6),
      credentials: CredentialsModel.internal(
        url: 'https://salon.local',
        serverName: 'Salon',
        serverId: 'server-salon',
      ),
    );

    await tester.pumpWidget(_credentialsHarness(LoginScreenModel(
      accounts: [account],
      screen: LoginScreenType.login,
    )));
    await tester.pumpAndSettle();

    expect(find.text('Serveurs enregistrés'), findsOneWidget);
    expect(find.byKey(const Key('login.backToProfiles')), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.text('Compte'), findsOneWidget);
    expect(find.text('Connectez-vous à Serveur test.'), findsOneWidget);
    expect(find.byKey(const Key('login.backToServers')), findsOneWidget);

    final authLink =
        tester.widget<FilledButton>(find.byKey(const Key('login.authLink')));
    final quickConnect = tester
        .widget<OutlinedButton>(find.byKey(const Key('login.quickConnect')));
    expect(authLink.onPressed, isNotNull);
    expect(quickConnect.onPressed, isNotNull);
    expect(find.byKey(const Key('login.submit')), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const Key('login.authLink'))).dy,
      lessThan(
          tester.getTopLeft(find.byKey(const Key('login.quickConnect'))).dy),
    );
  });

  testWidgets('fenêtre étroite et texte à 150 % : aucun débordement',
      (tester) async {
    tester.view.physicalSize = const Size(600, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final account = AccountModel(
      name: 'Camille',
      id: 'user-camille',
      avatar: '',
      lastUsed: DateTime(2026, 11, 6),
      credentials: CredentialsModel.internal(
        url: 'https://salon.local',
        serverName: 'Salon',
        serverId: 'server-salon',
      ),
    );

    await tester.pumpWidget(_credentialsHarness(
      LoginScreenModel(
        accounts: [account],
        screen: LoginScreenType.login,
      ),
      textScale: 1.5,
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Compte'), findsOneWidget);
  });

  testWidgets('ajout manuel : le bouton libellé ouvre le dialogue de serveur',
      (tester) async {
    await tester.pumpWidget(_credentialsHarness(LoginScreenModel(
      screen: LoginScreenType.login,
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('login.addServer')));
    await tester.pumpAndSettle();

    expect(find.text('Ajouter un serveur'), findsWidgets);
    expect(find.text('Saisissez l’adresse de votre serveur Jellyfin.'),
        findsOneWidget);

    await tester.enterText(
      find.byType(TextField),
      'https://nouveau.local',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Connexion'));
    await tester.pumpAndSettle();

    expect(find.text('Compte'), findsOneWidget);
  });
}

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(super.ref, {required LoginScreenModel initial}) {
    state = initial;
  }

  @override
  Future<void> setServer(String server) async {
    state = state.copyWith(
      serverLoginModel: ServerLoginModel(
        tempCredentials: CredentialsModel.internal(
          url: server,
          serverName: 'Serveur test',
          serverId: 'server-test',
        ),
        hasQuickConnect: true,
      ),
      errorMessage: null,
      loading: false,
    );
  }
}

class _FakeDiscovery extends ServerDiscovery {
  _FakeDiscovery(this.servers);

  final List<DiscoveryInfo> servers;

  @override
  Stream<List<DiscoveryInfo>> build() => Stream.value(servers);
}
