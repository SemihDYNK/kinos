import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:kinos/models/items/media_streams_model.dart';
import 'package:kinos/models/playback/playback_model.dart';
import 'package:kinos/models/settings/video_player_settings.dart';
import 'package:kinos/wrappers/players/base_player.dart';
import 'package:kinos/wrappers/players/player_states.dart';

/// Double de test pour [BasePlayer] — aucune dépendance à mpv/media_kit,
/// aucun canal de plateforme.
///
/// Naïf jusqu'ici (émettait la valeur demandée, immédiatement, une seule
/// fois). Reproduit maintenant fidèlement ce que lit
/// `lib/wrappers/players/lib_mpv.dart` (lecture seule, jamais modifié) :
/// - `setVolume` applique avec un léger délai, comme un vrai aller-retour
///   moteur (`await _player?.setVolume(...)`).
/// - `pause()`/`play()` déclenchent un fondu (`_startPlaybackFade`,
///   `enablePlayPauseFade` par défaut à `true`) qui fait RÉELLEMENT
///   transiter le volume par 0 (fondu de sortie) ou remonter de 0 vers
///   `_preferredVolume` (fondu d'entrée), à coups de `PlayerState` émis à
///   chaque palier — c'est ce flux, fidèlement reproduit ici, qui a
///   révélé la boucle de rétro-action une fois relayé vers l'UI.
/// - émet aussi des états périodiques sans rapport avec le volume
///   (position) pendant qu'un fondu est en cours, pour vérifier que rien
///   ne dépend d'un flux "propre".
class FakeBasePlayer extends BasePlayer {
  final _controller = StreamController<PlayerState>.broadcast();
  final List<double> setVolumeCalls = [];
  final List<double> setSpeedCalls = [];
  final List<Duration> seekCalls = [];

  double _preferredVolume = 100;
  Timer? _fadeTimer;
  Timer? _noiseTimer;
  int _fadeSteps = 4;
  Duration _setVolumeDelay = const Duration(milliseconds: 5);

  @override
  Stream<PlayerState> get stateStream => _controller.stream;

  /// Nombre de paliers du fondu simulé — par défaut assez petit pour des
  /// tests rapides ; augmenter pour une reproduction plus fine.
  set fadeSteps(int value) => _fadeSteps = value;

  /// Délai simulé avant qu'un `setVolume` de l'app n'atteigne le moteur.
  set setVolumeDelay(Duration value) => _setVolumeDelay = value;

  void emit(PlayerState state) {
    lastState = state;
    _controller.add(state);
  }

  /// Bruit de fond sans rapport avec le volume (position) — n'importe
  /// quel abonné doit rester correct même sous un flux d'état bavard.
  void startPositionNoise({Duration interval = const Duration(milliseconds: 3)}) {
    _noiseTimer?.cancel();
    _noiseTimer = Timer.periodic(interval, (_) {
      emit(lastState.update(position: lastState.position + const Duration(milliseconds: 16)));
    });
  }

  void stopPositionNoise() {
    _noiseTimer?.cancel();
    _noiseTimer = null;
  }

  @override
  Future<void> init(VideoPlayerSettingsModel settings) async {}

  @override
  Widget? videoWidget(Key key, BoxFit fit) => null;

  @override
  Widget? subtitles(bool showOverlay, {GlobalKey? controlsKey}) => null;

  @override
  Future<void> dispose() async {
    _fadeTimer?.cancel();
    _noiseTimer?.cancel();
    await _controller.close();
  }

  @override
  Future<void> open(BuildContext context) async {}

  @override
  Future<void> loadVideo(String url, bool play,
      {Duration startPosition = Duration.zero}) async {}

  @override
  Future<void> seek(Duration position) async {
    seekCalls.add(position);
  }

  /// Fondu d'entrée : `playing` passe à `true` immédiatement (comme
  /// `lib_mpv.dart:play()`), le volume remonte progressivement de 0 vers
  /// `_preferredVolume`.
  @override
  Future<void> play() async {
    _fadeTimer?.cancel();
    emit(lastState.update(playing: true));
    final start = lastState.volume;
    for (var i = 1; i <= _fadeSteps; i++) {
      final next = start + (_preferredVolume - start) * i / _fadeSteps;
      await Future.delayed(const Duration(milliseconds: 2));
      emit(lastState.update(volume: next));
    }
  }

  /// Fondu de sortie : le volume redescend progressivement vers 0 avant
  /// que `playing` ne passe à `false` (comme `lib_mpv.dart:pause()` via
  /// `_startPlaybackFade`) — le volume affiché transite RÉELLEMENT par 0
  /// à chaque pause, ce n'est pas un artefact.
  @override
  Future<void> pause() async {
    _fadeTimer?.cancel();
    final start = lastState.volume;
    for (var i = 1; i <= _fadeSteps; i++) {
      final next = start * (1 - i / _fadeSteps);
      await Future.delayed(const Duration(milliseconds: 2));
      emit(lastState.update(volume: next));
    }
    emit(lastState.update(playing: false));
  }

  @override
  Future<void> setVolume(double volume) async {
    setVolumeCalls.add(volume);
    _fadeTimer?.cancel();
    _preferredVolume = volume.clamp(0.0, 100.0);
    await Future.delayed(_setVolumeDelay);
    emit(lastState.update(volume: _preferredVolume));
  }

  @override
  Future<void> setSpeed(double speed) async {
    setSpeedCalls.add(speed);
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> playOrPause() async {}

  @override
  Future<void> loop(bool loop) async {}

  @override
  Future<Uint8List?> takeScreenshot() async => null;

  @override
  Future<int> setSubtitleTrack(
          SubStreamModel? model, PlaybackModel playbackModel) async =>
      -1;

  @override
  Future<int> setAudioTrack(
          AudioStreamModel? model, PlaybackModel playbackModel) async =>
      -1;
}
