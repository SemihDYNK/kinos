import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus_platform_interface/wakelock_plus_platform_interface.dart';

import 'package:kinos/providers/shared_provider.dart';
import 'package:kinos/providers/video_player_provider.dart';
import 'package:kinos/providers/settings/video_player_settings_provider.dart';

import '../support/fake_base_player.dart';

/// `MediaControlsWrapper._applyWakelock` (zone protégée, `lib/wrappers/`)
/// appelle le canal de plateforme `wakelock_plus` à chaque événement
/// d'état du lecteur — jamais mocké par défaut sous `flutter test`. Rien
/// à voir avec le volume : neutralisé pour ne pas faire échouer les
/// assertions asynchrones sans rapport avec ce qui est testé ici.
class _NoopWakelockPlatform extends WakelockPlusPlatformInterface {
  @override
  Future<void> toggle({required bool enable}) async {}

  @override
  Future<bool> get enabled async => false;
}

/// Historique : un premier correctif avait ajouté un relais moteur ->
/// interface (`syncVolumeFromEngine`), justifié par le bug "curseur à 0,
/// son à pleine puissance" après restauration de session. Ce relais
/// s'est révélé être la cause d'une régression bien pire : le moteur
/// (`lib_mpv.dart`, lecture seule, jamais modifié) ré-émet fidèlement
/// chaque palier de son propre fondu lecture/pause
/// (`_startPlaybackFade`, actif par défaut via `enablePlayPauseFade`)
/// comme un vrai `PlayerState.volume`, palier par palier jusqu'à 0 à
/// chaque pause — le relais recopiait CES paliers dans l'affichage,
/// donnant "volume à 0 à chaque pause" et des remontées erratiques sur
/// un palier de fondu en retard. Confirmé par une reproduction
/// temporaire avec logs avant retrait du relais (non conservée ici).
///
/// Le [FakeBasePlayer] utilisé ci-dessous reproduit fidèlement ce fondu
/// (lu directement dans `lib_mpv.dart`, jamais deviné) plutôt que de se
/// contenter de renvoyer la valeur demandée — c'est ce qui aurait dû
/// faire échouer le premier jeu de tests (trop naïf) et ne l'a pas fait.
///
/// Aucun test ici ne crée de vrai lecteur mpv/media_kit : `setup()`
/// (`MediaControlsWrapper`, seam déjà prévu pour changer de moteur en
/// cours de session) enrôle le faux lecteur à la place de
/// `VideoPlayerNotifier.init()`, qui créerait un lecteur réel et
/// appellerait `AudioService.init()`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  WakelockPlusPlatformInterface.instance = _NoopWakelockPlatform();

  late ProviderContainer container;
  late FakeBasePlayer fakePlayer;

  Future<void> attachFakePlayer() async {
    fakePlayer = FakeBasePlayer();
    final notifier = container.read(videoPlayerProvider.notifier);
    await notifier.state.setup(fakePlayer);
  }

  setUp(() async {
    // Cible Linux desktop uniquement (cf. CLAUDE.md) : sous `flutter
    // test`, `defaultTargetPlatform` retombe sur android par défaut,
    // faute de vraie plateforme hôte — sans ce forçage, le volume
    // emprunterait la branche mobile (`VolumeController`, canal de
    // plateforme non mocké) au lieu de la branche desktop testée ici.
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      // Ne passe jamais par `VideoPlayerNotifier.init()` (mpv réel,
      // AudioService) : `setup()` enrôle directement le faux lecteur.
      videoPlayerProvider.overrideWith((ref) => VideoPlayerNotifier(ref)),
    ]);
    addTearDown(container.dispose);
    // `MediaControlsWrapper` (zone protégée) ne coupe jamais son
    // abonnement à `_player.stateStream` à la fin d'un test — laisse le
    // temps aux derniers événements en vol (planifiés en microtâche par
    // `StreamController.broadcast()`) de s'écouler avant la destruction
    // du container, plutôt que de les laisser lire un container déjà
    // disposé.
    addTearDown(() => Future.delayed(const Duration(milliseconds: 50)));
  });

  test('curseur : le changement se propage au moteur', () async {
    await attachFakePlayer();
    container.read(videoPlayerSettingsProvider.notifier).setVolume(42);
    await Future.delayed(const Duration(milliseconds: 10));

    expect(container.read(videoPlayerSettingsProvider).internalVolume, 42);
    expect(fakePlayer.setVolumeCalls.last, 42.0);
  });

  test('mettre en pause ou lire ne modifie jamais le volume affiché',
      () async {
    await attachFakePlayer();
    container.read(videoPlayerSettingsProvider.notifier).setVolume(70);
    await Future.delayed(const Duration(milliseconds: 10));

    // pause() fait RÉELLEMENT transiter le volume du moteur par 0
    // (fondu de sortie fidèle à lib_mpv.dart) — l'affichage ne doit
    // jamais suivre ces paliers.
    await fakePlayer.pause();
    await Future.delayed(const Duration(milliseconds: 10));
    expect(container.read(videoPlayerSettingsProvider).internalVolume, 70);

    await fakePlayer.play();
    await Future.delayed(const Duration(milliseconds: 10));
    expect(container.read(videoPlayerSettingsProvider).internalVolume, 70);
  });

  test(
      'baisser le curseur de 100 à 40 résiste à 10 événements de fondu '
      'périmés', () async {
    await attachFakePlayer();
    container.read(videoPlayerSettingsProvider.notifier).setVolume(100);
    await Future.delayed(const Duration(milliseconds: 10));

    container.read(videoPlayerSettingsProvider.notifier).setVolume(40);

    // Simule un fondu resté "en vol" qui ré-émet des paliers vers
    // l'ancienne valeur pendant que le nouveau volume vient d'être posé
    // — exactement le mécanisme de la régression rapportée.
    for (var i = 0; i < 10; i++) {
      fakePlayer.emit(fakePlayer.lastState.update(volume: 100 - i.toDouble()));
    }
    await Future.delayed(const Duration(milliseconds: 10));

    expect(container.read(videoPlayerSettingsProvider).internalVolume, 40);
  });

  test('muet puis rétablissement : revient au bon volume', () async {
    await attachFakePlayer();
    final settingsNotifier =
        container.read(videoPlayerSettingsProvider.notifier);

    settingsNotifier.setVolume(65);
    await Future.delayed(const Duration(milliseconds: 10));
    expect(fakePlayer.setVolumeCalls.last, 65.0);

    settingsNotifier.setVolume(0);
    await Future.delayed(const Duration(milliseconds: 10));
    expect(container.read(videoPlayerSettingsProvider).internalVolume, 0);
    expect(fakePlayer.setVolumeCalls.last, 0.0);

    settingsNotifier.setVolume(65);
    await Future.delayed(const Duration(milliseconds: 10));
    expect(container.read(videoPlayerSettingsProvider).internalVolume, 65);
    expect(fakePlayer.setVolumeCalls.last, 65.0);
  });

  test(
      'reprise de session après une sortie en muet : restaure le dernier '
      'volume non nul, jamais 0', () async {
    await attachFakePlayer();
    final settingsNotifier =
        container.read(videoPlayerSettingsProvider.notifier);

    // La session précédente s'est terminée en muet — `_setVolume` a
    // conservé 55 comme dernier volume non nul avant la mise en muet.
    settingsNotifier.setVolume(55);
    await Future.delayed(const Duration(milliseconds: 10));
    settingsNotifier.setVolume(0);
    await Future.delayed(const Duration(milliseconds: 10));
    fakePlayer.setVolumeCalls.clear();

    // Même appel que `SharedUtility.loadSettings()` au démarrage.
    final persisted = settingsNotifier.state.copyWith(internalVolume: 0);
    settingsNotifier.restoreFromPersisted(
        persisted, container.read(sharedUtilityProvider).lastNonZeroVideoVolume);
    await Future.delayed(const Duration(milliseconds: 10));

    expect(container.read(videoPlayerSettingsProvider).internalVolume, 55);
    expect(fakePlayer.setVolumeCalls, contains(55.0));
    expect(fakePlayer.setVolumeCalls, isNot(contains(0.0)));
  });

  test('reprise de session sans historique connu : repli sur 100',
      () async {
    await attachFakePlayer();
    final settingsNotifier =
        container.read(videoPlayerSettingsProvider.notifier);

    // Baseline différente de 100 sans passer par `setVolume`/`_setVolume`
    // — ça mémoriserait justement un dernier volume non nul, ce que ce
    // test veut vérifier absent. Le modèle par défaut vaut déjà 100,
    // sans cette baseline la restauration ne changerait rien et
    // masquerait le test.
    settingsNotifier.state = settingsNotifier.state.copyWith(internalVolume: 30);
    await Future.delayed(const Duration(milliseconds: 10));
    fakePlayer.setVolumeCalls.clear();

    final persisted = settingsNotifier.state.copyWith(internalVolume: 0);
    settingsNotifier.restoreFromPersisted(
        persisted, container.read(sharedUtilityProvider).lastNonZeroVideoVolume);
    await Future.delayed(const Duration(milliseconds: 10));

    expect(container.read(videoPlayerSettingsProvider).internalVolume, 100);
    expect(fakePlayer.setVolumeCalls, contains(100.0));
  });

  test(
      "chaque mouvement du curseur atteint l'instance qui joue réellement, "
      'jamais une autre', () async {
    await attachFakePlayer();
    // L'instance qui "joue" est celle enrôlée par `setup()` — la même
    // que `loadPlaybackItem`/`loadAudioPlaybackItem` utiliseraient pour
    // charger le média. `videoPlayerProvider` est un singleton
    // (StateNotifierProvider non-autoDispose) : `container.read(...)`
    // doit toujours renvoyer le même wrapper, quel que soit le nombre
    // d'appels.
    final playingWrapper = container.read(videoPlayerProvider);

    for (final value in [0.0, 30.0, 60.0, 100.0]) {
      container.read(videoPlayerSettingsProvider.notifier).setVolume(value);
      await Future.delayed(const Duration(milliseconds: 10));

      expect(identical(container.read(videoPlayerProvider), playingWrapper),
          isTrue,
          reason: 'le wrapper a changé d\'identité entre deux mouvements');
      expect(fakePlayer.setVolumeCalls.last, value,
          reason: 'le faux lecteur qui "joue" n\'a pas reçu ce volume');
    }

    // Aucun autre faux lecteur n'a jamais existé dans ce test : si les
    // 4 valeurs précédentes sont bien dans l'ordre sur le MÊME
    // `fakePlayer`, c'est la preuve directe qu'aucun appel n'a pu
    // atteindre une autre instance.
    expect(fakePlayer.setVolumeCalls, [0.0, 30.0, 60.0, 100.0]);
  });

  test(
      'écriture de state avant que le moteur ne soit initialisé : aucun '
      'appel, aucun plantage', () async {
    // Ne passe jamais par `attachFakePlayer()` ici : le wrapper existe
    // (construit par `VideoPlayerNotifier`) mais `setup()` n'a jamais
    // été appelé, `hasPlayer` est donc faux.
    final settingsNotifier =
        container.read(videoPlayerSettingsProvider.notifier);

    expect(
      () => settingsNotifier.setVolume(30),
      returnsNormally,
    );
    expect(container.read(videoPlayerSettingsProvider).internalVolume, 30);
  });

  // Régression : `VideoPlayerSettingsProviderNotifier.state=` faisait
  // `ref.read(videoPlayerProvider)` pour pousser le volume, alors que
  // `videoPlayerProvider` (`VideoPlayerNotifier._listenToSettings`, dans
  // son constructeur ET dans `init()`) lit déjà `videoPlayerSettingsProvider`
  // via `ref.listen` — un read en sens inverse forme un cycle que
  // Riverpod détecte dès que les DEUX sens ont été empruntés au moins
  // une fois (`CircularDependencyError`, observé en usage réel : lecture
  // d'une première vidéo — qui établit `videoPlayerProvider ->
  // videoPlayerSettingsProvider` via `loadPlaybackItem` — puis un
  // mouvement du curseur de volume). Non reproduit avant ce test : les
  // autres tests de ce fichier construisent `VideoPlayerNotifier` via
  // l'override (`attachFakePlayer`), qui enregistre désormais la même
  // écoute dès le CONSTRUCTEUR (`_listenToSettings`, plus seulement dans
  // `init()`, jamais appelé ici) — donc l'arête existe déjà dans TOUS
  // les tests de ce fichier ; celui-ci l'affirme explicitement plutôt
  // que de compter sur une couverture implicite.
  test(
      "changer le volume après qu'un lecteur a été attaché ne lève jamais "
      'CircularDependencyError', () async {
    await attachFakePlayer();

    expect(
      () => container.read(videoPlayerSettingsProvider.notifier).setVolume(77),
      returnsNormally,
    );
    await Future.delayed(const Duration(milliseconds: 10));
    expect(container.read(videoPlayerSettingsProvider).internalVolume, 77);
    expect(fakePlayer.setVolumeCalls, contains(77.0));
  });
}
