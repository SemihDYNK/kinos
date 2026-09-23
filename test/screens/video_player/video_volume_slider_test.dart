import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus_platform_interface/wakelock_plus_platform_interface.dart';

import 'package:kinos/l10n/generated/app_localizations.dart';
import 'package:kinos/localization_delegates.dart';
import 'package:kinos/providers/shared_provider.dart';
import 'package:kinos/providers/settings/video_player_settings_provider.dart';
import 'package:kinos/providers/video_player_provider.dart';
import 'package:kinos/screens/video_player/components/video_volume_slider.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/widgets/shared/segmented_track.dart';

import '../../support/fake_base_player.dart';

class _NoopWakelockPlatform extends WakelockPlusPlatformInterface {
  @override
  Future<void> toggle({required bool enable}) async {}
  @override
  Future<bool> get enabled async => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  WakelockPlusPlatformInterface.instance = _NoopWakelockPlatform();

  late ProviderContainer container;
  late FakeBasePlayer fakePlayer;

  // `video_player_volume_sync_test.dart` réinitialise cette variable
  // depuis un `addTearDown` enregistré en `setUp`, et ça fonctionne —
  // mais ce fichier-là n'utilise que `test()` (pas `testWidgets`),
  // donc `TestWidgetsFlutterBinding._verifyInvariants` n'y tourne
  // jamais. Ici, `testWidgets` l'exécute juste après le corps du test
  // (`_runTestBody`, `flutter_test/lib/src/binding.dart`), AVANT que le
  // moindre `tearDown`/`addTearDown` de `package:test` (enregistré en
  // `setUp` ou ailleurs) ne s'exécute — leur chaîne encadre tout
  // l'appel `testWidgets`, `_verifyInvariants` compris. La seule
  // fenêtre valide est donc la dernière ligne du corps du test
  // lui-même, cf. `_resetPlatformOverride()` appelé en fin de chaque
  // test ci-dessous.
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
  });

  void resetPlatformOverride() => debugDefaultTargetPlatformOverride = null;

  Future<void> pumpSlider(WidgetTester tester,
      {AppDensity density = AppDensity.desk}) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      videoPlayerProvider.overrideWith((ref) => VideoPlayerNotifier(ref)),
    ]);
    addTearDown(container.dispose);

    fakePlayer = FakeBasePlayer();
    await container
        .read(videoPlayerProvider.notifier)
        .state
        .setup(fakePlayer);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: buildAppTheme(density: density),
        localizationsDelegates: KinosLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: Center(child: VideoVolumeSlider())),
      ),
    ));
    await tester.pump();
  }

  testWidgets('largeur de piste = 96 px en bureau', (tester) async {
    await pumpSlider(tester);

    final trackSize = tester.getSize(find.byType(SegmentedTrack));
    expect(trackSize.width, 96.0);
    expect(tester.takeException(), isNull);
    resetPlatformOverride();
  });

  testWidgets("l'icône haut-parleur coupe puis rétablit le son",
      (tester) async {
    await pumpSlider(tester);
    container.read(videoPlayerSettingsProvider.notifier).setVolume(70);
    await tester.pump();

    await tester.tap(find.byType(IconButton).first);
    await tester.pump();
    expect(container.read(videoPlayerSettingsProvider).internalVolume, 0);

    await tester.tap(find.byType(IconButton).first);
    await tester.pump();
    expect(container.read(videoPlayerSettingsProvider).internalVolume, 70);
    // Laisse s'écouler la lecture différée (300 ms) du volume-trace côté
    // moteur avant la destruction de l'arbre : sinon son `Timer` reste
    // en attente et `_verifyInvariants` échoue sur `!timersPending`.
    await tester.pump(const Duration(milliseconds: 350));
    resetPlatformOverride();
  });

  testWidgets('flèches clavier ±5 quand la piste a le focus', (tester) async {
    await pumpSlider(tester);
    container.read(videoPlayerSettingsProvider.notifier).setVolume(50);
    await tester.pump();

    // Simule le focus + glissement initial, comme un vrai clic sur la
    // piste (requestFocus() n'est déclenché que par onPointerDown).
    await tester.tapAt(tester.getCenter(find.byType(SegmentedTrack)));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    final afterRight =
        container.read(videoPlayerSettingsProvider).internalVolume;
    expect(afterRight, greaterThan(50));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(container.read(videoPlayerSettingsProvider).internalVolume,
        closeTo(afterRight - 5, 0.01));
    // Cf. le commentaire équivalent du test précédent : laisse le
    // `Timer` du volume-trace différé s'éteindre avant la fin du test.
    await tester.pump(const Duration(milliseconds: 350));
    resetPlatformOverride();
  });

  testWidgets('mode salon : cible interactive au moins AppDensity.couch.minTarget',
      (tester) async {
    await pumpSlider(tester, density: AppDensity.couch);

    // La zone interactive (SizedBox autour de la piste), pas le trait
    // peint lui-même.
    final interactiveArea = tester.getSize(find
        .ancestor(
          of: find.byType(SegmentedTrack),
          matching: find.byType(SizedBox),
        )
        .first);
    expect(interactiveArea.height, greaterThanOrEqualTo(AppDensity.couch.minTarget));
    expect(tester.takeException(), isNull);
    resetPlatformOverride();
  });

  testWidgets('piste et pouce partagent le même centre Y', (tester) async {
    await pumpSlider(tester);
    container.read(videoPlayerSettingsProvider.notifier).setVolume(60);
    await tester.pump();

    final trackY = tester.getCenter(find.byType(SegmentedTrack)).dy;
    final dotY = tester
        .getCenter(find.byWidgetPredicate((w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).shape == BoxShape.circle))
        .dy;
    expect((trackY - dotY).abs(), lessThanOrEqualTo(0.5));
    await tester.pump(const Duration(milliseconds: 350));
    resetPlatformOverride();
  });
}
