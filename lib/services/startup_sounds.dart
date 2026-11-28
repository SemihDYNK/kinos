import 'dart:async';

import 'package:kinos/services/background_players.dart';
import 'package:flutter/foundation.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart' as mpv;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kinos/providers/shared_provider.dart';

/// Réglage « Son au démarrage » (activé par défaut).
const startupSoundKey = 'startupSound';

bool startupSoundEnabled(SharedPreferences preferences) =>
    preferences.getBool(startupSoundKey) ?? true;

/// Le réglage « Son au démarrage », pour l'écran des réglages.
final startupSoundProvider = StateProvider<bool>(
    (ref) => startupSoundEnabled(ref.watch(sharedPreferencesProvider)));

void setStartupSound(WidgetRef ref, bool enabled) {
  ref.read(startupSoundProvider.notifier).state = enabled;
  ref.read(sharedPreferencesProvider).setBool(startupSoundKey, enabled);
}

/// Sons de l'intro : au clap, l'interrupteur d'un projecteur Super 8 (le
/// tout premier son de l'enregistrement, avant le moteur), et une nappe
/// lente et atmosphérique qui monte avec l'aurore ; à l'ouverture,
/// un souffle vif quand le faisceau surgit du K, puis un souffle d'air
/// léger qui passe de gauche à droite quand sa fenêtre s'élargit. Chacun part au moment où l'animation le franchit
/// (pas une piste mixée d'avance : l'horloge de l'intro peut ralentir un
/// instant quand une image bloque, une piste figée se décalerait).
///
/// Les lecteurs (mpv, sans sortie vidéo) sont préparés dès l'écran de
/// démarrage, sons chargés et en pause : en créer un au moment du son
/// prend plusieurs dizaines de millisecondes.
///
/// Sons sous licence CC0 (freesound.org), coupés et mis au niveau :
/// « VideoTronic Super 8mm Projector » par ajoyce86 (213741), « Shimmery »
/// par opticaillusions (521886, ralenti, plus grave, enchaîné, réverbéré), « Fast whoosh,
/// bamboo swoosh through air, version 2 » par zapsplat.com (719637) et
/// « Whoosh stereo light (transition) » par xkeril (701104).
class StartupSounds {
  StartupSounds._(this._clap, this._aurora, this._beam, this._window);

  final mpv.Player _clap;
  final mpv.Player _aurora;
  final mpv.Player _beam;
  final mpv.Player _window;
  bool _disposed = false;

  /// Prépare les sons ; `null` si la lecture audio est indisponible (le
  /// démarrage continue sans son).
  static Future<StartupSounds?> prepare() async {
    if (kIsWeb) return null;
    try {
      mpv.MediaKit.ensureInitialized();
      Future<mpv.Player> load(String asset, double volume) async {
        final player = openBackgroundPlayer(const mpv.PlayerConfiguration(
            vo: 'null', title: 'Kinos', logLevel: mpv.MPVLogLevel.error));
        await player.setVolume(volume);
        await player.open(mpv.Media('asset:///assets/sounds/$asset'),
            play: false);
        return player;
      }

      return StartupSounds._(
        await load('intro_clap.wav', _clapVolume),
        await load('intro_aurora.ogg', _auroraVolume),
        await load('intro_beam.wav', _beamVolume),
        await load('intro_window.wav', _windowVolume),
      );
    } catch (_) {
      return null;
    }
  }

  // Volumes mpv (0–100) : nettement sous la lecture vidéo.
  static const _clapVolume = 30.0;
  static const _auroraVolume = 25.0;
  static const _beamVolume = 25.0;
  static const _windowVolume = 30.0;

  /// Le clap : l'interrupteur, et la nappe qui monte avec l'aurore.
  void clap() {
    if (_disposed || !backgroundPlayerOpen(_clap)) return;
    _clap.play();
    _aurora.play();
  }

  /// Éteint la nappe de l'aurore en [duration] : elle tient pendant
  /// l'ouverture et s'éteint au moment où l'accueil est entièrement
  /// découvert, quel que soit le temps qu'il a mis à se charger.
  void fadeAurora(Duration duration) {
    if (_disposed || _fading != null) return;
    final start = DateTime.now();
    _fading = Timer.periodic(_fadeStep, (timer) {
      final t = DateTime.now().difference(start).inMicroseconds /
          duration.inMicroseconds;
      final open = !_disposed && backgroundPlayerOpen(_aurora);
      if (!open || t >= 1) {
        timer.cancel();
        if (open) _aurora.pause();
        return;
      }
      // Descente en douceur, plus marquée vers la fin.
      final remaining = 1 - t;
      _aurora.setVolume(_auroraVolume * remaining * remaining);
    });
  }

  Timer? _fading;
  static const _fadeStep = Duration(milliseconds: 15);

  void beam() {
    if (!_disposed && backgroundPlayerOpen(_beam)) _beam.play();
  }

  void window() {
    if (!_disposed && backgroundPlayerOpen(_window)) _window.play();
  }

  /// Libère les lecteurs une fois les derniers sons finis : libérés à la
  /// fin de l'ouverture, la nappe et le souffle étaient coupés net avant
  /// leur fondu de sortie.
  void release() {
    unawaited(Future<void>.delayed(_tail, dispose));
  }

  // Plus long que le plus long des sons après la fin de l'ouverture.
  static const _tail = Duration(seconds: 3);

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _fading?.cancel();
    await disposeBackgroundPlayer(_clap);
    await disposeBackgroundPlayer(_aurora);
    await disposeBackgroundPlayer(_beam);
    await disposeBackgroundPlayer(_window);
  }
}
