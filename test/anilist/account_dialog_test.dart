import 'package:kinos/providers/incognito_mode_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/anilist/anilist_account.dart';
import 'package:kinos/anilist/anilist_account_dialog.dart';
import 'package:kinos/anilist/anilist_runtime.dart';
import 'package:kinos/l10n/generated/app_localizations.dart';
import 'package:kinos/theme/app_theme.dart';

void main() {
  Future<void> mount(WidgetTester tester,
      {AnilistConnection? account, String? syncStatus}) async {
    await tester.pumpWidget(ProviderScope(
        overrides: [
          anilistConnectionProvider.overrideWith((ref) async => account),
          incognitoProvider.overrideWithValue(false),
          anilistSyncStatusProvider.overrideWith((ref) => syncStatus),
        ],
        child: MaterialApp(
            theme: buildAppTheme(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
                builder: (context) => Scaffold(
                    body: TextButton(
                        onPressed: () => showAnilistAccountDialog(context),
                        child: const Text('Open')))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('connection exposes browser flow and masks the token',
      (tester) async {
    await mount(tester);
    expect(find.text('Sign in with your browser'), findsOneWidget);
    expect(find.text('No account connected'), findsOneWidget);
    expect(
        tester.widget<TextField>(find.byType(TextField)).obscureText, isTrue);
    expect(find.text('Client Secret'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('connected account shows explicit synchronization control',
      (tester) async {
    await mount(tester,
        account: const AnilistConnection(
            id: 1, name: 'Viewer', token: 'hidden', enabled: true));
    expect(find.text('Viewer'), findsOneWidget);
    expect(find.text('Ready to synchronize in the background'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Sign in with your browser'), findsNothing);
    expect(find.text('Connect account'), findsNothing);
    expect(find.text('Disconnect'), findsOneWidget);
    expect(find.text('hidden'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('expired account can authenticate again', (tester) async {
    await mount(tester,
        account: const AnilistConnection(
            id: 1, name: 'Viewer', token: 'hidden', enabled: true),
        syncStatus: 'auth');
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Sign in with your browser'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
