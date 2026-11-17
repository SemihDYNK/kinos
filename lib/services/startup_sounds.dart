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
/// tout premier son de l'enregistrement, avant le moteur) ; à l'ouverture, un
/// souffle d'air léger qui passe de gauche à droite quand la fenêtre du
/// faisceau s'élargit. Chacun part au moment où l'animation le franchit
/// (pas une piste mixée d'avance : l'horloge de l'intro peut ralentir un
/// instant quand une image bloque, une piste figée se décalerait).
///
/// Les lecteurs (mpv, sans sortie vidéo) sont préparés dès l'écran de
/// démarrage, sons chargés et en pause : en créer un au moment du son
/// prend plusieurs dizaines de millisecondes.
///
/// Sons sous licence CC0 (freesound.org), coupés et mis au niveau :
/// « VideoTronic Super 8mm Projector » par ajoyce86 (213741) et « Whoosh
/// stereo light (transition) » par xkeril (701104).
class StartupSounds {
  StartupSounds._(this._clap, this._window);

  final mpv.Player _clap;
  final mpv.Player _window;
  bool _disposed = false;

  /// Prépare les sons ; `null` si la lecture audio est indisponible (le
  /// démarrage continue sans son).
  static Future<StartupSounds?> prepare() async {
    if (kIsWeb) return null;
    try {
      mpv.MediaKit.ensureInitialized();
      Future<mpv.Player> load(String asset, double volume) async {
        final player = mpv.Player(
            configuration: const mpv.PlayerConfiguration(
                vo: 'null', title: 'Kinos', logLevel: mpv.MPVLogLevel.error));
        await player.setVolume(volume);
        await player.open(mpv.Media('asset:///assets/sounds/$asset'),
            play: false);
        return player;
      }

      return StartupSounds._(
        await load('intro_clap.wav', _clapVolume),
        await load('intro_window.wav', _windowVolume),
      );
    } catch (_) {
      return null;
    }
  }

  // Volumes mpv (0–100) : nettement sous la lecture vidéo.
  static const _clapVolume = 30.0;
  static const _windowVolume = 30.0;

  void clap() {
    if (!_disposed) _clap.play();
  }

  void window() {
    if (!_disposed) _window.play();
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _clap.dispose();
    await _window.dispose();
  }
}
