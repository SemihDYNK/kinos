import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kinos/l10n/generated/app_localizations.dart';
import 'package:kinos/providers/shared_provider.dart';
import 'package:kinos/providers/settings/video_player_settings_provider.dart';
import 'package:kinos/screens/video_player/components/video_player_volume_indicator.dart';
import 'package:kinos/screens/video_player/components/player_motion.dart';

void main() {
  for (final reduced in [false, true]) {
    testWidgets(
        'volume updates immediately and survives repeated changes, reduced=$reduced',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
      addTearDown(container.dispose);
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      try {
        await tester.pumpWidget(UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: MediaQuery(
                  data: MediaQueryData(disableAnimations: reduced),
                  child: const VideoPlayerVolumeIndicator()),
            )));
        void volume(double value) => container
            .read(videoPlayerSettingsProvider.notifier)
            .setVolume(value);
        double scale(double value) => tester
            .widget<Transform>(find
                .ancestor(
                    of: find.byIcon(volumeIcon(value)),
                    matching: find.byType(Transform))
                .first)
            .transform
            .storage[0];
        volume(65);
        await tester.pump();
        expect(find.textContaining('65'), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 60));
        final before = scale(65);
        expect(before, reduced ? equals(1) : greaterThan(1));
        volume(70);
        await tester.pump();
        expect(find.textContaining('70'), findsOneWidget);
        expect(scale(70), closeTo(before, .001));
        await tester.pumpAndSettle();
        expect(scale(70), 1);
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
        expect(
            tester
                .widget<PlayerControlsMotion>(find.byType(PlayerControlsMotion))
                .visible,
            false);
        volume(0);
        await tester.pump();
        expect(find.byIcon(volumeIcon(0)), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 2));
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }
}
