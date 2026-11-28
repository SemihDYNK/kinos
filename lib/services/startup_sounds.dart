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

/// Sons de l'intro : une nappe de verre et de cloches qui monte dès le
/// noir et enfle pendant le mouvement de caméra ; au clap, l'interrupteur
/// d'un projecteur Super 8 et une cascade de célesta qui frappe avec lui,
/// pendant que la nappe s'éteint doucement. L'ouverture est
/// silencieuse. Chaque son part au moment où l'animation le franchit (pas
/// une piste mixée d'avance : l'horloge de l'intro peut ralentir un
/// instant quand une image bloque, une piste figée se décalerait).
///
/// Les lecteurs (mpv, sans sortie vidéo) sont préparés dès l'écran de
/// démarrage, sons chargés et en pause : en créer un au moment du son
/// prend plusieurs dizaines de millisecondes.
///
/// Sons sous licence CC0 (freesound.org), coupés et mis au niveau :
/// « VideoTronic Super 8mm Projector » par ajoyce86 (213741) ;
/// « MUSCChim_Atonal Crystal Chime Texture 1_EM » par newlocknew (772279)
/// mêlé à « Singing Bowl, long without reverb » par hollandm (573805,
/// filtré, très bas) ; « Celesta Chime Descending » par Qvantor (879801,
/// ralenti, réverbéré).
class StartupSounds {
  StartupSounds._(this._clap, this._bed, this._celesta);

  final mpv.Player _clap;
  final mpv.Player _bed;
  final mpv.Player _celesta;
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
        await load('intro_bed.ogg', _bedVolume),
        await load('intro_celesta.ogg', _celestaVolume),
      );
    } catch (_) {
      return null;
    }
  }

  // Volumes mpv (0–100) : nettement sous la lecture vidéo.
  static const _clapVolume = 30.0;
  static const _bedVolume = 32.0;
  static const _celestaVolume = 34.0;

  bool _open(mpv.Player player) => !_disposed && backgroundPlayerOpen(player);

  /// La nappe, dès le noir de l'intro.
  void start() {
    if (_open(_bed)) _bed.play();
  }

  /// Le clap : l'interrupteur et la cascade de célesta, dont la première
  /// note (la plus forte) frappe avec lui ; la nappe s'éteint.
  void clap() {
    if (_open(_clap)) _clap.play();
    if (_open(_celesta)) _celesta.play();
    _fadeBed(_bedFade);
  }

  // La nappe s'éteint en ce temps après le clap.
  static const _bedFade = Duration(milliseconds: 1600);

  void _fadeBed(Duration duration) {
    if (_disposed || _fading != null) return;
    final start = DateTime.now();
    _fading = Timer.periodic(_fadeStep, (timer) {
      final t = DateTime.now().difference(start).inMicroseconds /
          duration.inMicroseconds;
      final open = _open(_bed);
      if (!open || t >= 1) {
        timer.cancel();
        if (open) _bed.pause();
        return;
      }
      // Descente en douceur, plus marquée vers la fin.
      final remaining = 1 - t;
      _bed.setVolume(_bedVolume * remaining * remaining);
    });
  }

  Timer? _fading;
  static const _fadeStep = Duration(milliseconds: 15);

  /// Libère les lecteurs une fois les derniers sons finis (la résonance du
  /// célesta tient encore après le clap).
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
    await disposeBackgroundPlayer(_bed);
    await disposeBackgroundPlayer(_celesta);
  }
}
