import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:volume_controller/volume_controller.dart';

import 'package:kinos/models/settings/key_combinations.dart';
import 'package:kinos/models/settings/video_player_settings.dart';
import 'package:kinos/providers/shared_provider.dart';
import 'package:kinos/providers/video_player_provider.dart';

final videoPlayerSettingsProvider =
    StateNotifierProvider<VideoPlayerSettingsProviderNotifier, VideoPlayerSettingsModel>((ref) {
  return VideoPlayerSettingsProviderNotifier(ref);
});

final playbackRateProvider = StateProvider<double>((ref) => 1.0);

class VideoPlayerSettingsProviderNotifier extends StateNotifier<VideoPlayerSettingsModel> {
  VideoPlayerSettingsProviderNotifier(this.ref) : super(_sanitizeCrossfade(VideoPlayerSettingsModel()));

  final Ref ref;

  @override
  set state(VideoPlayerSettingsModel value) {
    value = _sanitizeCrossfade(value);
    super.state = value;
    ref.read(sharedUtilityProvider).videoPlayerSettings = value;
    // Ni la ré-init du moteur au changement de backend, ni la poussée du
    // volume, ne se font plus depuis ce setter : les deux faisaient
    // `ref.read(videoPlayerProvider...)`, alors que `videoPlayerProvider`
    // lit DÉJÀ ce provider-ci ailleurs (`loadPlaybackItem`/
    // `loadAudioPlaybackItem`, `video_player_provider.dart`) — un read en
    // sens inverse ici formait un cycle que Riverpod détecte dès que les
    // deux sens ont été empruntés au moins une fois dans la session
    // (`CircularDependencyError`, reproduit en usage réel après le
    // chargement d'une première vidéo puis un changement de volume ;
    // jamais vu par les tests `FakeBasePlayer`, qui n'appellent jamais
    // `loadPlaybackItem`). Déplacé dans le `ref.listen(videoPlayerSettingsProvider,
    // ...)` déjà présent côté `VideoPlayerNotifier.init()` — seul sens de
    // dépendance permis : ce provider-ci ne doit jamais lire
    // `videoPlayerProvider`, ni directement ni via son `.notifier`.
  }

  /// Restaure les réglages persistés au démarrage
  /// (`SharedUtility.loadSettings()`) — jamais une écriture directe de
  /// `state` : c'est cette voie-là (assignation brute, hors
  /// `_setVolume`) qui laissait le moteur non informé du volume restauré
  /// (le bug d'origine). Passe par le setter ci-dessus, qui pousse
  /// maintenant la correction au moteur lui-même.
  ///
  /// Règle validée : un volume persisté à 0 (muet à la fermeture de la
  /// session précédente) ne doit jamais relancer l'app en silence sans
  /// indication — restaure [lastNonZeroVolume] à la place (100 à défaut
  /// côté appelant, cf. `SharedHelper.lastNonZeroVideoVolume`).
  void restoreFromPersisted(
      VideoPlayerSettingsModel persisted, double lastNonZeroVolume) {
    state = persisted.internalVolume == 0
        ? persisted.copyWith(internalVolume: lastNonZeroVolume)
        : persisted;
  }

  void setScreenBrightness(double? value) async {
    state = state.copyWith(
      screenBrightness: value,
    );
    if (state.screenBrightness != null) {
      ScreenBrightness().setApplicationScreenBrightness(state.screenBrightness!);
    } else {
      ScreenBrightness().resetApplicationScreenBrightness();
    }
  }

  void setSavedBrightness() {
    if (state.screenBrightness != null) {
      ScreenBrightness().setApplicationScreenBrightness(state.screenBrightness!);
    }
  }

  void setFillScreen(bool? value, {BuildContext? context}) {
    state = state.copyWith(fillScreen: value ?? false);
  }

  void setHardwareAccel(bool? value) => state = state.copyWith(hardwareAccel: value ?? true);
  void setUseLibass(bool? value) => state = state.copyWith(useLibass: value ?? false);
  void setMediaTunneling(bool? value) => state = state.copyWith(enableTunneling: value ?? false);
  void setBufferSize(int? value) => state = state.copyWith(bufferSize: value ?? 32);
  void setFitType(BoxFit? value) => state = state.copyWith(videoFit: value ?? BoxFit.contain);
  void setScreensaver(Screensaver? value) => state = state.copyWith(screensaver: value ?? Screensaver.black);

  void setVolume(double value) {
    _setVolume(value);
  }

  void steppedVolume(int i) {
    final value = (state.volume + i).clamp(0, 100).toDouble();
    _setVolume(value);
  }

  void _setVolume(double value) {
    // Le moteur est notifié par le setter de `state` lui-même (cf.
    // ci-dessus) — pas d'appel à `videoPlayerProvider` ici, pour qu'il
    // n'existe qu'un seul chemin qui le fasse, quelle que soit l'origine
    // de l'écriture.
    state = state.copyWith(internalVolume: value);
    // Mémorise le dernier volume non nul pour `restoreFromPersisted` —
    // un volume à 0 n'écrase jamais ce repère (cf. `SharedHelper
    // .lastNonZeroVideoVolume`), c'est justement ce qui permet de ne
    // jamais relancer l'app en silence après une session muette.
    if (value > 0) {
      ref.read(sharedUtilityProvider).lastNonZeroVideoVolume = value;
    }
    if ({TargetPlatform.android, TargetPlatform.iOS}.contains(defaultTargetPlatform)) {
      VolumeController.instance.showSystemUI = false;
      VolumeController.instance.setVolume(value / 100);
      log("Setting system volume to $value");
    }
  }

  void steppedSpeed(double i) {
    var value = double.parse(
      ((ref.read(playbackRateProvider) + i).clamp(0.25, 3)).toStringAsFixed(2),
    );

    if ((value - 1.0).abs() <= 0.06) {
      value = 1.0;
    }

    ref.read(playbackRateProvider.notifier).state = value;
    // `activeVideoPlayerHolderProvider`, jamais `videoPlayerProvider`
    // directement : cf. le commentaire du holder dans
    // `video_player_provider.dart` — même raison structurelle que le
    // volume (cycle Riverpod).
    ref.read(activeVideoPlayerHolderProvider).wrapper?.setSpeed(value);
  }

  void toggleOrientation(Set<DeviceOrientation>? orientation) =>
      state = state.copyWith(allowedOrientations: orientation);

  void setShortcuts(MapEntry<VideoHotKeys, KeyCombination> newEntry) {
    state = state.copyWith(hotKeys: state.hotKeys.setOrRemove(newEntry, state.defaultShortCuts));
  }

  void nextChapter() {
    final chapters = ref.read(playBackModel)?.chapters ?? [];
    // `activeVideoPlayerHolderProvider`, jamais `videoPlayerProvider`
    // directement : même raison structurelle que `steppedSpeed`
    // ci-dessus (cycle Riverpod).
    final wrapper = ref.read(activeVideoPlayerHolderProvider).wrapper;
    final currentPosition = wrapper?.lastState?.position;

    if (chapters.isNotEmpty && currentPosition != null) {
      final currentChapter = chapters.lastWhereOrNull((element) => element.startPosition <= currentPosition);

      if (currentChapter != null) {
        final nextChapterIndex = chapters.indexOf(currentChapter) + 1;
        if (nextChapterIndex < chapters.length) {
          wrapper?.seek(chapters[nextChapterIndex].startPosition);
        } else {
          wrapper?.seek(currentChapter.startPosition);
        }
      }
    }
  }

  void prevChapter() {
    final chapters = ref.read(playBackModel)?.chapters ?? [];
    final wrapper = ref.read(activeVideoPlayerHolderProvider).wrapper;
    final currentPosition = wrapper?.lastState?.position;

    if (chapters.isNotEmpty && currentPosition != null) {
      final currentChapter = chapters.lastWhereOrNull((element) => element.startPosition <= currentPosition);

      if (currentChapter != null) {
        final prevChapterIndex = chapters.indexOf(currentChapter) - 1;
        if (prevChapterIndex >= 0) {
          wrapper?.seek(chapters[prevChapterIndex].startPosition);
        } else {
          wrapper?.seek(currentChapter.startPosition);
        }
      }
    }
  }

  void setEnableSpeedBoost(bool value) => state = state.copyWith(enableSpeedBoost: value);

  void setSpeedBoostRate(double value) {
    final clampedValue = value.clamp(0.25, 3.0);
    state = state.copyWith(speedBoostRate: clampedValue);
  }

  void setEnableDoubleTapSeek(bool value) => state = state.copyWith(enableDoubleTapSeek: value);

  void setEnableAdvancedVideoOptions(bool value) => state = state.copyWith(enableAdvancedVideoOptions: value);

  void setEnableEdgeGestures(bool value) => state = state.copyWith(enableEdgeGestures: value);

  void setReverseEdgeGestures(bool value) => state = state.copyWith(reverseEdgeGestures: value);

  void setEnablePictureInPicture(bool value) => state = state.copyWith(enablePictureInPicture: value);

  void setEnableReplayGain(bool value) => state = state.copyWith(enableReplayGain: value);

  void setEnablePlayPauseFade(bool value) => state = state.copyWith(enablePlayPauseFade: value);

  void setReplayGainVolumeLevel(ReplayGainVolumeLevel value) => state = state.copyWith(replayGainVolumeLevel: value);

  void setEnableCrossfade(bool value) {
    state = state.copyWith(enableCrossfade: value && state.canUseCrossfade);
  }

  void setCrossfadeDurationMs(int value) => state = state.copyWith(crossfadeDurationMs: value);

  static VideoPlayerSettingsModel _sanitizeCrossfade(VideoPlayerSettingsModel value) {
    if (!value.canUseCrossfade && value.enableCrossfade) {
      return value.copyWith(enableCrossfade: false);
    }
    return value;
  }

  void setAmbientBlur(bool value) => state = state.copyWith(ambientBlur: value);
}
