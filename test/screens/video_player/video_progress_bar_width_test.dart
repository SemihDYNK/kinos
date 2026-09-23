import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wakelock_plus_platform_interface/wakelock_plus_platform_interface.dart';

import 'package:kinos/providers/video_player_provider.dart';
import 'package:kinos/screens/video_player/components/video_progress_bar.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/adaptive_layout/adaptive_layout.dart';
import 'package:kinos/util/adaptive_layout/adaptive_layout_model.dart';
import 'package:kinos/util/poster_defaults.dart';
import 'package:kinos/widgets/shared/segmented_track.dart';

/// `MediaControlsWrapper._applyWakelock` (zone protégée, `lib/wrappers/`)
/// appelle un canal de plateforme jamais mocké par défaut — sans rapport
/// avec ce qui est testé ici (largeur/mise en page).
class _NoopWakelockPlatform extends WakelockPlusPlatformInterface {
  @override
  Future<void> toggle({required bool enable}) async {}

  @override
  Future<bool> get enabled async => false;
}

AdaptiveLayoutModel _adaptiveLayout(InputDevice inputDevice) =>
    AdaptiveLayoutModel(
      viewSize: ViewSize.desktop,
      layoutMode: LayoutMode.single,
      inputDevice: inputDevice,
      platform: TargetPlatform.linux,
      isDesktop: true,
      posterDefaults: const PosterDefaults(size: 150, ratio: 1.5),
      controller: const {},
      sideBarWidth: 0,
      topBarHeight: 0,
      statusBarHeight: 0,
    );

/// Régression pour la refonte de la barre de progression (piste unique,
/// sans trou) : vérifie qu'aucune largeur usuelle ne produit de
/// `FlutterError` (débordement), y compris pour un film long (chapitres
/// nombreux, position proche de la fin), pendant la mise en tampon, et
/// avec `InputDevice.dPad` (mode salon — chemin `FocusButton` distinct
/// dans `KinosSlider`, cf. `kinos_slider.dart:203-217`).
///
/// `videoPlayerProvider` est surchargé pour ne jamais créer de vrai
/// lecteur mpv/media_kit (`VideoPlayerNotifier(ref)` sans `.init()`) —
/// `VideoProgressBar` ne sollicite le moteur que sur interaction
/// (glissement), jamais pendant le simple rendu vérifié ici.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  WakelockPlusPlatformInterface.instance = _NoopWakelockPlatform();

  Widget harness({
    required double width,
    required Duration duration,
    required Duration position,
    Duration? buffer,
    bool buffering = false,
    bool handleVisible = true,
    InputDevice inputDevice = InputDevice.pointer,
  }) {
    return ProviderScope(
      overrides: [
        videoPlayerProvider.overrideWith((ref) => VideoPlayerNotifier(ref)),
      ],
      child: AdaptiveLayout(
        data: _adaptiveLayout(inputDevice),
        child: MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: SizedBox(
              width: width,
              height: 20,
              child: VideoProgressBar(
                wasPlayingChanged: (_) {},
                wasPlaying: false,
                timerReset: () {},
                onPositionChanged: (_) {},
                duration: duration,
                position: position,
                buffering: buffering,
                buffer: buffer ?? position + const Duration(minutes: 5),
                handleVisible: handleVisible,
                hideHandleAtRest: true,
              ),
            ),
          ),
        ),
      ),
    );
  }

  for (final width in [900.0, 1280.0, 1920.0]) {
    testWidgets('largeur $width : aucun débordement en lecture normale',
        (tester) async {
      await tester.pumpWidget(harness(
        width: width,
        duration: const Duration(minutes: 45),
        position: const Duration(minutes: 12, seconds: 34),
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'largeur $width : aucun débordement pour un film long, en fin de '
        'lecture', (tester) async {
      await tester.pumpWidget(harness(
        width: width,
        duration: const Duration(hours: 3, minutes: 12),
        position: const Duration(hours: 3, minutes: 11, seconds: 58),
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('largeur $width : aucun débordement pendant la mise en tampon',
        (tester) async {
      await tester.pumpWidget(harness(
        width: width,
        duration: const Duration(minutes: 45),
        position: const Duration(minutes: 12),
        buffering: true,
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'largeur $width : aucun débordement en mode salon (InputDevice.dPad)',
        (tester) async {
      await tester.pumpWidget(harness(
        width: width,
        duration: const Duration(minutes: 45),
        position: const Duration(minutes: 12, seconds: 34),
        inputDevice: InputDevice.dPad,
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    // Régression pour la piste invisible : mesures de géométrie réelles
    // (RenderBox), pas seulement l'absence d'exception.
    testWidgets(
        'largeur $width : géométrie de piste correcte au repos',
        (tester) async {
      const duration = Duration(minutes: 45);
      const position = Duration(minutes: 12, seconds: 34);
      const buffer = Duration(minutes: 17, seconds: 34);
      await tester.pumpWidget(harness(
        width: width,
        duration: duration,
        position: position,
        buffer: buffer,
        handleVisible: false,
      ));
      await tester.pump();

      final trackSize = tester.getSize(find.byType(SegmentedTrack));
      expect(trackSize.width, greaterThan(0));
      expect(trackSize.height, SegmentedTrack.heightRest);

      final backgroundColor =
          (tester.widget(find.byKey(SegmentedTrack.backgroundKey)) as ColoredBox)
              .color;
      expect(backgroundColor.a, greaterThan(0),
          reason: 'la piste ne doit jamais être peinte transparente');

      final playedSize =
          tester.getSize(find.byKey(SegmentedTrack.primaryKey));
      final expectedPlayedWidth =
          (position.inMilliseconds / duration.inMilliseconds) * trackSize.width;
      expect(playedSize.width, closeTo(expectedPlayedWidth, 1.0));

      final bufferSize =
          tester.getSize(find.byKey(SegmentedTrack.secondaryKey));
      final expectedBufferWidth =
          (buffer.inMilliseconds / duration.inMilliseconds) * trackSize.width;
      expect(bufferSize.width, closeTo(expectedBufferWidth, 1.0));
    });

    testWidgets(
        'largeur $width : la piste épaissit au survol/focus (6 px)',
        (tester) async {
      await tester.pumpWidget(harness(
        width: width,
        duration: const Duration(minutes: 45),
        position: const Duration(minutes: 12, seconds: 34),
        // Ce harnais passe `handleVisible: true` par défaut.
      ));
      await tester.pump();
      await tester.pump(AppDurations.hover);

      final trackSize = tester.getSize(find.byType(SegmentedTrack));
      expect(trackSize.height, SegmentedTrack.heightHover);
    });
  }

  // Régression pour le pouce décentré verticalement (piste centrée à
  // Y≈858, pouce à Y≈865 sur la capture rapportée, soit 7 px d'écart) :
  // la piste (non positionnée, haute de seulement `trackHeight`)
  // dépendait de l'alignement PAR DÉFAUT du `Stack` racine
  // (`topStart`, jamais explicité), tandis que le pouce (un `Positioned`
  // occupant toute la hauteur via `top: 0, bottom: 0`) se centrait lui
  // correctement — d'où l'écart. Fixé en sortant la piste de tout
  // alignement ambiant (`Positioned.fill` + `Center` explicite).
  group('alignement vertical piste / pouce / marqueur de chapitre', () {
    Finder thumbDotFinder() => find.byWidgetPredicate((w) =>
        w is Container &&
        w.decoration is BoxDecoration &&
        (w.decoration as BoxDecoration).shape == BoxShape.circle);

    // Pointe du marqueur triangulaire sous l'infobulle de chapitre : un
    // carré de 30 px pivoté à -45° (cf. `_caretSize`/`_caretPushDown`
    // dans `video_progress_bar.dart`) — son centre ne bouge pas sous la
    // rotation (`Transform.rotate` pivote autour de son propre centre),
    // sa pointe basse est à `côté × √2 / 2` en dessous.
    double caretTipY(WidgetTester tester) {
      final center =
          tester.getCenter(find.byKey(const Key('chapter-card-caret')));
      return center.dy + 30.0 * math.sqrt2 / 2;
    }

    testWidgets('au repos : piste et pouce partagent le même centre Y',
        (tester) async {
      await tester.pumpWidget(harness(
        width: 1280,
        duration: const Duration(minutes: 45),
        position: const Duration(minutes: 12, seconds: 34),
        handleVisible: false,
      ));
      await tester.pump();

      final trackY = tester.getCenter(find.byType(SegmentedTrack)).dy;
      final dotY = tester.getCenter(thumbDotFinder()).dy;
      expect((trackY - dotY).abs(), lessThanOrEqualTo(0.5));
    });

    testWidgets(
        'au survol : piste, pouce et marqueur de chapitre partagent le '
        'même centre Y', (tester) async {
      await tester.pumpWidget(harness(
        width: 1280,
        duration: const Duration(minutes: 45),
        position: const Duration(minutes: 12, seconds: 34),
      ));
      await tester.pump();
      await tester.pump(AppDurations.hover);

      final trackY = tester.getCenter(find.byType(SegmentedTrack)).dy;
      final dotY = tester.getCenter(thumbDotFinder()).dy;
      expect((trackY - dotY).abs(), lessThanOrEqualTo(0.5));
      expect((trackY - caretTipY(tester)).abs(), lessThanOrEqualTo(0.5));
    });

    testWidgets(
        'pendant le glissement : piste et pouce partagent le même '
        'centre Y', (tester) async {
      await tester.pumpWidget(harness(
        width: 1280,
        duration: const Duration(minutes: 45),
        position: const Duration(minutes: 12, seconds: 34),
        handleVisible: false,
      ));
      await tester.pump();

      final gesture = await tester.startGesture(
          tester.getCenter(find.byType(VideoProgressBar)));
      await tester.pump();
      await tester.pump(AppDurations.hover);

      final trackY = tester.getCenter(find.byType(SegmentedTrack)).dy;
      final dotY = tester.getCenter(thumbDotFinder()).dy;
      expect((trackY - dotY).abs(), lessThanOrEqualTo(0.5));

      await gesture.up();
      // `KinosSlider.onChangeEnd` lance un `Future.delayed(250ms)` avant
      // de reprendre la lecture — laisse-le s'éteindre avant la fin du
      // test, sinon son `Timer` reste en attente
      // (`!timersPending`, cf. les tests du volume).
      await tester.pump(const Duration(milliseconds: 300));
    });
  });
}
