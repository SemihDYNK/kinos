import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import 'package:kinos/models/item_base_model.dart';
import 'package:kinos/models/media_playback_model.dart';
import 'package:kinos/models/playback/playback_model.dart';
import 'package:kinos/models/playback/playback_queue_state.dart';
import 'package:kinos/models/settings/video_player_settings.dart';
import 'package:kinos/providers/settings/client_settings_provider.dart';
import 'package:kinos/providers/settings/video_player_settings_provider.dart';
import 'package:kinos/wrappers/media_control_wrapper.dart';

final mediaPlaybackProvider = StateProvider<MediaPlaybackModel>((ref) => MediaPlaybackModel());

final playBackModel = StateProvider<PlaybackModel?>((ref) => null);

/// Passerelle pour les commandes vitesse/chapitre émises depuis
/// `VideoPlayerSettingsProviderNotifier` (raccourcis clavier,
/// `steppedSpeed`/`nextChapter`/`prevChapter`) — nécessaire car ce
/// provider-là ne doit JAMAIS lire `videoPlayerProvider` : celui-ci lit
/// déjà `videoPlayerSettingsProvider` ailleurs (`loadPlaybackItem`/
/// `loadAudioPlaybackItem` plus bas, et l'écoute de réglages de
/// `VideoPlayerNotifier`), donc un read en sens inverse formerait un
/// cycle que Riverpod détecte dès que les deux sens ont été empruntés
/// au moins une fois dans la session (`CircularDependencyError`, cf. le
/// correctif volume équivalent ci-dessous).
///
/// Ce holder est délibérément SANS AUCUNE dépendance déclarée (son
/// `create` ne lit ni ne watch rien) : un simple conteneur mutable,
/// rempli une fois par `VideoPlayerNotifier` à sa construction, lu à la
/// demande côté réglages. Ni watch ni read vers l'un ou l'autre
/// provider dans SA propre construction — donc aucune arête
/// transitive ne peut refermer le cycle (le graphe de dépendances de
/// Riverpod suit les arêtes de façon transitive, pas seulement
/// directe : un médiateur qui lirait lui-même l'un des deux côtés
/// rouvrirait le même problème un cran plus loin).
class ActiveVideoPlayerHolder {
  MediaControlsWrapper? wrapper;
}

final activeVideoPlayerHolderProvider =
    Provider<ActiveVideoPlayerHolder>((ref) => ActiveVideoPlayerHolder());

final videoPlayerProvider = StateNotifierProvider<VideoPlayerNotifier, MediaControlsWrapper>((ref) {
  final videoPlayer = VideoPlayerNotifier(ref);
  videoPlayer.init();
  return videoPlayer;
});

class VideoPlayerNotifier extends StateNotifier<MediaControlsWrapper> {
  VideoPlayerNotifier(this.ref) : super(MediaControlsWrapper(ref: ref)) {
    // Enregistré dès la construction, pas seulement dans `init()` : les
    // tests (`FakeBasePlayer`) construisent `VideoPlayerNotifier`
    // directement (via `videoPlayerProvider.overrideWith`) SANS jamais
    // appeler `init()` — volontairement, pour ne jamais créer de vrai
    // lecteur mpv/`AudioService` (cf. `video_player_volume_sync_test.dart`).
    // Si l'écoute des réglages ne vivait que dans `init()`, ces tests ne
    // l'exerceraient jamais.
    ref.read(activeVideoPlayerHolderProvider).wrapper = state;
    _listenToSettings();
  }

  final Ref ref;

  List<StreamSubscription> subscriptions = [];

  late final mediaState = ref.read(mediaPlaybackProvider.notifier);

  MediaPlaybackModel get playbackState => ref.read(mediaPlaybackProvider);

  ProviderSubscription<VideoPlayerSettingsModel>? settingsChanged;
  @override
  void dispose() {
    settingsChanged?.close();
    super.dispose();
  }

  Future<void> init() async {
    await state.stop();
    await state.dispose();
    await state.init();

    for (final s in subscriptions) {
      s.cancel();
    }

    // Réenregistre l'écoute (`_listenToSettings` ferme déjà l'ancien
    // abonnement avant d'en reposer un) : `init()` peut être rappelé
    // depuis CE MÊME abonnement, cf. le déclenchement
    // `!previous.playerSame(next)` plus bas.
    _listenToSettings();

    final subscription = state.stateStream.listen((value) {
      updateBuffering(value.buffering);
      updateBuffer(value.buffer);
      updatePlaying(value.playing);
      updatePosition(value.position);
      updateDuration(value.duration);
    });

    subscriptions.add(subscription);
  }

  void _listenToSettings() {
    settingsChanged?.close();
    settingsChanged = ref.listen(
      videoPlayerSettingsProvider,
      (previous, next) {
        final currentItem = ref.read(playBackModel)?.item;
        if (currentItem != null) {
          state.applyReplayGain(
            currentItem,
            settings: next,
          );
        }

        // Rechargement du moteur si le backend a changé (hardware accel,
        // libass, taille de tampon, moteur MPV/MDK/natif) — déplacé ici
        // depuis `VideoPlayerSettingsProviderNotifier.state=`, qui
        // faisait `ref.read(videoPlayerProvider.notifier).init()` :
        // CE provider (`videoPlayerProvider`) lit déjà
        // `videoPlayerSettingsProvider` ailleurs (`loadPlaybackItem`/
        // `loadAudioPlaybackItem`, ligne ~171/223), donc un read en sens
        // inverse depuis le provider de réglages formait un cycle —
        // Riverpod le détecte dès que les DEUX sens ont été empruntés au
        // moins une fois dans la session (`CircularDependencyError`,
        // observé en usage réel après le chargement d'une première
        // vidéo, jamais reproduit par les tests `FakeBasePlayer` qui
        // n'appellent jamais `loadPlaybackItem`). Un seul sens de
        // dépendance possible : ce provider écoute les réglages, jamais
        // l'inverse.
        if (previous != null && !previous.playerSame(next)) {
          init();
          return;
        }

        // Idem pour le volume — déplacé depuis le même setter
        // (`VideoPlayerSettingsProviderNotifier._setVolume`/`set state`,
        // qui faisait `ref.read(videoPlayerProvider)`), pour la même
        // raison structurelle. Seule source de vérité pour le volume :
        // l'app pousse vers le moteur, jamais l'inverse — le moteur
        // ré-émet fidèlement chaque palier de son propre fondu
        // lecture/pause (`lib_mpv.dart::_startPlaybackFade`, actif par
        // défaut) comme un vrai `PlayerState.volume`, jamais un
        // changement externe (un relais moteur -> interface a existé
        // brièvement, `syncVolumeFromEngine`, retiré : il faisait
        // chuter l'affichage à 0 à chaque pause).
        final volumeChanged = previous?.internalVolume != next.internalVolume;
        if (volumeChanged && state.hasPlayer) {
          state.setVolume(next.volume);
        }
      },
    );
  }

  Future<void> updateBuffering(bool event) async =>
      mediaState.update((state) => state.buffering == event ? state : state.copyWith(buffering: event));

  Future<void> updateBuffer(Duration buffer) async {
    mediaState.update(
      (state) => (state.buffer - buffer).inSeconds.abs() < 1
          ? state
          : state.copyWith(
              buffer: buffer,
            ),
    );
  }

  Future<void> updateDuration(Duration duration) async {
    mediaState.update((state) {
      return (state.duration - duration).inSeconds.abs() < 1
          ? state
          : state.copyWith(
              duration: duration,
            );
    });
  }

  Future<void> updatePlaying(bool event) async {
    final currentState = playbackState;
    if (!state.hasPlayer || currentState.playing == event) return;
    if (currentState.state == VideoPlayerState.disposed) return;
    mediaState.update(
      (state) => state.copyWith(playing: event),
    );
    ref.read(playBackModel)?.updatePlaybackPosition(currentState.position, event, ref);
  }

  Future<void> updatePosition(Duration event) async {
    if (!state.hasPlayer) return;
    if (playbackState.playing == false) return;
    final currentState = playbackState;
    if (currentState.state == VideoPlayerState.disposed) return;
    final currentPosition = currentState.position;

    if ((currentPosition - event).inSeconds.abs() < 1) return;

    final position = event;

    final lastPosition = currentState.lastPosition;
    final diff = (position.inMilliseconds - lastPosition.inMilliseconds).abs();

    if (diff > const Duration(seconds: 10).inMilliseconds) {
      mediaState.update((value) => value.copyWith(
            position: event,
            lastPosition: position,
          ));
      ref.read(playBackModel)?.updatePlaybackPosition(position, playbackState.playing, ref);
    } else {
      mediaState.update((value) => value.copyWith(
            position: event,
          ));
    }
  }

  Future<bool> loadPlaybackItem(PlaybackModel model, Duration startPosition) async {
    ref.read(playBackModel)?.dispose();
    await state.stop();
    ref.read(playbackRateProvider.notifier).state = 1.0;

    final useMinimizedPlayer =
        model.item.type == KinosItemType.audio || model.mediaStreams?.videoStreams.isEmpty == true;

    mediaState.update((state) => state.copyWith(
          state: useMinimizedPlayer ? VideoPlayerState.minimized : VideoPlayerState.fullScreen,
          fullScreen: !useMinimizedPlayer,
          buffering: true,
          errorPlaying: false,
          skippedSegments: {},
        ));

    final media = model.media;
    PlaybackModel? newPlaybackModel = model;
    final effectiveStartPosition = await model.resolvedStartPosition(startPosition);

    if (media != null) {
      ref.read(playBackModel.notifier).update((state) => newPlaybackModel);
      await state.loadVideo(model, effectiveStartPosition, true);
      await state.setVolume(ref.read(videoPlayerSettingsProvider).volume);

      await state.setAudioTrack(null, model);
      await state.setSubtitleTrack(null, model);

      ref.read(mediaPlaybackProvider.notifier).update((state) => state.copyWith(
            state: useMinimizedPlayer ? VideoPlayerState.minimized : VideoPlayerState.fullScreen,
            buffering: true,
            errorPlaying: false,
            skippedSegments: {},
          ));

      await state.play();
      return true;
    }

    mediaState.update((state) => state.copyWith(errorPlaying: true));
    return false;
  }

  Future<bool> loadAudioPlaybackItem(
    PlaybackModel model,
    List<ItemBaseModel> queue,
    int currentIndex,
    Duration startPosition,
  ) async {
    final currentPlayerState = ref.read(mediaPlaybackProvider).state;
    final keepFullScreenLayout = currentPlayerState == VideoPlayerState.fullScreen;
    final playbackSettings = ref.read(mediaPlaybackProvider);

    final initializedQueueState = PlaybackQueueState.fromQueue(
      queue,
      initialItemId: queue[currentIndex.clamp(0, queue.length - 1)].id,
      shuffleEnabled: playbackSettings.shuffleEnabled,
      repeatMode: playbackSettings.repeatMode,
    );
    final queuedModel = model.updatePlaybackQueue(initializedQueueState);
    final effectiveStartPosition = await queuedModel.resolvedStartPosition(startPosition);

    ref.read(playBackModel.notifier).update((state) => queuedModel);
    ref.read(playbackRateProvider.notifier).state = 1.0;

    mediaState.update((state) => state.copyWith(
          state: keepFullScreenLayout ? VideoPlayerState.fullScreen : VideoPlayerState.minimized,
          fullScreen: keepFullScreenLayout,
          buffering: true,
          errorPlaying: false,
          skippedSegments: {},
          duration: queuedModel.item.overview.runTime ?? Duration.zero,
        ));

    await state.loadAudioQueue(queue, currentIndex, effectiveStartPosition, true);
    await state.setVolume(ref.read(videoPlayerSettingsProvider).volume);

    mediaState.update((state) => state.copyWith(
          buffering: false,
          playing: true,
          position: effectiveStartPosition,
          duration: queuedModel.item.overview.runTime ?? Duration.zero,
        ));
    return true;
  }

  Future<void> reorderAudioQueueSection(
    AudioQueueSection section,
    int oldIndex,
    int newIndex,
  ) async {
    await state.reorderAudioQueueSection(section, oldIndex, newIndex);
  }

  Future<void> addToTemporaryQueue(List<ItemBaseModel> items) async {
    await state.addToTemporaryQueue(items);
  }

  Future<void> clearTemporaryQueue() async {
    state.clearTemporaryQueue();
  }

  Future<void> removeAudioQueueItem(ItemBaseModel item) async {
    await state.removeAudioQueueItem(item.id);
  }

  Future<void> removeAudioQueueSectionItem(
    AudioQueueSection section,
    int sectionIndex,
  ) async {
    await state.removeAudioQueueSectionItem(section, sectionIndex);
  }

  Future<void> playAudioQueueItem(ItemBaseModel item) async {
    if (ref.read(playBackModel) == null) return;
    await state.jumpToQueueItem(item);
  }

  Future<void> openPlayer(BuildContext context) async => state.openPlayer(context);

  Future<bool> takeScreenshot() async {
    final syncPath = ref.read(clientSettingsProvider).syncPath;
    // Early return here if we don't have a set/valid path. Skips actually taking the screenshot
    // which would be discarded.
    if (syncPath == null) {
      return false;
    }

    final screenshotsPath = p.join(syncPath, "Screenshots");
    final screenshotBuf = await state.takeScreenshot();

    if (screenshotBuf != null) {
      final savePathDirectory = Directory(screenshotsPath);

      // Should we try to create the directory instead?
      if (!await savePathDirectory.exists()) {
        return false;
      }

      final fileExtension = "png";
      final paddingAmount = 3;

      int maxNumber = 0;

      await for (var file in savePathDirectory.list()) {
        final finalSegment = file.uri.pathSegments.last;

        if (file is File && p.extension(finalSegment) == ".$fileExtension") {
          final match = RegExp(r'(\d+)').firstMatch(finalSegment);

          if (match != null) {
            final fileNumber = int.parse(match.group(0)!);

            if (fileNumber > maxNumber) {
              maxNumber = fileNumber;
            }
          }
        }
      }

      maxNumber += 1;

      final maxNumberStr = maxNumber.toString().padLeft(paddingAmount, '0');
      final screenshotName = '$maxNumberStr.$fileExtension';
      final screenshotPath = p.join(screenshotsPath, screenshotName);

      final screenshotFile = File(screenshotPath);
      await screenshotFile.writeAsBytes(screenshotBuf);

      return true;
    }

    return false;
  }
}
