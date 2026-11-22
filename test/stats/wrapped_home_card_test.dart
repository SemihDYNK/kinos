import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kinos/providers/shared_provider.dart';
import 'package:kinos/ratings/kinos_ratings.dart';
import 'package:kinos/stats/stats_screen.dart' show viewingEventsProvider;
import 'package:kinos/stats/viewing_log.dart';
import 'package:kinos/stats/wrapped/wrapped_home_card.dart';
import 'package:kinos/theme/app_theme.dart';

void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  final events = [
    for (var n = 1; n <= 6; n++)
      ViewingEvent(
          identity: 'tmdb:movie:$n',
          kind: 'movie',
          title: 'Film $n',
          at: DateTime(2026, n, 3),
          runtimeSeconds: 7200,
          sources: const {ViewingSource.kinos}),
  ];

  Future<SharedPreferences> pump(WidgetTester tester, DateTime today) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        kinosRatingStoreProvider.overrideWith((ref) => null),
        viewingEventsProvider.overrideWith((ref) async => events),
      ],
      child: MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: CustomScrollView(slivers: [
            WrappedHomeCard(contentPadding: EdgeInsets.zero, today: today),
          ]),
        ),
      ),
    ));
    await tester.pump();
    return preferences;
  }

  testWidgets('the Wrapped card shows in December and hides for good',
      (tester) async {
    final preferences = await pump(tester, DateTime(2026, 12, 2));
    expect(find.text('VOTRE ANNÉE 2026'), findsOneWidget);
    expect(find.text('Voir mon année'), findsOneWidget);
    await tester.tap(find.byTooltip('Masquer'));
    await tester.pump();
    expect(find.text('VOTRE ANNÉE 2026'), findsNothing);
    expect(preferences.getBool('wrappedHomeHidden:2026'), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no Wrapped card in November', (tester) async {
    await pump(tester, DateTime(2026, 11, 22));
    expect(find.text('VOTRE ANNÉE 2026'), findsNothing);
  });
}
