import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus_platform_interface/wakelock_plus_platform_interface.dart';

import 'package:kinos/models/item_base_model.dart';
import 'package:kinos/models/items/chapters_model.dart';
import 'package:kinos/models/items/item_shared_models.dart';
import 'package:kinos/models/items/overview_model.dart';
import 'package:kinos/models/playback/playback_model.dart';
import 'package:kinos/providers/settings/video_player_settings_provider.dart';
import 'package:kinos/providers/shared_provider.dart';
import 'package:kinos/providers/video_player_provider.dart';

import '../support/fake_base_player.dart';

class _NoopWakelockPlatform extends WakelockPlusPlatformInterface {
  @override
  Future<void> toggle({required bool enable}) async {}
  @override
  Future<bool> get enabled async => false;
}

/// [PlaybackModel] minimal, sans réseau : `playbackStarted`/
/// `updatePlaybackPosition`/`playbackStopped` par défaut appellent la
/// vraie API Jellyfin (`DirectPlaybackModel.playbackStarted` fait un
/// `sessionsPlayingPost`) — hors de propos ici (ces tests vérifient la
/// non-cyclicité du graphe de providers, pas l'intégration serveur) et
/// injoignable dans le bac à sable de test. Ne surcharge que ces trois
/// méthodes réseau ; tout le reste (chapitres, media, item) est réel.
class _FakePlaybackModel extends PlaybackModel {
  _FakePlaybackModel({
    required super.item,
    required super.media,
    super.chapters,
  }) : super(playbackInfo: null);

  @override
  Future<PlaybackModel?> playbackStarted(Duration position, Ref ref) async => null;

  @override
  Future<PlaybackModel?> updatePlaybackPosition(Duration position, bool isPlaying, Ref ref) async => null;

  @override
  Future<PlaybackModel?> playbackStopped(Duration position, Duration? totalDuration, Ref ref) async => null;
}

ItemBaseModel _fakeMovie() => const ItemBaseModel(
      name: 'Film de test',
      id: 'movie-1',
      overview: OverviewModel(genres: [], summary: ''),
      parentId: null,
      playlistId: null,
      images: null,
      childCount: null,
      primaryRatio: null,
      userData: UserData(),
      canDownload: null,
      canDelete: null,
      jellyType: null,
    );

/// Régression pour `CircularDependencyError` (observé en usage réel :
/// lecture d'un film — qui établit `videoPlayerProvider ->
/// videoPlayerSettingsProvider` via `loadPlaybackItem` — puis un
/// raccourci vitesse/chapitre, qui lisait `videoPlayerProvider` en sens
/// inverse depuis `VideoPlayerSettingsProviderNotifier`). Contrairement
/// à `video_player_volume_sync_test.dart` (qui enrôle le faux lecteur
/// SANS jamais appeler `loadPlaybackItem`), ces tests appellent
/// `loadPlaybackItem` pour de vrai — c'est justement l'appel qui
/// établissait l'arête fatale, un test qui le court-circuite ne prouve
/// rien.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  WakelockPlusPlatformInterface.instance = _NoopWakelockPlatform();

  late ProviderContainer container;
  late FakeBasePlayer fakePlayer;

  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      videoPlayerProvider.overrideWith((ref) => VideoPlayerNotifier(ref)),
    ]);
    addTearDown(container.dispose);
    addTearDown(() => Future.delayed(const Duration(milliseconds: 50)));

    fakePlayer = FakeBasePlayer();
    await container.read(videoPlayerProvider.notifier).state.setup(fakePlayer);
  });

  Future<void> loadRealMedia({List<Chapter>? chapters}) async {
    final model = _FakePlaybackModel(
      item: _fakeMovie(),
      media: const Media(url: 'file:///fake.mkv'),
      chapters: chapters,
    );
    final ok = await container
        .read(videoPlayerProvider.notifier)
        .loadPlaybackItem(model, Duration.zero);
    expect(ok, isTrue, reason: 'loadPlaybackItem doit réussir pour que la '
        "suite du test soit significative — sinon l'arête "
        "videoPlayerProvider -> videoPlayerSettingsProvider n'est pas "
        'établie et le test ne prouve rien.');
  }

  test(
      'steppedSpeed après un chargement réel : aucun CircularDependencyError '
      'ET le moteur reçoit bien la nouvelle vitesse', () async {
    await loadRealMedia();

    expect(
      () => container.read(videoPlayerSettingsProvider.notifier).steppedSpeed(0.1),
      returnsNormally,
    );
    // Comportement observable inchangé : la vitesse calculée (1.0 + 0.1,
    // cf. `steppedSpeed`) atteint bien le lecteur actif, pas seulement
    // "aucune exception".
    expect(fakePlayer.setSpeedCalls, [1.1]);
  });

  test(
      'nextChapter après un chargement réel : aucun CircularDependencyError '
      'ET le moteur reçoit bien la position du chapitre suivant', () async {
    await loadRealMedia(chapters: [
      Chapter(name: 'un', imageUrl: '', startPosition: Duration.zero),
      Chapter(name: 'deux', imageUrl: '', startPosition: const Duration(minutes: 5)),
    ]);
    fakePlayer.emit(fakePlayer.lastState.update(position: Duration.zero));

    expect(
      () => container.read(videoPlayerSettingsProvider.notifier).nextChapter(),
      returnsNormally,
    );
    expect(fakePlayer.seekCalls, [const Duration(minutes: 5)]);
  });

  test(
      'prevChapter après un chargement réel : aucun CircularDependencyError '
      'ET le moteur reçoit bien la position du chapitre précédent', () async {
    await loadRealMedia(chapters: [
      Chapter(name: 'un', imageUrl: '', startPosition: Duration.zero),
      Chapter(name: 'deux', imageUrl: '', startPosition: const Duration(minutes: 5)),
    ]);
    fakePlayer.emit(fakePlayer.lastState.update(position: const Duration(minutes: 5)));

    expect(
      () => container.read(videoPlayerSettingsProvider.notifier).prevChapter(),
      returnsNormally,
    );
    expect(fakePlayer.seekCalls, [Duration.zero]);
  });
}
